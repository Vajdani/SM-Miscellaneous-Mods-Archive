dofile("$GAME_DATA/Scripts/game/AnimationUtil.lua")
dofile("$SURVIVAL_DATA/Scripts/util.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_projectiles.lua")

dofile("$CONTENT_DATA/Scripts/util.lua")

---@class Pistol : ToolClass
---@field fpAnimations table
---@field tpAnimations table
---@field aiming boolean
---@field shootEffect Effect
---@field shootEffectFP Effect
---@field aimFireMode table
---@field normalFireMode table
---@field blendTime number
---@field aimBlendSpeed number
---@field movementDispersion number
---@field sprintCooldown number
Pistol = class()
Pistol.magCapacity = 15
Pistol.reloadAnims = {
	reload = true
}

local Damage = 28
local magDebrisUUID = sm.uuid.new("478009fd-fa41-454e-aad8-ea1d5da9dc45")
local defaultDir = sm.vec3.new(0,-1,0)

local renderables = {
	"$CONTENT_DATA/Tools/Pistol/Renderables/pistol_base.rend",
	"$CONTENT_DATA/Tools/Pistol/Renderables/pistol_mag.rend",
	"$CONTENT_DATA/Tools/Pistol/Renderables/pistol_slide.rend"
}
local renderablesTp = {
	"$CONTENT_DATA/Tools/Pistol/pistol_tp.rend",
	"$CONTENT_DATA/Tools/Pistol/pistol_tp_animlist.rend"
}
local renderablesFp = {
	"$CONTENT_DATA/Tools/Pistol/pistol_fp.rend",
	"$CONTENT_DATA/Tools/Pistol/pistol_fp_animlist.rend"
}

sm.tool.preloadRenderables(renderables)
sm.tool.preloadRenderables(renderablesTp)
sm.tool.preloadRenderables(renderablesFp)

function Pistol:client_onCreate()
	self.shootEffect = sm.effect.createEffect("SpudgunBasic - BasicMuzzel")
	self.shootEffectFP = sm.effect.createEffect("SpudgunBasic - FPBasicMuzzel")

	self.isLocal = self.tool:isLocal()
	if not self.isLocal then return end

	self.ammo = self.magCapacity
	self.isReloading = false
end

function Pistol:client_onReload()
	if self.ammo < self.magCapacity and not self.isReloading and not self.aiming then
		sm.gui.displayAlertText("Reloading...", 2.5)
		self.isReloading = true
		self.network:sendToServer("sv_onReload")
	end

	return true
end

function Pistol:sv_onReload()
	self.network:sendToClients("cl_onReload")
end

function Pistol:cl_onReload()
	local aimDir = self.tool:getOwner().character.direction
	local boneDir = self.tool:getTpBoneDir("jnt_mag")
	sm.debris.createDebris(
		magDebrisUUID,
		self.tool:getTpBonePos("jnt_mag") - boneDir * 0.1,
		GetRot(boneDir, defaultDir),
		boneDir * -1
	)

	setTpAnimation(self.tpAnimations, "reload", 10)
	if self.isLocal then
		setFpAnimation(self.fpAnimations, "reload", 0)
	end
end

function Pistol:client_onToggle()
	return true
end

function Pistol:loadAnimations()

	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			shoot = { "connecttool_shoot", { crouch = "connecttool_crouch_shoot", blendNext = 0.1 } },
			aim = { "connecttool_aim", { crouch = "connecttool_crouch_aim" } },
			aimShoot = { "connecttool_aim_shoot", { crouch = "connecttool_crouch_aim_shoot", blendNext = 0.1 } },
			idle = { "connecttool_idle" },

			reload = { "connecttool_reload", { nextAnimation = "idle" } },

			pickup = { "connecttool_pickup", { nextAnimation = "idle" } },
			putdown = { "connecttool_putdown" }
		}
	)
	local movementAnimations = {
		idle = "connecttool_idle",
		--idleRelaxed = "connecttool_relax",

		sprint = "connecttool_sprint",
		runFwd = "connecttool_run_fwd",
		runBwd = "connecttool_run_bwd",

		jump = "connecttool_jump",
		jumpUp = "connecttool_jump_up",
		jumpDown = "connecttool_jump_down",

		land = "connecttool_jump_land",
		landFwd = "connecttool_jump_land_fwd",
		landBwd = "connecttool_jump_land_bwd",

		crouchIdle = "connecttool_crouch_idle",
		crouchFwd = "connecttool_crouch_fwd",
		crouchBwd = "connecttool_crouch_bwd"
	}

	for name, animation in pairs(movementAnimations) do
		self.tool:setMovementAnimation(name, animation)
	end

	setTpAnimation(self.tpAnimations, "idle", 5.0)

	if self.isLocal then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				equip = { "connecttool_pickup", { nextAnimation = "idle" } },
				unequip = { "connecttool_putdown" },

				idle = { "connecttool_idle", { looping = true } },
				shoot = { "connecttool_shoot", { nextAnimation = "idle", blendNext = 0.1 } },

				reload = { "connecttool_reload", { nextAnimation = "idle" } },

				aimInto = { "connecttool_aim_into", { nextAnimation = "aimIdle" } },
				aimExit = { "connecttool_aim_exit", { nextAnimation = "idle", blendNext = 0 } },
				aimIdle = { "connecttool_aim_idle", { looping = true } },
				aimShoot = { "connecttool_aim_shoot", { nextAnimation = "aimIdle", blendNext = 0.1 } },

				sprintInto = { "connecttool_sprint_into", { nextAnimation = "sprintIdle", blendNext = 0.2 } },
				sprintExit = { "connecttool_sprint_exit", { nextAnimation = "idle", blendNext = 0 } },
				sprintIdle = { "connecttool_sprint_idle", { looping = true } },
			}
		)
	end

	self.normalFireMode = {
		fireCooldown = 0.33,
		spreadCooldown = 0.18,
		spreadIncrement = 2.6,
		spreadMinAngle = .25,
		spreadMaxAngle = 8,
		fireVelocity = 130.0,

		minDispersionStanding = 0.1,
		minDispersionCrouching = 0.04,

		maxMovementDispersion = 0.4,
		jumpDispersionMultiplier = 2
	}

	self.aimFireMode = {
		fireCooldown = 0.25,
		spreadCooldown = 0.18,
		spreadIncrement = 1.3,
		spreadMinAngle = 0,
		spreadMaxAngle = 8,
		fireVelocity = 130.0,

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
	self.aimWeight = math.max(cameraWeight, cameraFPWeight)

end

function Pistol:client_onUpdate(dt)
	-- First person animation
	local isSprinting = self.tool:isSprinting()
	local isCrouching = self.tool:isCrouching()

	if self.isLocal then
		if self.equipped then
			if isSprinting and self.fpAnimations.currentAnimation ~= "sprintInto" and
				self.fpAnimations.currentAnimation ~= "sprintIdle" then
				swapFpAnimation(self.fpAnimations, "sprintExit", "sprintInto", 0.0)
			elseif not self.tool:isSprinting() and
				(self.fpAnimations.currentAnimation == "sprintIdle" or self.fpAnimations.currentAnimation == "sprintInto") then
				swapFpAnimation(self.fpAnimations, "sprintInto", "sprintExit", 0.0)
			end

			if self.aiming and not isAnyOf(self.fpAnimations.currentAnimation, { "aimInto", "aimIdle", "aimShoot" }) then
				swapFpAnimation(self.fpAnimations, "aimExit", "aimInto", 0.0)
			end

			if not self.aiming and isAnyOf(self.fpAnimations.currentAnimation, { "aimInto", "aimIdle", "aimShoot" }) then
				swapFpAnimation(self.fpAnimations, "aimInto", "aimExit", 0.0)
			end

			local current = self.fpAnimations.currentAnimation
			local data = self.fpAnimations.animations[current]
			if data and self.reloadAnims[current] == true then
				if data.time + data.playRate * dt >= data.info.duration then
					self.ammo = self.magCapacity
					self.isReloading = false
				end
			end
		end

		updateFpAnimations(self.fpAnimations, self.equipped, dt)
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
		local firePos = self.tool:getFpBonePos("pipe")
		effectPos = self.aiming and firePos + dir * 0.45 or firePos + dir * 0.2
		rot = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), dir)

		self.shootEffectFP:setPosition(effectPos)
		self.shootEffectFP:setVelocity(self.tool:getMovementVelocity())
		self.shootEffectFP:setRotation(rot)
	end

	local pos = self.tool:getTpBonePos("pipe")
	local dir = self.tool:getDirection()
	effectPos = pos + dir * 0.2
	rot = sm.vec3.getRotation(sm.vec3.new(0, 0, 1), dir)

	self.shootEffect:setPosition(effectPos)
	self.shootEffect:setVelocity(self.tool:getMovementVelocity())
	self.shootEffect:setRotation(rot)

	-- Timers
	self.fireCooldownTimer = math.max(self.fireCooldownTimer - dt, 0.0)
	self.spreadCooldownTimer = math.max(self.spreadCooldownTimer - dt, 0.0)
	self.sprintCooldownTimer = math.max(self.sprintCooldownTimer - dt, 0.0)


	if self.isLocal then
		local dispersion = 0.0
		local fireMode = self.aiming and self.aimFireMode or self.normalFireMode
		local recoilDispersion = 1.0 -
			(math.max(fireMode.minDispersionCrouching, fireMode.minDispersionStanding) + fireMode.maxMovementDispersion)

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

		self.spreadCooldownTimer = clamp(self.spreadCooldownTimer, 0.0, fireMode.spreadCooldown)
		local spreadFactor = fireMode.spreadCooldown > 0.0 and
			clamp(self.spreadCooldownTimer / fireMode.spreadCooldown, 0.0, 1.0) or 0.0

		self.tool:setDispersionFraction(clamp(self.movementDispersion + spreadFactor * recoilDispersion, 0.0, 1.0))

		if self.aiming then
			if self.tool:isInFirstPersonView() then
				self.tool:setCrossHairAlpha(0.0)
			else
				self.tool:setCrossHairAlpha(1.0)
			end
			self.tool:setInteractionTextSuppressed(true)
		else
			self.tool:setCrossHairAlpha(1.0)
			self.tool:setInteractionTextSuppressed(false)
		end
	end

	-- Sprint block
	local blockSprint = self.aiming or self.sprintCooldownTimer > 0.0
	self.tool:setBlockSprint(blockSprint)

	local playerDir = self.tool:getSmoothDirection()
	local angle = math.asin(playerDir:dot(sm.vec3.new(0, 0, 1))) / (math.pi / 2)

	local crouchWeight = self.tool:isCrouching() and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight

	local totalWeight = 0.0
	for name, animation in pairs(self.tpAnimations.animations) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min(animation.weight + (self.tpAnimations.blendSpeed * dt), 1.0)

			if animation.time >= animation.info.duration - self.blendTime then
				if (name == "shoot" or name == "aimShoot") then
					setTpAnimation(self.tpAnimations, self.aiming and "aim" or "idle", 10.0)
				elseif name == "pickup" then
					setTpAnimation(self.tpAnimations, self.aiming and "aim" or "idle", 0.001)
				elseif animation.nextAnimation ~= "" then
					setTpAnimation(self.tpAnimations, animation.nextAnimation, 0.001)
				end
			end
		else
			animation.weight = math.max(animation.weight - (self.tpAnimations.blendSpeed * dt), 0.0)
		end

		totalWeight = totalWeight + animation.weight
	end

	totalWeight = totalWeight == 0 and 1.0 or totalWeight
	for name, animation in pairs(self.tpAnimations.animations) do
		local weight = animation.weight / totalWeight
		if name == "idle" then
			self.tool:updateMovementAnimation(animation.time, weight)
		elseif animation.crouch then
			self.tool:updateAnimation(animation.info.name, animation.time, weight * normalWeight)
			self.tool:updateAnimation(animation.crouch.name, animation.time, weight * crouchWeight)
		else
			self.tool:updateAnimation(animation.info.name, animation.time, weight)
		end
	end

	-- Third Person joint lock
	local relativeMoveDirection = self.tool:getRelativeMoveDirection()
	if (((isAnyOf(self.tpAnimations.currentAnimation, { "aimInto", "aim", "shoot" }) and (relativeMoveDirection:length() > 0 or isCrouching)) or (self.aiming and (relativeMoveDirection:length() > 0 or isCrouching))) and not isSprinting) then
		self.jointWeight = math.min(self.jointWeight + (10.0 * dt), 1.0)
	else
		self.jointWeight = math.max(self.jointWeight - (6.0 * dt), 0.0)
	end

	if (not isSprinting) then
		self.spineWeight = math.min(self.spineWeight + (10.0 * dt), 1.0)
	else
		self.spineWeight = math.max(self.spineWeight - (10.0 * dt), 0.0)
	end

	local finalAngle = (0.5 + angle * 0.5)
	self.tool:updateAnimation("spudgun_spine_bend", finalAngle, self.spineWeight)

	local totalOffsetZ = lerp(-22.0, -26.0, crouchWeight)
	local totalOffsetY = lerp(6.0, 12.0, crouchWeight)
	local crouchTotalOffsetX = clamp((angle * 60.0) - 15.0, -60.0, 40.0)
	local normalTotalOffsetX = clamp((angle * 50.0), -45.0, 50.0)
	local totalOffsetX = lerp(normalTotalOffsetX, crouchTotalOffsetX, crouchWeight)
	local finalJointWeight = (self.jointWeight)

	self.tool:updateJoint("jnt_hips", sm.vec3.new(totalOffsetX, totalOffsetY, totalOffsetZ), 0.35 * finalJointWeight * (normalWeight))
	local crouchSpineWeight = (0.35 / 3) * crouchWeight

	self.tool:updateJoint("jnt_spine1", sm.vec3.new(totalOffsetX, totalOffsetY, totalOffsetZ), (0.10 + crouchSpineWeight) * finalJointWeight)
	self.tool:updateJoint("jnt_spine2", sm.vec3.new(totalOffsetX, totalOffsetY, totalOffsetZ), (0.10 + crouchSpineWeight) * finalJointWeight)
	self.tool:updateJoint("jnt_spine3", sm.vec3.new(totalOffsetX, totalOffsetY, totalOffsetZ), (0.45 + crouchSpineWeight) * finalJointWeight)
	self.tool:updateJoint("jnt_head", sm.vec3.new(totalOffsetX, totalOffsetY, totalOffsetZ), 0.3 * finalJointWeight)


	-- Camera update
	local bobbing = 1
	if self.aiming then
		local blend = 1 - ((1 - 1 / self.aimBlendSpeed) ^ (dt * 60))
		self.aimWeight = sm.util.lerp(self.aimWeight, 1.0, blend)
		bobbing = 0.12
	else
		local blend = 1 - ((1 - 1 / self.aimBlendSpeed) ^ (dt * 60))
		self.aimWeight = sm.util.lerp(self.aimWeight, 0.0, blend)
		bobbing = 1
	end

	self.tool:updateCamera(2.8, 30.0, sm.vec3.new(0.65, 0.0, 0.05), self.aimWeight)
	self.tool:updateFpCamera(30.0, sm.vec3.new(0.0, 0.0, 0.0), self.aimWeight, bobbing)
end

function Pistol:client_onEquip(animate)

	if animate then
		sm.audio.play("PotatoRifle - Equip", self.tool:getPosition())
	end

	self.wantEquipped = true
	self.aiming = false
	local cameraWeight, cameraFPWeight = self.tool:getCameraWeights()
	self.aimWeight = math.max(cameraWeight, cameraFPWeight)
	self.jointWeight = 0.0

	local currentRenderablesTp = {}
	local currentRenderablesFp = {}

	for k, v in pairs(renderablesTp) do currentRenderablesTp[#currentRenderablesTp + 1] = v end
	for k, v in pairs(renderablesFp) do currentRenderablesFp[#currentRenderablesFp + 1] = v end
	for k, v in pairs(renderables) do
		currentRenderablesTp[#currentRenderablesTp + 1] = v
		currentRenderablesFp[#currentRenderablesFp + 1] = v
	end
	self.tool:setTpRenderables(currentRenderablesTp)
	if self.isLocal then
		self.tool:setFpRenderables(currentRenderablesFp)
	end

	self:loadAnimations()
	setTpAnimation(self.tpAnimations, "pickup", 0.0001)
	if self.isLocal then
		swapFpAnimation(self.fpAnimations, "unequip", "equip", 0.2)
	end
end

function Pistol:client_onUnequip(animate)
	self.wantEquipped = false
	self.equipped = false
	self.aiming = false
	if sm.exists(self.tool) then
		if animate then
			sm.audio.play("PotatoRifle - Unequip", self.tool:getPosition())
		end
		setTpAnimation(self.tpAnimations, "putdown")
		if self.isLocal then
			self.tool:setMovementSlowDown(false)
			self.tool:setBlockSprint(false)
			self.tool:setCrossHairAlpha(1.0)
			self.tool:setInteractionTextSuppressed(false)
			if self.fpAnimations.currentAnimation ~= "unequip" then
				swapFpAnimation(self.fpAnimations, "equip", "unequip", 0.2)
			end

			self.isReloading = false
		end
	end
end

function Pistol:sv_n_onAim(aiming)
	self.network:sendToClients("cl_n_onAim", aiming)
end

function Pistol:cl_n_onAim(aiming)
	if not self.isLocal and self.tool:isEquipped() then
		self:onAim(aiming)
	end
end

function Pistol:onAim(aiming)
	self.aiming = aiming
	if self.tpAnimations.currentAnimation == "idle" or self.tpAnimations.currentAnimation == "aim" or
		self.tpAnimations.currentAnimation == "relax" and self.aiming then
		setTpAnimation(self.tpAnimations, self.aiming and "aim" or "idle", 5.0)
	end
end

function Pistol:sv_n_onShoot()
	self.network:sendToClients("cl_n_onShoot")
end

function Pistol:cl_n_onShoot()
	if not self.isLocal and self.tool:isEquipped() then
		self:onShoot()
	end
end

function Pistol:onShoot()
	self.tpAnimations.animations.idle.time = 0
	self.tpAnimations.animations.shoot.time = 0
	self.tpAnimations.animations.aimShoot.time = 0

	setTpAnimation(self.tpAnimations, self.aiming and "aimShoot" or "shoot", 10.0)

	if self.tool:isInFirstPersonView() then
		self.shootEffectFP:start()
	else
		self.shootEffect:start()
	end

end

function Pistol:calculateFirePosition()
	local crouching = self.tool:isCrouching()
	local firstPerson = self.tool:isInFirstPersonView()
	local dir = sm.localPlayer.getDirection()
	local pitch = math.asin(dir.z)
	local right = sm.localPlayer.getRight()

	local fireOffset = sm.vec3.new(0.0, 0.0, 0.0)

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
		fireOffset = fireOffset:rotate(math.rad(pitch), right)
	end
	local firePosition = GetOwnerPosition(self.tool) + fireOffset
	return firePosition
end

function Pistol:calculateTpMuzzlePos()
	local crouching = self.tool:isCrouching()
	local dir = sm.localPlayer.getDirection()
	local pitch = math.asin(dir.z)
	local right = sm.localPlayer.getRight()
	local up = right:cross(dir)

	local fakeOffset = sm.vec3.new(0.0, 0.0, 0.0)

	--General offset
	fakeOffset = fakeOffset + right * 0.25
	fakeOffset = fakeOffset + dir * 0.5
	fakeOffset = fakeOffset + up * 0.25

	--Action offset
	local pitchFraction = pitch / (math.pi * 0.5)
	if crouching then
		fakeOffset = fakeOffset + dir * 0.2
		fakeOffset = fakeOffset + up * 0.1
		fakeOffset = fakeOffset - right * 0.05

		if pitchFraction > 0.0 then
			fakeOffset = fakeOffset - up * 0.2 * pitchFraction
		else
			fakeOffset = fakeOffset + up * 0.1 * math.abs(pitchFraction)
		end
	else
		fakeOffset = fakeOffset + up * 0.1 * math.abs(pitchFraction)
	end

	local fakePosition = fakeOffset + GetOwnerPosition(self.tool)
	return fakePosition
end

---@return Vec3
function Pistol:calculateFpMuzzlePos()
	local fovScale = (sm.camera.getFov() - 45) / 45

	local up = sm.localPlayer.getUp()
	local dir = sm.localPlayer.getDirection()
	local right = sm.localPlayer.getRight()

	local muzzlePos45 = sm.vec3.new(0.0, 0.0, 0.0)
	local muzzlePos90 = sm.vec3.new(0.0, 0.0, 0.0)

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

	return self.tool:getFpBonePos("pipe") + sm.vec3.lerp(muzzlePos45, muzzlePos90, fovScale)
end

function Pistol:cl_onPrimaryUse(state)
	if self.tool:getOwner().character == nil then
		return
	end

	if self.fireCooldownTimer <= 0.0 --[[and state == sm.tool.interactState.start]] then
		if self.ammo > 0 then
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
				local raycastPos = sm.camera.getPosition() +
					sm.camera.getDirection() * sm.camera.getDirection():dot(GetOwnerPosition(self.tool) - sm.camera.getPosition())
				local hit, result = sm.localPlayer.getRaycast(250, raycastPos, sm.camera.getDirection())
				if hit then
					local norDir = sm.vec3.normalize(result.pointWorld - firePos)
					local dirDot = norDir:dot(dir)

					if dirDot > 0.96592583 then -- max 15 degrees off
						dir = norDir
					else
						local radsOff = math.asin(dirDot)
						dir = sm.vec3.lerp(dir, norDir, math.tan(radsOff) / 3.7320508) -- if more than 15, make it 15
					end
				end
			end
			dir = dir:rotate(math.rad(0.955), sm.camera.getRight()) -- 50 m sight calibration

			-- Spread
			local fireMode = self.aiming and self.aimFireMode or self.normalFireMode
			local recoilDispersion = 1.0 -
				(math.max(fireMode.minDispersionCrouching, fireMode.minDispersionStanding) + fireMode.maxMovementDispersion)

			local spreadFactor = fireMode.spreadCooldown > 0.0 and
				clamp(self.spreadCooldownTimer / fireMode.spreadCooldown, 0.0, 1.0) or 0.0
			spreadFactor = clamp(self.movementDispersion + spreadFactor * recoilDispersion, 0.0, 1.0)
			local spreadDeg = fireMode.spreadMinAngle + (fireMode.spreadMaxAngle - fireMode.spreadMinAngle) * spreadFactor

			sm.projectile.projectileAttack(projectile_potato, Damage, firePos,
				sm.noise.gunSpread(dir, spreadDeg) * fireMode.fireVelocity, self.tool:getOwner(), fakePosition,
				fakePositionSelf)

			self.fireCooldownTimer = fireMode.fireCooldown
			self.spreadCooldownTimer = math.min(self.spreadCooldownTimer + fireMode.spreadIncrement, fireMode.spreadCooldown)
			self.sprintCooldownTimer = self.sprintCooldown

			self:onShoot()
			self.network:sendToServer("sv_n_onShoot")
			setFpAnimation(self.fpAnimations, self.aiming and "aimShoot" or "shoot", 0.05)

			self.ammo = self.ammo - 1
		else
			local fireMode = self.aiming and self.aimFireMode or self.normalFireMode
			self.fireCooldownTimer = fireMode.fireCooldown
			sm.audio.play("PotatoRifle - NoAmmo")
		end
	end
end

function Pistol:cl_onSecondaryUse(state)
	local aiming = state == 1 or state == 2
	if aiming ~= self.aiming then
		self.aiming = aiming
		self.tpAnimations.animations.idle.time = 0

		self:onAim(self.aiming)
		self.tool:setMovementSlowDown(self.aiming)
		self.network:sendToServer("sv_n_onAim", self.aiming)
	end
end

function Pistol:client_onEquippedUpdate(lmb, rmb)
	if lmb == 1 or lmb == 2 --[[lmb ~= self.prevlmb]] then
		self:cl_onPrimaryUse(lmb)
		--self.prevlmb = lmb
	end

	if rmb ~= self.prevrmb then
		self:cl_onSecondaryUse(rmb)
		self.prevrmb = rmb
	end

	return true, true
end
