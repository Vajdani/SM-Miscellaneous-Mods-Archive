--ඞ
---@class Player : PlayerClass
---@field sv table
---@field cl table
Player = class()
Player.respawnTime = 5 * 40
Player.hazardStats = {
	lava = { frequency = 40, damage = 15 },
	acid = { frequency = 20, damage = 10 }
}

dofile "$CONTENT_DATA/Scripts/util.lua"

local armourDamageReduction = 0.75 --percent
local queuedMsgRemoveTime = 60
local ammoTypeToIcon = {
	rounds = "$CONTENT_DATA/Gui/susshake.png",
	shells = "$CONTENT_DATA/Gui/susshake.png",
	cells = "$CONTENT_DATA/Gui/susshake.png",
	grenades = "$CONTENT_DATA/Gui/susshake.png",
	rockets = "$CONTENT_DATA/Gui/susshake.png"
}

--Server
function Player.server_onCreate( self )
	print("Player", self.player.id, "created | server")

	self.sv = {}
	self.sv.stats = {
		health = 100, maxhealth = 100,
		armour = 0, maxarmour = 150,

		rounds = 0, maxrounds = 150,
		shells = 0, maxshells = 24,
		cells = 0, maxcells = 250,
		grenades = 0, maxgrenades = 30,
		rockets = 0, maxrockets = 20
	}
	self.sv.dead = false
	self.sv.deathTick = nil

	self.sv.currentHazard = nil
	self.sv.hazardDamageTick = nil

	self:sv_resetInventory()

	self.network:setClientData( self.sv )
	self.player:setPublicData( self.sv )
end

function Player:server_onFixedUpdate()
	local tick = sm.game.getCurrentTick()

	if self.sv.deathTick ~= nil and tick - self.sv.deathTick >= self.respawnTime then
		self:sv_respawn()
	end

	if self.sv.currentHazard ~= nil then
		local hazardStats = self.hazardStats[self.sv.currentHazard]

		if tick - self.sv.hazardDamageTick >= hazardStats.frequency then
			self.sv.hazardDamageTick = tick

			self:sv_takeDamage(hazardStats.damage, self.sv.currentHazard)
		end
	end
end

function Player:sv_setStats( data )
	self.sv.stats.health = data.health
	self.sv.stats.armour = data.armour

	self:sv_checkDead()
end

function Player:sv_setHazard( hazard )
	self.sv.currentHazard = hazard
	self.sv.hazardDamageTick = hazard ~= nil and sm.game.getServerTick() - self.hazardStats[self.sv.currentHazard].frequency or nil
end

function Player:server_onProjectile(position, airTime, velocity, projectileName, attacker, damage, customData, normal, uuid )
	self:sv_takeDamage(damage, attacker)
end

function Player:server_onMelee( position, attacker, damage, power, direction, normal )
	self:sv_takeDamage(damage, attacker)

	if attacker then
		ApplyKnockback( self.player.character, direction, power )
	end
end

function Player:server_onExplosion( center, destructionLevel )
	self:sv_takeDamage(destructionLevel * 2, nil)
	local dir = ( self.player.character.worldPosition - center )
	if self.player.character:isTumbling() and dir:length() > 0.01 then
		local knockbackDirection = dir:normalize()
		ApplyKnockback( self.player.character, knockbackDirection, 5000 )
	end
end

function Player:sv_takeDamage( damage, source )
	if type(damage) == "table" then
		damage, source = damage.damage, damage.source
	end

	if self.sv.dead or damage <= 0 then return end

	if self.sv.stats.armour > 0 then
		self.sv.stats.armour = self.sv.stats.armour - damage * armourDamageReduction

		if self.sv.stats.armour <= 0 then
			self.sv.stats.health = math.max( self.sv.stats.health + self.sv.stats.armour, 0 )
			self.sv.stats.armour = 0
		end
	else
		self.sv.stats.health = math.max( self.sv.stats.health - damage, 0 )
	end

	print( "Player", self.player.id, "took", damage, "damage")
	print( "Player", self.player.id, "stats:", self.sv.stats.health, self.sv.stats.armour)

	--self.player:sendCharacterEvent( "hit" )

	self:sv_checkDead()
end

function Player:sv_restorehealth( amount )
	local prevHealth = self.sv.stats.health
	self.sv.stats.health = sm.util.clamp(self.sv.stats.health + amount, 0, self.sv.stats.maxhealth)

	local restored = self.sv.stats.health - prevHealth
	self.network:sendToClient(self.player, "cl_queueMsg", "#"..g_pickupColours.health:getHexStr():sub(1,6).."Restored "..tostring(restored).." health")
	self.network:setClientData( self.sv )
end

function Player:sv_restorearmour( amount )
	local prevArmour = self.sv.stats.armour
	self.sv.stats.armour = sm.util.clamp(self.sv.stats.armour + amount, 0, self.sv.stats.maxarmour)

	local restored = self.sv.stats.armour - prevArmour
	self.network:sendToClient(self.player, "cl_queueMsg", "#"..g_pickupColours.armour:getHexStr():sub(1,6).."Restored "..tostring(restored).." armour" )
	self.network:setClientData( self.sv )
end

function Player:sv_restoreammo( data )
	local type, amount = data.type, data.amount
	local prevAmmo = self.sv.stats[type]
	self.sv.stats[type] = sm.util.clamp( self.sv.stats[type] + amount, 0, self.sv.stats["max"..type] )

	local restored = self.sv.stats[type] - prevAmmo
	self.network:sendToClient(self.player, "cl_queueMsg", "#"..g_pickupColours.ammo:getHexStr():sub(1,6).."Picked up x"..tostring(restored).." "..type )
	self.network:setClientData( self.sv )
end

function Player:sv_spendAmmo( data )
	local type, amount = data.type, data.amount
	self.sv.stats[type] = math.max( self.sv.stats[type] - amount, 0 )

	self.network:setClientData( self.sv )
end

function Player:sv_checkDead()
	if self.sv.stats.health <= 0 then
		print("Player", self.player.id, "has died!")
		self.sv.dead = true
		self.sv.deathTick = sm.game.getServerTick()

		local char = self.player.character
		char:setTumbling( true )
		char:setDowned( true )

		char:applyTumblingImpulse( char.velocity * char.mass )
	end

	self.network:setClientData( self.sv )
	self.player:setPublicData( self.sv )
end

function Player:sv_respawn()
	self.sv.stats = {
		health = 100, maxhealth = 100,
		armour = 0, maxarmour = 150,

		rounds = 0, maxrounds = 150,
		shells = 0, maxshells = 24,
		cells = 0, maxcells = 250,
		grenades = 0, maxgrenades = 30,
		rockets = 0, maxrockets = 20
	}
	self.sv.dead = false
	self.sv.deathTick = nil

	self.sv.currentHazard = nil
	self.sv.hazardDamageTick = nil

	local char = self.player.character
	char:setTumbling( false )
	char:setDowned( false )
	char:setWorldPosition( tableToVec3(g_respawnPoints[math.random(#g_respawnPoints)]) )

	self:sv_resetInventory()

	print("Player", self.player.id, "has respawned!")

	self.network:setClientData( self.sv )
	self.player:setPublicData( self.sv )
end

function Player:sv_resetInventory()
	sm.container.beginTransaction()
	local container = self.player:getInventory()
	local uuid = sm.uuid.getNil()
	for i = 1, container:getSize() do
		container:setItem( i - 1, uuid, -1 )
	end

	container:setItem( 0, g_weaponUUIDs.hammer, 1 )
	sm.container.endTransaction()
end

function Player.server_onShapeRemoved( self, items )

end



--Client
function Player.client_onCreate( self )
	print("Player", self.player.id, "created | client")

	self.cl = {}

	local player = sm.localPlayer.getPlayer()
	if player ~= self.player then return end

	self:cl_init()

	self.cl.data = {}
end

function Player:client_onRefresh()
	self:cl_init()
	self:cl_updateUI()
end

function Player:cl_init()
	self.cl.survivalHud = sm.gui.createSurvivalHudGui()
	self.cl.survivalHud:setVisible("WaterBar", false)
	self.cl.survivalHud:setVisible("BindingPanel", false)
	self.cl.survivalHud:open()

	self.cl.extraHud = sm.gui.createGuiFromLayout( "$CONTENT_DATA/Gui/extraHud.layout", false,
		{
			isHud = true,
			isInteractive = false,
			needsCursor = false,
			hidesHotbar = false,
			isOverlapped = false,
			backgroundAlpha = 0.0
		}
	)
	self.cl.extraHud:open()

	self.cl.queuedMsgs = {}
	self.cl.queuedMsgRemoveTimer = Timer()
	self.cl.queuedMsgRemoveTimer:start(queuedMsgRemoveTime)
end

function Player:client_onClientDataUpdate( data )
	if sm.localPlayer.getPlayer() ~= self.player then return end

	self.cl.data = data

	if self.cl.data.dead then
		sm.camera.setCameraState( 4 )
	end

	self.player:setClientPublicData( data )

	self:cl_updateUI()
end

function Player:client_onUpdate()
	if sm.localPlayer.getPlayer() ~= self.player then return end

	if self.cl.data.dead then
		local time = math.max(math.ceil((self.respawnTime - (sm.game.getCurrentTick() - self.cl.data.deathTick)) / 40), 0)
		sm.gui.setInteractionText( "", interactionWrap("Respawning in: #ffffff"..tostring(time)) )

		if time == 0 then
			sm.camera.setCameraState( 0 )
		elseif time == 1 then
			sm.gui.startFadeToBlack( 1, 1 )
		end
	end
end

function Player:client_onFixedUpdate()
	if sm.localPlayer.getPlayer() ~= self.player then return end

	if #self.cl.queuedMsgs > 0 then
		self.cl.queuedMsgRemoveTimer:tick()

		if self.cl.queuedMsgRemoveTimer:done() then
			local new = {}
			for i = 2, #self.cl.queuedMsgs  do
				new[i-1] = self.cl.queuedMsgs[i]
			end
			self.cl.queuedMsgs = new
			self.cl.queuedMsgRemoveTimer:start(queuedMsgRemoveTime)
		end

		local message = ""
		for i = sm.util.clamp(#self.cl.queuedMsgs-1, 1, 10000), #self.cl.queuedMsgs do
			message = message..self.cl.queuedMsgs[i].."\n"
		end
		self:cl_displayMsg( { msg = message, dur = 2.5 } )
	end

	local weaponName = g_weaponUUIDs_reverse[tostring(sm.localPlayer.getActiveItem())]
	local ammoType = g_weaponToAmmoType[weaponName]
	local shouldDisplay = ammoType ~= nil

	self.cl.extraHud:setVisible("ammoDisplay", shouldDisplay)
	if shouldDisplay then
		self.cl.extraHud:setText("ammoAmount", tostring(self.cl.data.stats[ammoType]))
		self.cl.extraHud:setImage("ammoIcon", ammoTypeToIcon[ammoType] )
	end
end

function Player:cl_queueMsg(msg)
	table.insert(self.cl.queuedMsgs, msg)
	self.cl.queuedMsgRemoveTimer:reset()
end

function Player:cl_displayMsg( args )
	sm.gui.displayAlertText(args.msg, args.dur)
end

function Player:cl_updateUI()
	local data = self.cl.data
	self.cl.survivalHud:setSliderData( "Health", data.stats.maxhealth * 10 + 1, data.stats.health * 10 )
	self.cl.survivalHud:setSliderData( "Food", data.stats.maxarmour * 10 + 1, data.stats.armour * 10 )
end

function Player:client_onInteract()

end

function Player:client_onReload()

end