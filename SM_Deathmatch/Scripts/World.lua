---@class World : WorldClass
---@field sv table
---@field cl table
World = class( nil )
World.terrainScript = "$CONTENT_DATA/Scripts/terrain.lua"
World.cellMinX = -2
World.cellMaxX = 1
World.cellMinY = -2
World.cellMaxY = 1
World.worldBorder = true

dofile "$SURVIVAL_DATA/Scripts/game/managers/PesticideManager.lua"
dofile "$SURVIVAL_DATA/Scripts/blueprint_util.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$CONTENT_DATA/Scripts/util.lua"

g_potatoProjectiles = {
    projectile_potato,
    projectile_fries,
    projectile_smallpotato
}

local pickupSize = sm.vec3.one() / 2
local weaponPickupSize = sm.vec3.one() / 4
local weaponPickupSpinSpeed = 100
local weaponPickupBobSpeed = 2
local weaponPickupSpinOffset = { min = 1, max = 100 }
local weaponPickupBobOffset = { min = 1, max = 100 }
local weaponPickupPosOffset = sm.vec3.new(0,0,0.3)
local default_weaponPickup_direction = sm.vec3.new(0,-1,0)
local default_weaponPickup_rotation = sm.vec3.getRotation(vector_up, default_weaponPickup_direction)
g_pickupColours = {
    health = sm.color.new(0,0.5,1),
    armour = sm.color.new(0,1,0),
	ammo = sm.color.new(1,1,0)
}
g_hazardColours = {
    acid = sm.color.new(0,1,0),
    lava = sm.color.new(1,0,0),
}

function World.server_onCreate( self )
    print("World.server_onCreate")

    g_pesticideManager = PesticideManager()
	g_pesticideManager:sv_onCreate()

    self.sv = {}
	self.sv.pickups = {}
	self.sv.hazards = {}
    self.sv.teleporters = {}

    self:sv_createPickups()
    self:sv_createHazards()
    self:sv_createTeleporters()
end

function World:server_onFixedUpdate( dt )
    g_pesticideManager:sv_onWorldFixedUpdate( self )

    if self.sv.pickups ~= nil or #self.sv.pickups > 0 then
        for v, k in pairs(self.sv.pickups) do
            if not k.active --[[and k.remainingUses > 0]] then
                k.cd = k.cd - 1
                if k.cd <= 0 then
                    k.active = true
                    k.cd = k.respawnTime
                    self.network:sendToClients("cl_managePickupEffect", { id = v, active = k.active, pos = k.pos })
                end
            end
        end
    end
end

function World:server_onProjectile( hitPos, hitTime, hitVelocity, _, attacker, damage, userData, hitNormal, target, projectileUuid )
	-- Notify units about projectile hit
	if isAnyOf( projectileUuid, g_potatoProjectiles ) then
		local units = sm.unit.getAllUnits()
		for i, unit in ipairs( units ) do
			if InSameWorld( self.world, unit ) then
				sm.event.sendToUnit( unit, "sv_e_worldEvent", { eventName = "projectileHit", hitPos = hitPos, hitTime = hitTime, hitVelocity = hitVelocity, attacker = attacker, damage = damage })
			end
		end
	end

	if projectileUuid == projectile_pesticide then
		local forward = sm.vec3.new( 0, 1, 0 )
		local randomDir = forward:rotateZ( math.random( 0, 359 ) )
		local effectPos = hitPos
		local success, result = sm.physics.raycast( hitPos + sm.vec3.new( 0, 0, 0.1 ), hitPos - sm.vec3.new( 0, 0, PESTICIDE_SIZE.z * 0.5 ), nil, sm.physics.filter.static + sm.physics.filter.dynamicBody )
		if success then
			effectPos = result.pointWorld + sm.vec3.new( 0, 0, PESTICIDE_SIZE.z * 0.5 )
		end
		g_pesticideManager:sv_addPesticide( self, effectPos, sm.vec3.getRotation( forward, randomDir ) )
	end

	if projectileUuid == projectile_glowstick then
		sm.harvestable.createHarvestable( hvs_remains_glowstick, hitPos, sm.vec3.getRotation( sm.vec3.new( 0, 1, 0 ), hitVelocity:normalize() ) )
	end

	if projectileUuid == projectile_explosivetape then
		sm.physics.explode( hitPos, 7, 2.0, 6.0, 25.0, "RedTapeBot - ExplosivesHit" )
	end
end


function World:sv_pickup_onPickup( trigger, result )
    local index = trigger:getUserData().index
    local pickupData = self.sv.pickups[index]

    if not pickupData.active --[[or pickupData.remainingUses == 0]] then return end

    local playersEntered = 0
    for v, k in pairs(result) do
        if sm.exists(k) then
            local player = k:getPlayer()
            if player ~= nil and not player.character:isDowned() and not player.character:isSwimming() and not player.character:isDiving() then
                local publicData = player:getPublicData()
                local compare = publicData.stats[pickupData.type]

                if compare < publicData.stats["max"..pickupData.type] then
                    sm.event.sendToPlayer(player, "sv_restore"..pickupData.type, pickupData.amount)
                    playersEntered = playersEntered + 1
                end
            end
        end
    end

    if playersEntered > 0 then
        pickupData.active = false
        --pickupData.remainingUses = pickupData.remainingUses - 1
        self.network:sendToClients("cl_managePickupEffect", { id = index, active = pickupData.active, pos = pickupData.pos })
    end
end

function World:sv_weaponPickup_onPickup( trigger, result )
    local index = trigger:getUserData().index
    local pickupData = self.sv.pickups[index]
    if not pickupData.active --[[or pickupData.remainingUses == 0]] then return end

    local players = self:getPlayersInTrigger( result )
    local theLuckyOne = players[math.random(#players)]
    local inv = theLuckyOne:getInventory()
    local weaponID = pickupData.weaponID
    local uuid = g_weaponUUIDs[weaponID]
    local canObtainGun = not inv:canSpend(uuid, 1)

    if canObtainGun then
        sm.container.beginTransaction()
        sm.container.collect( inv, uuid, 1 )
        sm.container.endTransaction()
    end

    local public = theLuckyOne:getPublicData()
    local ammoType = g_weaponToAmmoType[weaponID]
    local canCollectAmmo = public.stats[ammoType] < public.stats["max"..ammoType]

    if canCollectAmmo then
        sm.event.sendToPlayer(theLuckyOne, "sv_restoreammo",
            {
                type = ammoType,
                amount = g_ammoPickupAmounts[ammoType]
            }
        )
    end

    if canObtainGun or canCollectAmmo then
        pickupData.active = false
        self.network:sendToClients("cl_managePickupEffect", { id = index, active = pickupData.active, pos = pickupData.pos })
    end
end


function World:sv_createPickups()
    local pickups = g_arenaData[g_currentArena].pickups

    local dataToSend = {}
    for v, k in pairs(pickups) do
        local pickup = k
        pickup.pos = tableToVec3(pickup.pos)
        pickup.trigger = sm.areaTrigger.createBox( pickupSize, pickup.pos, sm.quat.identity(), sm.areaTrigger.filter.character, { index = v, weaponID = k.weaponID } )
        pickup.trigger:bindOnStay( k.weaponID ~= nil and "sv_weaponPickup_onPickup" or "sv_pickup_onPickup" )
        pickup.active = true
        pickup.cd = k.respawnTime
        --pickup.remainingUses = pickup.maxUses
        self.sv.pickups[#self.sv.pickups+1] = pickup

		dataToSend[#dataToSend+1] = { pos = pickup.pos, type = pickup.type, weaponID = pickup.weaponID }
    end

    self.network:sendToClients("cl_createPickups", dataToSend)
end

function World:sv_resetPickups()
    for v, k in pairs(self.sv.pickups) do
        k.active = true
        --k.remainingUses = k.maxUses

        self.network:sendToClients("cl_managePickupEffect", { id = v, active = k.active, pos = k.pos })
    end
end

function World:sv_deletePickups()
    for v, k in pairs(self.sv.pickups) do
        self.sv.pickups[v] = nil

        self.network:sendToClients("cl_managePickupEffect", { id = v, active = false, delete = true })
    end
end


function World:sv_hazard_onEnter( trigger, result )
    local type = trigger:getUserData().type
    for k, v in pairs(self:getPlayersInTrigger( result )) do
        sm.event.sendToPlayer( v, "sv_setHazard", type )
    end
end

function World:sv_hazard_onExit( trigger, result )
    for k, v in pairs(self:getPlayersInTrigger( result )) do
        sm.event.sendToPlayer( v, "sv_setHazard", nil )
    end
end

function World:sv_createHazards()
    local hazards = g_arenaData[g_currentArena].hazards

    local dataToSend = {}
    for v, k in pairs(hazards) do
        local hazard = k
        local pos = tableToVec3(hazard.pos)
        local size = tableToVec3(hazard.size)
        hazard.pos = pos
        hazard.trigger = sm.areaTrigger.createBox( size, pos, sm.quat.identity(), sm.areaTrigger.filter.character, { index = v, type = hazard.type } )
        hazard.trigger:bindOnEnter( "sv_hazard_onEnter" )
        hazard.trigger:bindOnExit( "sv_hazard_onExit" )
        self.sv.hazards[#self.sv.hazards+1] = hazard

		dataToSend[#dataToSend+1] = { pos = pos, size = size, type = hazard.type }
    end

    self.network:sendToClients("cl_createHazards", dataToSend)
end


function World:sv_teleporter_onEnter( trigger, result )
    local userData = trigger:getUserData()
    local tpData = self.sv.teleporters[userData.tpPairIndex]
    local pairData = tpData[userData.tpIndex == 1 and 2 or 1]
    local dir = tableToVec3(pairData.direction)
    local pos = tableToVec3(pairData.pos)

    for k, obj in pairs(self:getTeleportableObjectsInTrigger(result)) do
        if type(obj) == "Player" then
            local vel = obj.character.velocity
            local char = sm.character.createCharacter( obj, self.world, pos + dir * 2, getYawPitch(dir), 0 )
            obj:setCharacter( char )
            sm.physics.applyImpulse( char, vel * char.mass )

            --obj.character:setWorldPosition( pos + dir * 2 )
        else
            local shapeVel = obj.velocity
            local shape = sm.shape.createPart( obj.uuid, pos + dir * 2, sm.vec3.getRotation( axis_y, dir ), true, true )
            shape.interactable:setPublicData( obj.interactable:getPublicData() )
            sm.physics.applyImpulse( shape, dir * shapeVel * shape.mass, true )

            obj:destroyShape(0)
        end
    end
end

function World:sv_createTeleporters()
    local dataToSend = {}
    for v, data in pairs(g_arenaData[g_currentArena].teleporters) do
        local teleporters = {}
        local visualData = {}
        local tpColour = sm.color.new(data.colour)

        for i, k in pairs(data.tps) do
            local teleporter = k
            local pos = tableToVec3(teleporter.pos)
            local size = tableToVec3(teleporter.size)
            local dir = tableToVec3(teleporter.direction)

            teleporter.pos = pos
            teleporter.trigger = sm.areaTrigger.createBox(
                size,
                pos,
                sm.vec3.getRotation( axis_y, dir ),
                sm.areaTrigger.filter.character + sm.areaTrigger.filter.dynamicBody,
                {
                    tpPairIndex = v,
                    tpIndex = i
                }
            )
            teleporter.trigger:bindOnEnter( "sv_teleporter_onEnter" )

            teleporters[#teleporters+1] = teleporter
            visualData[#visualData+1] = { pos = pos, dir = dir, size = size, colour = tpColour }
        end

        self.sv.teleporters[#self.sv.teleporters+1] = teleporters
		dataToSend[#dataToSend+1] = visualData
    end

    self.network:sendToClients("cl_createTeleporters", dataToSend)
end

function World:getPlayersInTrigger( result )
    local players = {}
    for v, k in pairs(result) do
        if sm.exists(k) then
            local player = k:getPlayer()
            if player ~= nil then
                local char = player.character
                if not char:isDowned() and not char:isSwimming() and not char:isDiving() then
                    players[#players+1] = player
                end
            end
        end
    end

    return players
end

function World:getTeleportableObjectsInTrigger( result )
    local objs = {}
    for v, obj in pairs(result) do
        if sm.exists(obj) then
            if type(obj) == "Character" then
                local player = obj:getPlayer()
                if player ~= nil then
                    local char = player.character
                    if not char:isDowned() and not char:isSwimming() and not char:isDiving() then
                        objs[#objs+1] = player
                    end
                end
            else
                local shape = obj:getShapes()[1]
                if shape.uuid == sm.uuid.new("27231323-22b2-446b-b27f-7942c47cce46") then
                    objs[#objs+1] = shape
                end
            end
        end
    end

    return objs
end



function World:client_onCreate()
    self.cl = {}
	self.cl.pickups = {}
	self.cl.hazards = {}
	self.cl.teleporters = {}

    if g_pesticideManager == nil then
		assert( not sm.isHost )
		g_pesticideManager = PesticideManager()
	end
	g_pesticideManager:cl_onCreate()
end

function World:cl_createPickups( data )
    for v, k in pairs(data) do
        local pickup = sm.effect.createEffect("ShapeRenderable")
        local uuid = sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a")
        local isWeapon = k.type == "weapon"
        if isWeapon then
            uuid = GetToolItemUUID(g_weaponUUIDs[k.weaponID])
        end

        pickup:setParameter("uuid", uuid)
        pickup:setPosition( k.pos )

        if isWeapon then
            pickup:setScale(weaponPickupSize)
            pickup:setRotation( default_weaponPickup_rotation )
        else
            pickup:setParameter("color", g_pickupColours[k.type])
            pickup:setScale(pickupSize)
        end

        pickup:start()

        self.cl.pickups[#self.cl.pickups+1] = {
            effect = pickup,
            spin = isWeapon,
            spinTime = isWeapon and math.random(weaponPickupSpinOffset.min, weaponPickupSpinOffset.max) or nil,
            spinSpeed = isWeapon and randomInvert(weaponPickupSpinSpeed, 0.5) or nil,
            defaultPos = isWeapon and k.pos or nil,
            bobTime = isWeapon and math.random(weaponPickupBobOffset.min, weaponPickupBobOffset.max) or nil,
            bobSpeed = isWeapon and weaponPickupBobSpeed or nil
        }
    end
end

function World:cl_managePickupEffect( args )
    if args.active then
		sm.effect.playEffect( "Part - Upgrade", args.pos, sm.vec3.zero(), sm.vec3.getRotation( sm.vec3.new(0,1,0), sm.vec3.new(0,0,1) ) )
        self.cl.pickups[args.id].effect:start()
    else
        self.cl.pickups[args.id].effect:stop()
    end

    if args.delete then
        self.cl.pickups[args.id] = nil
    end
end

function World:cl_createHazards( data )
    for v, k in pairs(data) do
        local hazard = sm.effect.createEffect("ShapeRenderable")
        hazard:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
        hazard:setParameter("color", g_hazardColours[k.type])
        hazard:setPosition( k.pos )
        hazard:setScale( k.size )
        hazard:start()

        self.cl.hazards[#self.cl.hazards+1] = hazard
    end
end

function World:cl_createTeleporters( data )
    for k, pair in pairs(data) do
        for k2, tpData in pairs(pair) do
            local teleporter = sm.effect.createEffect("ShapeRenderable")
            teleporter:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
            teleporter:setParameter("color", tpData.colour)
            teleporter:setPosition( tpData.pos )
            teleporter:setRotation( sm.vec3.getRotation( axis_y, tpData.dir ) )
            teleporter:setScale( tpData.size * 2 )
            teleporter:start()

            self.cl.teleporters[#self.cl.teleporters+1] = teleporter
        end
    end
end

function World:client_onUpdate(dt)
    for k, pickup in pairs(self.cl.pickups) do
        if pickup.spin then
            pickup.spinTime = pickup.spinTime + dt * pickup.spinSpeed
            pickup.bobTime = pickup.bobTime + dt * pickup.bobSpeed

            local rot = default_weaponPickup_rotation * sm.quat.angleAxis( math.rad(pickup.spinTime), default_weaponPickup_direction )
            pickup.effect:setPosition( pickup.defaultPos + sm.vec3.new(0,0,math.sin(pickup.bobTime)/8) - rot * weaponPickupPosOffset  )
            pickup.effect:setRotation( rot )
        end
    end
end

function World.cl_n_pesticideMsg( self, msg )
	g_pesticideManager[msg.fn]( g_pesticideManager, msg )
end