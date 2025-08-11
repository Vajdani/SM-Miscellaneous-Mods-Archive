dofile( "$GAME_DATA/Scripts/game/AnimationUtil.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )

dofile( "$SURVIVAL_DATA/Scripts/game/util/Timer.lua" )
dofile "$CONTENT_DATA/Scripts/weapons/BaseWeapon.lua"
dofile "$CONTENT_DATA/Scripts/util.lua"


---@class Revolver : ToolClass
---@field fpAnimations table
---@field tpAnimations table
---@field shootEffect Effect
---@field shootEffectFP Effect

Revolver = class( BaseWeapon )
Revolver.Damage = 30
Revolver.PiercingShotRange = 25
Revolver.MaxPiercerCharge = 3
Revolver.PiercerCooldown = 60
Revolver.MaxCoins = 4
Revolver.CoinRecharge = 4 * 40
Revolver.CoinColours = {
	low = sm.color.new("#ff0000"),
	med = sm.color.new("#e3e30b"),
	full = sm.color.new("#16e30b")
}
Revolver.renderables = {
	{
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
		"$CONTENT_DATA/Characters/char_spudgun_barrel_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
	},
	{
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
		"$CONTENT_DATA/Characters/char_spudgun_barrel_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
	}
}
Revolver.renderablesTp = {
	"$GAME_DATA/Character/Char_Male/Animations/char_male_tp_spudgun.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_tp_animlist.rend"
}
Revolver.renderablesFp = {
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_fp_animlist.rend"
}
for k, v in pairs( Revolver.renderables ) do
	sm.tool.preloadRenderables( v )
end
sm.tool.preloadRenderables( Revolver.renderablesTp )
sm.tool.preloadRenderables( Revolver.renderablesFp )


function Revolver.client_onCreate( self )
	self.shootEffect = sm.effect.createEffect( "SpudgunBasic - BasicMuzzel" )
	self.shootEffectFP = sm.effect.createEffect( "SpudgunBasic - FPBasicMuzzel" )

	self.cl = {}
	self:init( "revolver", Revolver )

	if not self.isLocal then return end

	self.cl.piercerCharge = 0
	self.cl.piercerCooldown = Timer()
	self.cl.piercerCooldown:start( self.PiercerCooldown )
	self.cl.piercerCooldown.count = self.cl.piercerCooldown.ticks

	self.cl.coin = {}
	self.cl.coin.ammo = 4
	self.cl.coin.recharge = Timer()
	self.cl.coin.recharge:start( self.CoinRecharge )
	self.cl.coin.hud = sm.gui.createGuiFromLayout( "$CONTENT_DATA/Gui/coins.layout", false,
		{
			isHud = true,
			isInteractive = false,
			needsCursor = false
		}
	)
end




function Revolver:client_onToggle()
	self:modSwap()
	if self.cl.modIndex == 1 then
		self.cl.coin.hud:open()
	else
		self.cl.coin.hud:close()
	end

	return true
end

function Revolver:client_onFixedUpdate( dt )
	if not self.isLocal then return end

	self.cl.piercerCooldown:tick()
	if self.cl.modIndex == 1 and self.cl.piercerCooldown:done() and self.cl.rmb == 2 and self.cl.lmb == 0 then
		self.cl.piercerCharge = sm.util.clamp(self.cl.piercerCharge + dt * 3, 0, self.MaxPiercerCharge)
	end

	if self.cl.coin.ammo < self.MaxCoins then
		self.cl.coin.recharge:tick()
		if self.cl.coin.recharge:done() then
			self.cl.coin.ammo = self.cl.coin.ammo + 1
			self.cl.coin.recharge:reset()
		end
	end

	if self.cl.modIndex == 2 then
		for i = 1, self.cl.coin.ammo do
			self.cl.coin.hud:setColor( "coin"..tostring(i), self.CoinColours.full )
		end

		local fillAt = self.cl.coin.ammo + 1
		if fillAt <= 4 then
			local colour = self.cl.coin.recharge.count >= self.CoinRecharge/2 and self.CoinColours.med or self.CoinColours.low
			self.cl.coin.hud:setColor( "coin"..tostring(fillAt), colour )
			--self.cl.coin.hud:setColor( "coin"..tostring(fillAt), ColourLerp( self.CoinColours.low, self.CoinColours.full, self.cl.coin.recharge.count/self.CoinRecharge ) )

			for i = fillAt + 1, 4 do
				self.cl.coin.hud:setColor( "coin"..tostring(i), self.CoinColours.low )
			end
		end
	end
end

function Revolver:sv_piercingShot( charge )
	print("pierce shot")
	---@type Player
	local player = self.tool:getOwner()
	local playerChar = player.character
	local rayStart = playerChar.worldPosition + sm.vec3.new(0,0,0.575)
	local dir = playerChar.direction
	local rayLength = self.PiercingShotRange * (1 + charge)
	for i = 1, 15 do
		local hit, result = sm.physics.raycast( rayStart, rayStart + dir * rayLength )
		if not hit or result.type ~= "character" then break end

		local char = result:getCharacter()
		local pos = char.worldPosition
		rayLength = rayLength - (rayStart - pos):length()
		rayStart = pos
		if char ~= playerChar then
			sm.projectile.projectileAttack( projectile_potato, self.Damage * charge, result.pointWorld, dir * 10, player )
		end
	end
end



function Revolver.client_onUpdate( self, dt )
	-- First person animation
	local isSprinting =  self.tool:isSprinting()
	local isCrouching =  self.tool:isCrouching()

	if self.isLocal then
		if self.equipped then
			if isSprinting and self.fpAnimations.currentAnimation ~= "sprintInto" and self.fpAnimations.currentAnimation ~= "sprintIdle" then
				swapFpAnimation( self.fpAnimations, "sprintExit", "sprintInto", 0.0 )
			elseif not self.tool:isSprinting() and ( self.fpAnimations.currentAnimation == "sprintIdle" or self.fpAnimations.currentAnimation == "sprintInto" ) then
				swapFpAnimation( self.fpAnimations, "sprintInto", "sprintExit", 0.0 )
			end
		end
		updateFpAnimations( self.fpAnimations, self.equipped, dt )
	end

	if not self.equipped then
		if self.wantEquipped then
			self.wantEquipped = false
			self.equipped = true
		end
		return
	end

	local effectPos, rot

	if self.isLocal then
		local dir = sm.localPlayer.getDirection()
		local firePos = self.tool:getFpBonePos( "pejnt_barrel" )
		effectPos = firePos + dir * 0.2
		rot = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), dir )

		self.shootEffectFP:setPosition( effectPos )
		self.shootEffectFP:setVelocity( self.tool:getMovementVelocity() )
		self.shootEffectFP:setRotation( rot )
	end
	local pos = self.tool:getTpBonePos( "pejnt_barrel" )
	local dir = self.tool:getTpBoneDir( "pejnt_barrel" )

	effectPos = pos + dir * 0.2

	rot = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), dir )


	self.shootEffect:setPosition( effectPos )
	self.shootEffect:setVelocity( self.tool:getMovementVelocity() )
	self.shootEffect:setRotation( rot )

	-- Timers
	self.fireCooldownTimer = math.max( self.fireCooldownTimer - dt, 0.0 )
	self.spreadCooldownTimer = math.max( self.spreadCooldownTimer - dt, 0.0 )
	self.sprintCooldownTimer = math.max( self.sprintCooldownTimer - dt, 0.0 )


	if self.isLocal then
		local dispersion = 0.0
		local fireMode = self.normalFireMode
		local recoilDispersion = 1.0 - ( math.max( fireMode.minDispersionCrouching, fireMode.minDispersionStanding ) + fireMode.maxMovementDispersion )

		if isCrouching then
			dispersion = fireMode.minDispersionCrouching
		else
			dispersion = fireMode.minDispersionStanding
		end

		if self.tool:getRelativeMoveDirection():length() > 0 then
			dispersion = dispersion + fireMode.maxMovementDispersion * self.tool:getMovementSpeedFraction()
		end

		if not self.tool:isOnGround() then
			dispersion = dispersion * fireMode.jumpDispersionMultiplier
		end

		self.movementDispersion = dispersion

		self.spreadCooldownTimer = clamp( self.spreadCooldownTimer, 0.0, fireMode.spreadCooldown )
		local spreadFactor = fireMode.spreadCooldown > 0.0 and clamp( self.spreadCooldownTimer / fireMode.spreadCooldown, 0.0, 1.0 ) or 0.0

		self.tool:setDispersionFraction( clamp( self.movementDispersion + spreadFactor * recoilDispersion, 0.0, 1.0 ) )

		self.tool:setCrossHairAlpha( 1.0 )
		self.tool:setInteractionTextSuppressed( false )
	end

	-- Sprint block
	local blockSprint = self.sprintCooldownTimer > 0.0
	self.tool:setBlockSprint( blockSprint )

	local playerDir = self.tool:getSmoothDirection()
	local angle = math.asin( playerDir:dot( sm.vec3.new( 0, 0, 1 ) ) ) / ( math.pi / 2 )

	local crouchWeight = self.tool:isCrouching() and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight

	local totalWeight = 0.0
	for name, animation in pairs( self.tpAnimations.animations ) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min( animation.weight + ( self.tpAnimations.blendSpeed * dt ), 1.0 )

			if animation.time >= animation.info.duration - self.blendTime then
				if name == "shoot" then
					setTpAnimation( self.tpAnimations, "idle", 10.0 )
				elseif name == "pickup" then
					setTpAnimation( self.tpAnimations, "idle", 0.001 )
				elseif animation.nextAnimation ~= "" then
					setTpAnimation( self.tpAnimations, animation.nextAnimation, 0.001 )
				end
			end
		else
			animation.weight = math.max( animation.weight - ( self.tpAnimations.blendSpeed * dt ), 0.0 )
		end

		totalWeight = totalWeight + animation.weight
	end

	totalWeight = totalWeight == 0 and 1.0 or totalWeight
	for name, animation in pairs( self.tpAnimations.animations ) do
		local weight = animation.weight / totalWeight
		if name == "idle" then
			self.tool:updateMovementAnimation( animation.time, weight )
		elseif animation.crouch then
			self.tool:updateAnimation( animation.info.name, animation.time, weight * normalWeight )
			self.tool:updateAnimation( animation.crouch.name, animation.time, weight * crouchWeight )
		else
			self.tool:updateAnimation( animation.info.name, animation.time, weight )
		end
	end

	-- Third Person joint lock
	local relativeMoveDirection = self.tool:getRelativeMoveDirection()
	if ( ( ( self.tpAnimations.currentAnimation == "shoot" and ( relativeMoveDirection:length() > 0 or isCrouching) ) ) and not isSprinting ) then
		self.jointWeight = math.min( self.jointWeight + ( 10.0 * dt ), 1.0 )
	else
		self.jointWeight = math.max( self.jointWeight - ( 6.0 * dt ), 0.0 )
	end

	if ( not isSprinting ) then
		self.spineWeight = math.min( self.spineWeight + ( 10.0 * dt ), 1.0 )
	else
		self.spineWeight = math.max( self.spineWeight - ( 10.0 * dt ), 0.0 )
	end

	local finalAngle = ( 0.5 + angle * 0.5 )
	self.tool:updateAnimation( "spudgun_spine_bend", finalAngle, self.spineWeight )

	local totalOffsetZ = lerp( -22.0, -26.0, crouchWeight )
	local totalOffsetY = lerp( 6.0, 12.0, crouchWeight )
	local crouchTotalOffsetX = clamp( ( angle * 60.0 ) -15.0, -60.0, 40.0 )
	local normalTotalOffsetX = clamp( ( angle * 50.0 ), -45.0, 50.0 )
	local totalOffsetX = lerp( normalTotalOffsetX, crouchTotalOffsetX , crouchWeight )

	local finalJointWeight = ( self.jointWeight )


	self.tool:updateJoint( "jnt_hips", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), 0.35 * finalJointWeight * ( normalWeight ) )

	local crouchSpineWeight = ( 0.35 / 3 ) * crouchWeight

	self.tool:updateJoint( "jnt_spine1", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), ( 0.10 + crouchSpineWeight )  * finalJointWeight )
	self.tool:updateJoint( "jnt_spine2", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), ( 0.10 + crouchSpineWeight ) * finalJointWeight )
	self.tool:updateJoint( "jnt_spine3", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), ( 0.45 + crouchSpineWeight ) * finalJointWeight )
	self.tool:updateJoint( "jnt_head", sm.vec3.new( totalOffsetX, totalOffsetY, totalOffsetZ ), 0.3 * finalJointWeight )


	-- Camera update
	local bobbing = 1
	local blend = 1 - (1 - 1 / self.aimBlendSpeed) ^ (dt * 60)
	self.aimWeight = sm.util.lerp( self.aimWeight, 0.0, blend )

	self.tool:updateCamera( 2.8, 30.0, sm.vec3.new( 0.65, 0.0, 0.05 ), self.aimWeight )
	self.tool:updateFpCamera( 30.0, sm.vec3.new( 0.0, 0.0, 0.0 ), self.aimWeight, bobbing )
end

function Revolver.client_onEquip( self, animate )

	if animate then
		sm.audio.play( "PotatoRifle - Equip", self.tool:getPosition() )
	end

	self.wantEquipped = true
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
	self.aimWeight = math.max( cameraWeight, cameraFPWeight )
	self.jointWeight = 0.0

	self:onEquip()

	if self.isLocal and self.cl.modIndex == 2 then
		self.cl.coin.hud:open()
	end
end

function Revolver.client_onUnequip( self, animate )

	self.wantEquipped = false
	self.equipped = false
	if sm.exists( self.tool ) then
		if animate then
			sm.audio.play( "PotatoRifle - Unequip", self.tool:getPosition() )
		end
		setTpAnimation( self.tpAnimations, "putdown" )
		if self.isLocal then
			self.cl.coin.hud:close()

			self.tool:setMovementSlowDown( false )
			self.tool:setBlockSprint( false )
			self.tool:setCrossHairAlpha( 1.0 )
			self.tool:setInteractionTextSuppressed( false )
			if self.fpAnimations.currentAnimation ~= "unequip" then
				swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
			end
		end
	end
end

function Revolver:sv_n_onShoot( args )
	print("primary fire")
	---@type Vec3, Vec3
	local pos, dir = args.pos, args.dir
	local hit, result = sm.physics.raycast(pos, pos + dir * 100, nil, -1)
	if hit then
		local target = result:getCharacter() or result:getShape() or result:getAreaTrigger()
		local type = type(target)
		if type == "Character" then

		elseif type == "Shape" then
			if isAnyOf(target.uuid, g_detonateAbleObjects) then
				self:sv_detonateObj(target.interactable)
			end
		elseif type == "AreaTrigger" then
			if target:getUserData().type == "coin" then
				
			end
		end
	end

	self.network:sendToClients( "cl_onShoot" )
end

function Revolver:cl_onShoot()
	self.tpAnimations.animations.idle.time = 0
	self.tpAnimations.animations.shoot.time = 0

	setTpAnimation( self.tpAnimations, "shoot", 10.0 )

	if self.tool:isInFirstPersonView() then
		self.shootEffectFP:start()
	else
		self.shootEffect:start()
	end
end

function Revolver.cl_onPrimaryUse( self, state )
	if self.tool:getOwner().character == nil then
		return
	end

	if self.fireCooldownTimer <= 0.0 then
		local firstPerson = self.tool:isInFirstPersonView()
		local dir = sm.localPlayer.getDirection()
		local firePos = self:calculateFirePosition()

		-- Aim assist
		if not firstPerson then
			local raycastPos = sm.camera.getPosition() + sm.camera.getDirection() * sm.camera.getDirection():dot( GetOwnerPosition( self.tool ) - sm.camera.getPosition() )
			local hit, result = sm.localPlayer.getRaycast( 250, raycastPos, sm.camera.getDirection() )
			if hit then
				local norDir = sm.vec3.normalize( result.pointWorld - firePos )
				local dirDot = norDir:dot( dir )

				if dirDot > 0.96592583 then -- max 15 degrees off
					dir = norDir
				else
					local radsOff = math.asin( dirDot )
					dir = sm.vec3.lerp( dir, norDir, math.tan( radsOff ) / 3.7320508 ) -- if more than 15, make it 15
				end
			end
		end

		dir = dir:rotate( math.rad( 0.955 ), sm.camera.getRight() ) -- 50 m sight calibratio

		-- Timers
		local fireMode = self.normalFireMode
		self.fireCooldownTimer = fireMode.fireCooldown
		self.spreadCooldownTimer = math.min( self.spreadCooldownTimer + fireMode.spreadIncrement, fireMode.spreadCooldown )
		self.sprintCooldownTimer = self.sprintCooldown

		self.network:sendToServer( "sv_n_onShoot", { pos = firePos, dir = dir } )
		setFpAnimation( self.fpAnimations, "shoot", 0.05 )
	end
end

function Revolver:sv_detonateObj( obj )
	sm.event.sendToInteractable(obj, "sv_detonate")
end

function Revolver.client_onEquippedUpdate( self, lmb, rmb, f )
	if self.cl.piercerCooldown:done() then
		if lmb == 1 then
			if self.cl.modIndex == 1 and rmb == 2 then
				self.network:sendToServer("sv_piercingShot", self.cl.piercerCharge)
				self.cl.piercerCharge = 0
				self.cl.piercerCooldown:reset()
			else
				self:cl_onPrimaryUse()
			end
		elseif lmb == 2 then
			self:cl_onPrimaryUse()
		end
	end

	if self.cl.modIndex == 1 then
		local fraction = self.cl.piercerCharge > 0 and self.cl.piercerCharge / self.MaxPiercerCharge or 1 - self.cl.piercerCooldown.count / self.cl.piercerCooldown.ticks
		sm.gui.setProgressFraction(fraction)

		if self.cl.piercerCooldown:done() and rmb == 3 and self.cl.piercerCharge > 0 then
			self.network:sendToServer("sv_piercingShot", self.cl.piercerCharge)
			self.cl.piercerCharge = 0
			self.cl.piercerCooldown:reset()
		end
	end

	if self.cl.modIndex == 2 and self.cl.coin.ammo > 0 and rmb == 1 then
		self.network:sendToServer("sv_throwCoin",
			{
				pos = sm.camera.getPosition(),
				moveDir = TranslateMovementDir(self.tool:getRelativeMoveDirection(), self.tool:getOwner().character) --devs making me do extra math smh
			}
		)
		self.cl.coin.ammo = self.cl.coin.ammo - 1
	end

	self:onEquipped( lmb, rmb, f )

	return true, true
end

function Revolver:sv_throwCoin( args )
	local char = self.tool:getOwner().character
	local dir = char.direction

	sm.event.sendToScriptableObject(
		g_ProjectileManager,
		"sv_createProjectile",
		{
			name = "coin",
			pos = args.pos + dir,
			dir = (dir + vec3_up * 0.5 + char.velocity * 0.095):normalize() --[[(dir + vec3_up / 2 + args.moveDir):normalize()]]
		}
	)

	self.network:sendToClients("cl_throwCoin")
end


function Revolver:cl_throwCoin()
	--setTpAnimation( self.tpAnimations, "coin_throw", 0.2 )
    if self.isLocal then
        --setFpAnimation( self.fpAnimations, "coin_throw", 0.001 )
    end
end



function Revolver.loadAnimations( self )

	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			shoot = { "spudgun_shoot", { crouch = "spudgun_crouch_shoot" } },
			idle = { "spudgun_idle" },
			pickup = { "spudgun_pickup", { nextAnimation = "idle" } },
			putdown = { "spudgun_putdown" },

			--coin_throw = { "spudgun_pickup", { nextAnimation = "idle" } },
		}
	)
	local movementAnimations = {
		idle = "spudgun_idle",
		idleRelaxed = "spudgun_relax",

		sprint = "spudgun_sprint",
		runFwd = "spudgun_run_fwd",
		runBwd = "spudgun_run_bwd",

		jump = "spudgun_jump",
		jumpUp = "spudgun_jump_up",
		jumpDown = "spudgun_jump_down",

		land = "spudgun_jump_land",
		landFwd = "spudgun_jump_land_fwd",
		landBwd = "spudgun_jump_land_bwd",

		crouchIdle = "spudgun_crouch_idle",
		crouchFwd = "spudgun_crouch_fwd",
		crouchBwd = "spudgun_crouch_bwd"
	}

	for name, animation in pairs( movementAnimations ) do
		self.tool:setMovementAnimation( name, animation )
	end

	setTpAnimation( self.tpAnimations, "idle", 5.0 )

	if self.isLocal then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				equip = { "spudgun_pickup", { nextAnimation = "idle" } },
				unequip = { "spudgun_putdown" },

				idle = { "spudgun_idle", { looping = true } },
				shoot = { "spudgun_shoot", { nextAnimation = "idle" } },

				sprintInto = { "spudgun_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
				sprintExit = { "spudgun_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },
				sprintIdle = { "spudgun_sprint_idle", { looping = true } },

				--coin_throw = { "spudgun_pickup", { nextAnimation = "idle" } },
			}
		)
	end

	self.normalFireMode = {
		fireCooldown = 0.50,
		spreadCooldown = 0.18,
		spreadIncrement = 2.6,
		spreadMinAngle = 0.25,
		spreadMaxAngle = 8,
		fireVelocity = 130.0,

		minDispersionStanding = 0.1,
		minDispersionCrouching = 0.04,

		maxMovementDispersion = 0.4,
		jumpDispersionMultiplier = 2
	}

	self.fireCooldownTimer = 0.0
	self.spreadCooldownTimer = 0.0

	self.movementDispersion = 0.0

	self.sprintCooldownTimer = 0.0
	self.sprintCooldown = 0.3

	self.aimBlendSpeed = 3.0
	self.blendTime = 0.2

	self.jointWeight = 0.0
	self.spineWeight = 0.0
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
	self.aimWeight = math.max( cameraWeight, cameraFPWeight )

end

function Revolver.calculateFirePosition( self )
	local crouching = self.tool:isCrouching()
	local firstPerson = self.tool:isInFirstPersonView()
	local dir = sm.localPlayer.getDirection()
	local pitch = math.asin( dir.z )
	local right = sm.localPlayer.getRight()

	local fireOffset = sm.vec3.new( 0.0, 0.0, 0.0 )

	if crouching then
		fireOffset.z = 0.15
	else
		fireOffset.z = 0.45
	end

	if firstPerson then
		fireOffset = fireOffset + right * 0.05
	else
		fireOffset = fireOffset + right * 0.25
		fireOffset = fireOffset:rotate( math.rad( pitch ), right )
	end
	local firePosition = GetOwnerPosition( self.tool ) + fireOffset
	return firePosition
end

function Revolver.calculateTpMuzzlePos( self )
	local crouching = self.tool:isCrouching()
	local dir = sm.localPlayer.getDirection()
	local pitch = math.asin( dir.z )
	local right = sm.localPlayer.getRight()
	local up = right:cross(dir)

	local fakeOffset = sm.vec3.new( 0.0, 0.0, 0.0 )

	--General offset
	fakeOffset = fakeOffset + right * 0.25
	fakeOffset = fakeOffset + dir * 0.5
	fakeOffset = fakeOffset + up * 0.25

	--Action offset
	local pitchFraction = pitch / ( math.pi * 0.5 )
	if crouching then
		fakeOffset = fakeOffset + dir * 0.2
		fakeOffset = fakeOffset + up * 0.1
		fakeOffset = fakeOffset - right * 0.05

		if pitchFraction > 0.0 then
			fakeOffset = fakeOffset - up * 0.2 * pitchFraction
		else
			fakeOffset = fakeOffset + up * 0.1 * math.abs( pitchFraction )
		end
	else
		fakeOffset = fakeOffset + up * 0.1 *  math.abs( pitchFraction )
	end

	local fakePosition = fakeOffset + GetOwnerPosition( self.tool )
	return fakePosition
end

---@return Vec3 Position First person muzzle position
function Revolver:calculateFpMuzzlePos()
	local fovScale = ( sm.camera.getFov() - 45 ) / 45

	local up = sm.localPlayer.getUp()
	local dir = sm.localPlayer.getDirection()
	local right = sm.localPlayer.getRight()

	local muzzlePos45 = sm.vec3.new( 0.0, 0.0, 0.0 )
	local muzzlePos90 = sm.vec3.new( 0.0, 0.0, 0.0 )

	muzzlePos45 = muzzlePos45 - up * 0.15
	muzzlePos45 = muzzlePos45 + right * 0.2
	muzzlePos45 = muzzlePos45 + dir * 1.25

	muzzlePos90 = muzzlePos90 - up * 0.15
	muzzlePos90 = muzzlePos90 + right * 0.2
	muzzlePos90 = muzzlePos90 + dir * 0.25

	---@type Vec3
	local pos = self.tool:getFpBonePos( "pejnt_barrel" )
	return pos + sm.vec3.lerp( muzzlePos45, muzzlePos90, fovScale )
end