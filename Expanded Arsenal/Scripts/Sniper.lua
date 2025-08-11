dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survivalPlayer.lua"

dofile("$CONTENT_DATA/Scripts/util.lua")

local Damage = 150
local maxBreathHold = 3
local baseFireVel = 260
local fireVelIncrease = 40
local projectileUUID = sm.uuid.new("69fc1a2b-77d2-40da-9a82-03fbe3c35a18")

---@class Sniper : ToolClass
---@field tpAnimations table
---@field fpAnimations table
---@field aimFireMode table
---@field normalFireMode table
---@field fireCooldownTimer number
---@field shootEffect Effect
---@field shootEffectFP Effect
---@field blendTime number
---@field aimBlendSpeed number
---@field movementDispersion number
---@field sprintCooldown number
---@field aiming boolean
---@field isLocal boolean
---@field ammo number
---@field breathHold boolean
---@field breathHoldCount number
---@field maxSpread number
Sniper = class()
Sniper.magCapacity = 4
Sniper.reloadAnims = {
	reload = true
}

local renderables = {
	"$CONTENT_DATA/Tools/Sniper/Renderables/sniper.rend"
}
local renderablesTp = {
	"$CONTENT_DATA/Tools/Sniper/sniper_tp.rend",
	"$CONTENT_DATA/Tools/Sniper/sniper_tp_animlist.rend"
}
local renderablesFp = {
	"$CONTENT_DATA/Tools/Sniper/sniper_fp.rend",
	"$CONTENT_DATA/Tools/Sniper/sniper_fp_animlist.rend"
}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

function Sniper:server_onCreate()
	self.network:sendToClient(self.tool:getOwner(), "cl_setAutoReload", self.storage:load())
end

function Sniper.client_onCreate( self )
	self.shootEffect = sm.effect.createEffect( "SpudgunBasic - BasicMuzzel" )
	self.shootEffectFP = sm.effect.createEffect( "SpudgunBasic - FPBasicMuzzel" )

	self.isLocal = self.tool:isLocal()
	if not self.isLocal then return end

	self.isReloading = false
	self.autoReload = false
	self.ammo = self.magCapacity
	self.breathHold = false
	self.breathHoldCount = 0
	self.inaccurate = false
	self.inaccuracyDuration = 1
	self.maxSpread = 8
end

function Sniper:client_onToggle()
	self.autoReload = not self.autoReload
	local text = self.autoReload and "#00ff00ON" or "#ff0000OFF"
	sm.gui.displayAlertText("Automatic reloading: "..text, 2.5)
	self.network:sendToServer("sv_toggleAutoReload", self.autoReload)

	return true
end

function Sniper:sv_toggleAutoReload(reload)
	self.storage:save( { reload } )
end

function Sniper:cl_setAutoReload( reload )
	self.autoReload = reload ~= nil and reload[1] or false
end

function Sniper:client_onReload()
	self:cl_reload()

	return true
end

function Sniper:cl_reload()
	if self.ammo == self.magCapacity or self.tool:isSprinting() then return end

	self.isReloading = true
	self:cl_onReload()
	setFpAnimation( self.fpAnimations, "reload", 0.05 )
	self.network:sendToServer("sv_onReload")
end

function Sniper.sv_onReload( self )
	self.network:sendToClients( "cl_onReload" )
end

function Sniper.cl_onReload( self )
	setTpAnimation( self.tpAnimations, "reload", 10.0 )
	sm.audio.play("PotatoRifle - Reload", self.tool:getOwner().character.worldPosition)
	self.aiming = false
end

function Sniper.client_onUpdate( self, dt )
	local isSprinting = self.tool:isSprinting()
	local isCrouching = self.tool:isCrouching()

	if self.isLocal then
		if self.equipped then
			local current = self.fpAnimations.currentAnimation
			if isSprinting and current ~= "sprintInto" and current ~= "sprintIdle" then
				swapFpAnimation( self.fpAnimations, "sprintExit", "sprintInto", 0.0 )
			elseif not isSprinting and ( current == "sprintIdle" or current == "sprintInto" ) then
				swapFpAnimation( self.fpAnimations, "sprintInto", "sprintExit", 0.0 )
			end

			if self.aiming and not isAnyOf( current, { "aimInto", "aimIdle", "aimShoot" } ) then
				swapFpAnimation( self.fpAnimations, "aimExit", "aimInto", 0.0 )
			end
			if not self.aiming and isAnyOf( current, { "aimInto", "aimIdle", "aimShoot" } ) then
				swapFpAnimation( self.fpAnimations, "aimInto", "aimExit", 0.0 )
			end

			if self.ammo == 0 and not self.isReloading then
				if not self.autoReload then
					sm.gui.setInteractionText("", sm.gui.getKeyBinding("Reload", true), "Reload weapon")
				elseif self.fireCooldownTimer <= 0 then
					self:cl_reload()
				end
			end

			local data = self.fpAnimations.animations[current]
			if data and self.reloadAnims[current] == true then
				if data.time + data.playRate * dt >= data.info.duration then
					self.ammo = self.magCapacity
					self.isReloading = false
				end
			end

			local character = self.tool:getOwner().character
			self.breathHold = character ~= nil and character:isCrouching() and character:isAiming()

			if self.inaccurate then
				self.inaccuracyDuration = self.inaccuracyDuration - dt
				self.maxSpread = 15
				self.aimFireMode.spreadMinAngle = self.maxSpread / 4
				self.normalFireMode.spreadMinAngle = self.maxSpread / 4
				if self.inaccuracyDuration <= 0 then
					self.inaccurate = false
					self.inaccuracyDuration = self.normalFireMode.fireCooldown + 0.5
				end
			else
				self.maxSpread = 8
				self.aimFireMode.spreadMinAngle = 0
				self.normalFireMode.spreadMinAngle = 0
			end

			if self.breathHold and not self.isReloading and self.fireCooldownTimer <= 0.0 then
				self.breathHoldCount = self.breathHoldCount < maxBreathHold and self.breathHoldCount + dt or maxBreathHold

				if self.breathHoldCount < maxBreathHold + 0.025 then
					self.aimFireMode.spreadMaxAngle = self.maxSpread - self.breathHoldCount
					self.normalFireMode.spreadMaxAngle = self.maxSpread - self.breathHoldCount
					self.aimFireMode.fireVelocity = baseFireVel + fireVelIncrease * self.breathHoldCount
				end
			else
				self.aimFireMode.spreadMaxAngle = self.maxSpread
				self.normalFireMode.spreadMaxAngle = self.maxSpread
				self.breathHoldCount = 0
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

		if not self.aiming then
			effectPos = firePos + dir * 0.2
		else
			effectPos = firePos + dir * 0.45
		end

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
		local fireMode = self.aiming and self.aimFireMode or self.normalFireMode
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

		if self.aiming then
			if self.tool:isInFirstPersonView() then
				self.tool:setCrossHairAlpha( 0.0 )
			else
				self.tool:setCrossHairAlpha( 1.0 )
			end
			self.tool:setInteractionTextSuppressed( true )
		else
			self.tool:setCrossHairAlpha( 1.0 )
			self.tool:setInteractionTextSuppressed( false )
		end
	end

	-- Sprint block
	local blockSprint = self.aiming or self.sprintCooldownTimer > 0.0 or self.isReloading
	self.tool:setBlockSprint( blockSprint )

	local playerDir = self.tool:getDirection()
	local angle = math.asin( playerDir:dot( sm.vec3.new( 0, 0, 1 ) ) ) / ( math.pi / 2 )

	local crouchWeight = self.tool:isCrouching() and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight

	local totalWeight = 0.0
	for name, animation in pairs( self.tpAnimations.animations ) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min( animation.weight + ( self.tpAnimations.blendSpeed * dt ), 1.0 )

			if animation.time >= animation.info.duration - self.blendTime then
				if ( name == "shoot" or name == "aimShoot" ) then
					setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 10.0 )
				elseif name == "pickup" then
					setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 0.001 )
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
	if ( ( ( isAnyOf( self.tpAnimations.currentAnimation, { "aimInto", "aim", "shoot" } ) and ( relativeMoveDirection:length() > 0 or isCrouching) ) or ( self.aiming and ( relativeMoveDirection:length() > 0 or isCrouching) ) ) and not isSprinting ) then
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
	self.tool:updateAnimation( "spudsniper_spine_bend", finalAngle, self.spineWeight )

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
	if self.aiming then
		local blend = 1 - (1 - 1 / self.aimBlendSpeed) ^ (dt * 60)
		self.aimWeight = sm.util.lerp( self.aimWeight, 1.0, blend )
		bobbing = 0.12
	else
		local blend = 1 - (1 - 1 / self.aimBlendSpeed) ^ (dt * 60)
		self.aimWeight = sm.util.lerp( self.aimWeight, 0.0, blend )
		bobbing = 1
	end

	self.tool:updateCamera( 2.8, 30.0, sm.vec3.new( 0.65, 0.0, 0.05 ), self.aimWeight )
	self.tool:updateFpCamera( 30.0, sm.vec3.new( 0.0, 0.0, 0.0 ), self.aimWeight, bobbing )
end

function Sniper.client_onEquip( self, animate )
	if animate then
		sm.audio.play( "PotatoRifle - Equip", self.tool:getPosition() )
	end

	self.wantEquipped = true
	self.aiming = false
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
	self.aimWeight = math.max( cameraWeight, cameraFPWeight )
	self.jointWeight = 0.0

	local currentRenderablesTp = {}
	local currentRenderablesFp = {}
	for k,v in pairs( renderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	for k,v in pairs( renderables ) do
		currentRenderablesTp[#currentRenderablesTp+1] = v
		currentRenderablesFp[#currentRenderablesFp+1] = v
	end
	self.tool:setTpRenderables( currentRenderablesTp )
	if self.isLocal then
		self.tool:setFpRenderables( currentRenderablesFp )
	end

	self:loadAnimations()

	setTpAnimation( self.tpAnimations, "pickup", 0.0001 )
	if self.isLocal then
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end
end

function Sniper.client_onUnequip( self, animate )
	if animate then
		sm.audio.play( "PotatoRifle - Unequip", self.tool:getPosition() )
	end

	self.wantEquipped = false
	self.equipped = false
	setTpAnimation( self.tpAnimations, "putdown" )
	if self.isLocal then
		if self.fpAnimations.currentAnimation ~= "unequip" then
			swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
		end

		self.isReloading = false
	end
end

function Sniper.sv_n_onAim( self, aiming )
	self.network:sendToClients( "cl_n_onAim", aiming )
end

function Sniper.cl_n_onAim( self, aiming )
	if not self.isLocal and self.tool:isEquipped() then
		self:onAim( aiming )
	end
end

function Sniper.onAim( self, aiming )
	self.aiming = aiming
	if self.tpAnimations.currentAnimation == "idle" or self.tpAnimations.currentAnimation == "aim" or self.tpAnimations.currentAnimation == "relax" and self.aiming then
		setTpAnimation( self.tpAnimations, self.aiming and "aim" or "idle", 5.0 )
	end
end

function Sniper.sv_onShoot( self )
	self.network:sendToClients( "cl_onShoot" )
end

function Sniper.cl_onShoot( self )
	self.tpAnimations.animations.idle.time = 0
	self.tpAnimations.animations.shoot.time = 0
	self.tpAnimations.animations.aimShoot.time = 0

	setTpAnimation( self.tpAnimations, self.aiming and "aimShoot" or "shoot", 10.0 )

	if self.tool:isInFirstPersonView() then
		self.shootEffectFP:start()
	else
		self.shootEffect:start()
	end
end

function Sniper.calculateFirePosition( self )
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
		if not self.aiming then
			fireOffset = fireOffset + right * 0.05
		end
	else
		fireOffset = fireOffset + right * 0.25
		fireOffset = fireOffset:rotate( math.rad( pitch ), right )
	end
	local firePosition = GetOwnerPosition( self.tool ) + fireOffset
	return firePosition
end

function Sniper.calculateTpMuzzlePos( self )
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

function Sniper.calculateFpMuzzlePos( self )
	local fovScale = ( sm.camera.getFov() - 45 ) / 45

	local up = sm.localPlayer.getUp()
	local dir = sm.localPlayer.getDirection()
	local right = sm.localPlayer.getRight()

	local muzzlePos45 = sm.vec3.new( 0.0, 0.0, 0.0 )
	local muzzlePos90 = sm.vec3.new( 0.0, 0.0, 0.0 )

	if self.aiming then
		muzzlePos45 = muzzlePos45 - up * 0.2
		muzzlePos45 = muzzlePos45 + dir * 0.5

		muzzlePos90 = muzzlePos90 - up * 0.5
		muzzlePos90 = muzzlePos90 - dir * 0.6
	else
		muzzlePos45 = muzzlePos45 - up * 0.15
		muzzlePos45 = muzzlePos45 + right * 0.2
		muzzlePos45 = muzzlePos45 + dir * 1.25

		muzzlePos90 = muzzlePos90 - up * 0.15
		muzzlePos90 = muzzlePos90 + right * 0.2
		muzzlePos90 = muzzlePos90 + dir * 0.25
	end

	return self.tool:getFpBonePos( "pejnt_barrel" ) + sm.vec3.lerp( muzzlePos45, muzzlePos90, fovScale )
end

function Sniper.cl_onPrimaryUse( self, state )
	if self.tool:getOwner().character == nil or self.isReloading then
		return
	end

	if self.fireCooldownTimer <= 0.0 and state == 1 then
		if self.ammo > 0 and (not sm.game.getEnableAmmoConsumption() or sm.container.canSpend( sm.localPlayer.getInventory(), obj_plantables_carrot, 1 ) ) then
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

			dir = dir:rotate( math.rad( 0.01 ), sm.camera.getRight() ) -- 1 m sight calibration

			-- Spread
			local fireMode = self.aiming and self.aimFireMode or self.normalFireMode
			local recoilDispersion = 1.0 - ( math.max(fireMode.minDispersionCrouching, fireMode.minDispersionStanding ) + fireMode.maxMovementDispersion )

			local spreadFactor = fireMode.spreadCooldown > 0.0 and clamp( self.spreadCooldownTimer / fireMode.spreadCooldown, 0.0, 1.0 ) or 0.0
			spreadFactor = clamp( self.movementDispersion + spreadFactor * recoilDispersion, 0.0, 1.0 )
			local spreadDeg =  fireMode.spreadMinAngle + ( fireMode.spreadMaxAngle - fireMode.spreadMinAngle ) * spreadFactor

			dir = sm.noise.gunSpread( dir, spreadDeg )
			sm.projectile.projectileAttack( projectileUUID, Damage, firePos, dir * fireMode.fireVelocity, self.tool:getOwner(), fakePosition, fakePositionSelf )
			self.inaccurate = true

			self.fireCooldownTimer = fireMode.fireCooldown
			self.spreadCooldownTimer = math.min( self.spreadCooldownTimer + fireMode.spreadIncrement, fireMode.spreadCooldown )
			self.sprintCooldownTimer = self.sprintCooldown

			self.network:sendToServer( "sv_onShoot" )
			setFpAnimation( self.fpAnimations, self.aiming and "aimShoot" or "shoot", 0.05 )

			self.ammo = self.ammo - 1
		else
			local fireMode = self.aiming and self.aimFireMode or self.normalFireMode
			self.fireCooldownTimer = fireMode.fireCooldown
			sm.audio.play( "PotatoRifle - NoAmmo" )
		end
	end
end

function Sniper.cl_onSecondaryUse( self, state )
	if self.isReloading then return end

	local aiming = state == 1 or state == 2
	if aiming ~= self.aiming then
		self.aiming = aiming
		self.tpAnimations.animations.idle.time = 0

		self:onAim( self.aiming )
		self.tool:setMovementSlowDown( self.aiming )
		self.network:sendToServer( "sv_n_onAim", self.aiming )
	end
end

function Sniper.client_onEquippedUpdate( self, primaryState, secondaryState )
	if self.breathHold then
		sm.gui.displayAlertText( "Breath hold: #ff9d00"..tostring(("%.2f"):format(self.breathHoldCount)).." #ffffff/ "..tostring(maxBreathHold), 1 )
	end

	if not self.isReloading then
		sm.gui.setProgressFraction( self.ammo/self.magCapacity )
	--else
		--local data = self.fpAnimations.animations[self.fpAnimations.currentAnimation]
		--sm.gui.setProgressFraction( data.time/data.info.duration )
	end

	if primaryState ~= self.prevPrimaryState then
		self:cl_onPrimaryUse( primaryState )
		self.prevPrimaryState = primaryState
	end

	if secondaryState ~= self.prevSecondaryState then
		self:cl_onSecondaryUse( secondaryState )
		self.prevSecondaryState = secondaryState
	end

	return true, true
end



function Sniper.loadAnimations( self )
	self.tpAnimations = _createTpAnimations(
		self.tool,
		{
			shoot = { "spudsniper_shoot", { crouch = "spudsniper_crouch_shoot" } },
			aim = { "spudsniper_aim", { crouch = "spudsniper_crouch_aim" } },
			aimShoot = { "spudsniper_aim_shoot", { crouch = "spudsniper_crouch_aim_shoot" } },
			idle = { "spudsniper_idle" },
			pickup = { "spudsniper_pickup", { nextAnimation = "idle" } },
			putdown = { "spudsniper_putdown" },

			reload = { "spudgun_reload", { nextAnimation = "idle" } },
		}
	)

	local movementAnimations = {
		idle = "spudsniper_idle",
		--idleRelaxed = "spudsniper_relax",

		sprint = "spudsniper_sprint",
		runFwd = "spudsniper_run_fwd",
		runBwd = "spudsniper_run_bwd",

		jump = "spudsniper_jump",
		jumpUp = "spudsniper_jump_up",
		jumpDown = "spudsniper_jump_down",

		land = "spudsniper_jump_land",
		landFwd = "spudsniper_jump_land_fwd",
		landBwd = "spudsniper_jump_land_bwd",

		crouchIdle = "spudsniper_crouch_idle",
		crouchFwd = "spudsniper_crouch_fwd",
		crouchBwd = "spudsniper_crouch_bwd"
	}

	for name, animation in pairs( movementAnimations ) do
		self.tool:setMovementAnimation( name, animation )
	end

	setTpAnimation( self.tpAnimations, "idle", 5.0 )

	if self.isLocal then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				equip = { "spudsniper_pickup", { nextAnimation = "idle" } },
				unequip = { "spudsniper_putdown" },

				idle = { "spudsniper_idle", { looping = true } },
				shoot = { "spudsniper_shoot", { nextAnimation = "idle" } },

				aimInto = { "spudsniper_aim_into", { nextAnimation = "aimIdle" } },
				aimExit = { "spudsniper_aim_exit", { nextAnimation = "idle", blendNext = 0 } },
				aimIdle = { "spudsniper_aim_idle", { looping = true} },
				aimShoot = { "spudsniper_aim_shoot", { nextAnimation = "aimIdle"} },

				sprintInto = { "spudsniper_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
				sprintExit = { "spudsniper_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },
				sprintIdle = { "spudsniper_sprint_idle", { looping = true } },

				reload = { "spudgun_reload", { nextAnimation = "idle" } },
			}
		)
	end

	self.normalFireMode = {
		fireCooldown = 1,
		spreadCooldown = 0.18,
		spreadIncrement = 2.6,
		spreadMinAngle = 0.25,
		spreadMaxAngle = 8,
		fireVelocity = baseFireVel,

		minDispersionStanding = 0.1,
		minDispersionCrouching = 0.04,

		maxMovementDispersion = 0.4,
		jumpDispersionMultiplier = 2
	}

	self.aimFireMode = {
		fireCooldown = 1,
		spreadCooldown = 0.18,
		spreadIncrement = 1.3,
		spreadMinAngle = 0,
		spreadMaxAngle = self.maxSpread,
		fireVelocity =  baseFireVel,

		minDispersionStanding = 0.01,
		minDispersionCrouching = 0.01,

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