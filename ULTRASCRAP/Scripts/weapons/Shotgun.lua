dofile( "$GAME_DATA/Scripts/game/AnimationUtil.lua" )
dofile( "$SURVIVAL_DATA/Scripts/util.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua" )
dofile( "$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua" )

dofile "$CONTENT_DATA/Scripts/weapons/BaseWeapon.lua"
dofile "$CONTENT_DATA/Scripts/util.lua"


---@class Shotgun : ToolClass
---@field fpAnimations table
---@field tpAnimations table
---@field shootEffect Effect
---@field shootEffectFP Effect

Shotgun = class( BaseWeapon )
Shotgun.damage = 16
Shotgun.renderables = {
	{
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
		"$CONTENT_DATA/Characters/char_spudgun_barrel_frier.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
	},
	{
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
		"$CONTENT_DATA/Characters/char_spudgun_barrel_frier.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
		"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
	}
}
Shotgun.renderablesTp = {
	"$GAME_DATA/Character/Char_Male/Animations/char_male_tp_spudgun.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_tp_animlist.rend"
}
Shotgun.renderablesFp = {
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/char_spudgun_fp_animlist.rend"
}
for k, v in pairs( Shotgun.renderables ) do
	sm.tool.preloadRenderables( v )
end
sm.tool.preloadRenderables( Shotgun.renderablesTp )
sm.tool.preloadRenderables( Shotgun.renderablesFp )

local pumpColours = {
	sm.color.new("#11ab0c"),
	sm.color.new("#de800d"),
	sm.color.new("#de300d"),
	sm.color.new("#de0d0d")
}
local flashFrequency = 40 / 4
local flashColours = {
	pumpColours[#pumpColours],
	sm.color.new(0,0,0)
}
local MaxCoreChargeColour = sm.color.new(0,0.75,1)
local MaxCoreCharge = 5
local BaseCoreImpulse = 10
local CoreUUID = sm.uuid.new("77331e1a-0b07-427c-acdd-2d090db5c08d")

function Shotgun.client_onCreate( self )
	self.shootEffect = sm.effect.createEffect( "SpudgunFrier - FrierMuzzel" )
	self.shootEffectFP = sm.effect.createEffect( "SpudgunFrier - FPFrierMuzzel" )

	self.cl = {}
	self.cl.flashing = false
	self.cl.flashTimer = Timer()
	self.cl.flashTimer:start( flashFrequency )
	self.cl.flashCount = 1

	self:init( "shotgun", Shotgun )

	if not self.isLocal then return end

	self.cl.canFireTimer = Timer()
	self.cl.canFireTimer:start( 10 )
	self.cl.canFireTimer.count = self.cl.canFireTimer.ticks

	self.cl.pumpCount = 1
	self.cl.canPumpTimer = Timer()
	self.cl.canPumpTimer:start( 20 )

	self.cl.coreCharge = 0
	self.cl.coreCoolDownTimer = Timer()
	self.cl.coreCoolDownTimer:start( 60 )
	self.cl.coreCoolDownTimer.count = self.cl.coreCoolDownTimer.ticks
end




function Shotgun:client_onToggle()
	self:modSwap()
	self.fireCooldownTimer = 0
	self.cl.canFireTimer:reset()

	return true
end

function Shotgun:client_onFixedUpdate( dt )
	if self.cl.flashing then
		self.cl.flashTimer:tick()
		if self.cl.flashTimer:done() then
			self.cl.flashTimer:start(flashFrequency)
			self:cl_changePumpColour( { "flash", self.cl.flashCount } )
			if self.cl.flashCount == 1 then
				sm.audio.play( "Retrobass" )
			end

			self.cl.flashCount = self.cl.flashCount == 2 and 1 or 2
		end
	end

	if not self.isLocal then return end

	self.cl.canFireTimer:tick()
	self.cl.canPumpTimer:tick()
	self.cl.coreCoolDownTimer:tick()

	if self.cl.modIndex == 1 then
		if self.cl.coreCoolDownTimer:done() then
			if self.cl.rmb == 2 then
				self.cl.coreCharge = sm.util.clamp(self.cl.coreCharge + dt * 6, 0, MaxCoreCharge)
			elseif self.cl.coreCharge > 0 and isAnyOf(self.cl.rmb, {0,3}) then
				self:cl_spawnCore()
			end
		else
			self.cl.coreCharge = sm.util.clamp(self.cl.coreCharge - dt * 12, 0, MaxCoreCharge)
		end

		local colour = ColourLerp(g_weaponColours[1], MaxCoreChargeColour, self.cl.coreCharge/MaxCoreCharge)
		self.tool:setFpColor(colour)
		self.tool:setTpColor(colour)
	end
end

function Shotgun:cl_spawnCore()
	self.network:sendToServer("sv_spawnCore", { charge = self.cl.coreCharge, pos = sm.camera.getPosition() })
	self.cl.coreCoolDownTimer:reset()
	setFpAnimation( self.fpAnimations, "shoot", 0.05 )
end

function Shotgun:sv_spawnCore( args )
	local owner = self.tool:getOwner()
	local char = owner.character
	local dir = char.direction
	local shape = sm.shape.createPart( CoreUUID, args.pos - sm.vec3.one() / 8 + dir, sm.quat.identity(), true, true )
	sm.physics.applyImpulse(shape, dir * BaseCoreImpulse * shape.mass * (1 + args.charge), true)

	self:sv_n_onShoot()
end

function Shotgun:sv_toggleFlash( toggle )
	self.network:sendToClients("cl_toggleFlash", toggle )
end

function Shotgun:cl_toggleFlash( toggle )
	self.cl.flashing = toggle
	self.cl.flashCount = 1
	self.cl.flashTimer:reset()
end

function Shotgun:sv_changePumpColour( data )
	self.network:sendToClients("cl_changePumpColour", data)
end

function Shotgun:cl_changePumpColour( data )
	if data[1] == "flash" then
		self.tool:setFpColor(flashColours[data[2]])
		self.tool:setTpColor(flashColours[data[2]])
		return
	else
		self.cl.flashing = false
	end

	local pumps = data[2]
	self.tool:setFpColor(pumpColours[pumps])
	self.tool:setTpColor(pumpColours[pumps])
	if pumps == #pumpColours then
		self.cl.flashing = true
	end
end





function Shotgun.client_onUpdate( self, dt )
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
	local blend = 1 - math.pow( 1 - 1 / self.aimBlendSpeed, dt * 60 )
	self.aimWeight = sm.util.lerp( self.aimWeight, 0.0, blend )

	self.tool:updateCamera( 2.8, 30.0, sm.vec3.new( 0.65, 0.0, 0.05 ), self.aimWeight )
	self.tool:updateFpCamera( 30.0, sm.vec3.new( 0.0, 0.0, 0.0 ), self.aimWeight, bobbing )
end

function Shotgun.client_onEquip( self, animate )

	if animate then
		sm.audio.play( "PotatoRifle - Equip", self.tool:getPosition() )
	end

	self.wantEquipped = true
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
	self.aimWeight = math.max( cameraWeight, cameraFPWeight )
	self.jointWeight = 0.0

	self:onEquip()

	if self.isLocal then
		self.cl.canFireTimer:reset()
	end
end

function Shotgun.client_onUnequip( self, animate )
	self.wantEquipped = false
	self.equipped = false
	if sm.exists( self.tool ) then
		if animate then
			sm.audio.play( "PotatoRifle - Unequip", self.tool:getPosition() )
		end
		setTpAnimation( self.tpAnimations, "putdown" )
		if self.isLocal then
			if self.cl.modIndex == 1 then
				self.cl.coreCharge = 0
			elseif self.cl.modIndex == 2 then
				self.cl.pumpCount = 1
				self.network:sendToServer("sv_toggleFlash", false)
				self.network:sendToServer("sv_changePumpColour", { "abcd", self.cl.pumpCount })
			end

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

function Shotgun:sv_n_onShoot()
	self.network:sendToClients( "cl_onShoot" )
end

function Shotgun:cl_onShoot()
	self.tpAnimations.animations.idle.time = 0
	self.tpAnimations.animations.shoot.time = 0

	setTpAnimation( self.tpAnimations, "shoot", 10.0 )

	if self.isLocal then
		local dir = sm.localPlayer.getDirection()
		local firePos = self.tool:getFpBonePos( "pejnt_barrel" )
		local effectPos = firePos + dir * 0.2
		local rot = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), dir )

		self.shootEffectFP:setPosition( effectPos )
		self.shootEffectFP:setVelocity( self.tool:getMovementVelocity() )
		self.shootEffectFP:setRotation( rot )
	end

	local pos = self.tool:getTpBonePos( "pejnt_barrel" )
	local dir = self.tool:getTpBoneDir( "pejnt_barrel" )
	local effectPos = pos + dir * 0.2
	local rot = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), dir )

	self.shootEffect:setPosition( effectPos )
	self.shootEffect:setVelocity( self.tool:getMovementVelocity() )
	self.shootEffect:setRotation( rot )

	if self.tool:isInFirstPersonView() then
		self.shootEffectFP:start()
	else
		self.shootEffect:start()
	end

end

function Shotgun.cl_onPrimaryUse( self, state )
	if self.tool:getOwner().character == nil then
		return
	end

	if self.fireCooldownTimer <= 0.0 then
		local firstPerson = self.tool:isInFirstPersonView()
		local dir = sm.localPlayer.getDirection()
		local firePos = self:calculateFirePosition()
		local fakePosition = self:calculateTpMuzzlePos()
		local fakePositionSelf = fakePosition
		if firstPerson then
			fakePositionSelf = self:calculateFpMuzzlePos()
		end

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

		dir = dir:rotate( math.rad( 0.955 ), sm.camera.getRight() ) -- 50 m sight calibration

		-- Spread
		local fireMode = self.normalFireMode
		local recoilDispersion = 1.0 - ( math.max(fireMode.minDispersionCrouching, fireMode.minDispersionStanding ) + fireMode.maxMovementDispersion )

		local spreadFactor = fireMode.spreadCooldown > 0.0 and clamp( self.spreadCooldownTimer / fireMode.spreadCooldown, 0.0, 1.0 ) or 0.0
		spreadFactor = clamp( self.movementDispersion + spreadFactor * recoilDispersion, 0.0, 1.0 )
		local spreadDeg =  fireMode.spreadMinAngle + ( fireMode.spreadMaxAngle - fireMode.spreadMinAngle ) * spreadFactor

		dir = sm.noise.gunSpread( dir, spreadDeg )

		local owner = self.tool:getOwner()
		if owner then
			if self.cl.modIndex == 1 then
				if self.cl.coreCharge > 0 then
					self:cl_spawnCore()
				else
					dir = sm.noise.gunSpread( dir, spreadDeg )
					sm.projectile.projectileAttack( projectile_fries, self.damage, firePos, dir * fireMode.fireVelocity, owner, fakePosition, fakePositionSelf )
				end
			else
				if self.cl.pumpCount == #pumpColours then
					self.network:sendToServer("sv_explode")
				else
					for i = 1, self.cl.pumpCount do
						dir = sm.noise.gunSpread( dir, spreadDeg * math.random( 2, 10 ) )
						sm.projectile.projectileAttack( projectile_fries, self.damage, firePos, dir * fireMode.fireVelocity, owner, fakePosition, fakePositionSelf )
					end
				end

				self.cl.pumpCount = 1
				self.network:sendToServer("sv_changePumpColour", { "abcd", self.cl.pumpCount } )
				self.network:sendToServer("sv_toggleFlash", false)
			end
		end

		-- Timers
		self.fireCooldownTimer = fireMode.fireCooldown
		self.spreadCooldownTimer = math.min( self.spreadCooldownTimer + fireMode.spreadIncrement, fireMode.spreadCooldown )
		self.sprintCooldownTimer = self.sprintCooldown

		self.network:sendToServer( "sv_n_onShoot" )
		setFpAnimation( self.fpAnimations, "shoot", 0.05 )
	end
end

function Shotgun:sv_explode()
	local char = self.tool:getOwner().character
	local worldPos = char.worldPosition
	local finalPos = worldPos - char.direction
	local hit, result = sm.physics.raycast(worldPos, finalPos)
	if hit then finalPos = result.pointWorld end


	sm.physics.explode( finalPos, 5, 5, 7.5, 150, "PropaneTank - ExplosionSmall" )
end

function Shotgun.client_onEquippedUpdate( self, lmb, rmb, f )

	if self.cl.canFireTimer:done() and isAnyOf(lmb, {1,2}) then
		self:cl_onPrimaryUse()
	end

	if self.cl.modIndex == 1 then
		sm.gui.setProgressFraction(self.cl.coreCharge / MaxCoreCharge)
	end

	if self.cl.modIndex == 2 and (rmb == 1 or self.cl.canPumpTimer:done() and rmb == 2) then
		local maxPumps = #pumpColours
		self.cl.pumpCount = self.cl.pumpCount < maxPumps and self.cl.pumpCount + 1 or maxPumps

		if self.cl.pumpCount == maxPumps and not self.cl.flashing then
			self.network:sendToServer("sv_toggleFlash", true)
		end

		self:onPump()
		self.network:sendToServer( "sv_n_onPump" )
		setFpAnimation( self.fpAnimations, "shoot", 0.05 )
		self.network:sendToServer("sv_changePumpColour", { "abcd", self.cl.pumpCount } )

		self.cl.canPumpTimer:reset()
	end

	self:onEquipped( lmb, rmb, f )

	return true, true
end

function Shotgun.sv_n_onPump( self )
	self.network:sendToClients( "cl_n_onPump" )
end

function Shotgun.cl_n_onPump( self )
	if not self.tool:isLocal() and self.tool:isEquipped() then
		self:onPump()
	end
end

function Shotgun.onPump( self )
	self.tpAnimations.animations.idle.time = 0
	self.tpAnimations.animations.shoot.time = 0

	sm.audio.play("Button on", self.tool:getOwner().character.worldPosition)
	setTpAnimation( self.tpAnimations, "shoot", 10.0 )
end




function Shotgun.loadAnimations( self )

	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			shoot = { "spudgun_shoot", { crouch = "spudgun_crouch_shoot" } },
			idle = { "spudgun_idle" },
			pickup = { "spudgun_pickup", { nextAnimation = "idle" } },
			putdown = { "spudgun_putdown" }
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
			}
		)
	end

	self.normalFireMode = {
		fireCooldown = 1,
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

function Shotgun.calculateFirePosition( self )
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

function Shotgun.calculateTpMuzzlePos( self )
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
function Shotgun:calculateFpMuzzlePos()
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

	return self.tool:getFpBonePos( "pejnt_barrel" ) + sm.vec3.lerp( muzzlePos45, muzzlePos90, fovScale )
end