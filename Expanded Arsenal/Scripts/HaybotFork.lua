dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

Fork = class()

local renderables = {
	"$CONTENT_DATA/Tools/Fork/Renderables/HaybotFork.rend"
}
local renderablesTp = {
	"$CONTENT_DATA/Tools/Fork/fork_tp.rend",
	"$CONTENT_DATA/Tools/Fork/fork_tp_animlist.rend"
}
local renderablesFp = {
	"$CONTENT_DATA/Tools/Fork/fork_fp.rend",
	"$CONTENT_DATA/Tools/Fork/fork_fp_animlist.rend"
}

sm.tool.preloadRenderables(renderables)
sm.tool.preloadRenderables(renderablesTp)
sm.tool.preloadRenderables(renderablesFp)


function Fork.client_onCreate(self)
	self:cl_init()
end

function Fork.cl_init(self)
	self:cl_loadAnimations()
end

function Fork.cl_loadAnimations(self)
	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			idle = { "longsandwich_idle", { looping = true } },
			use = { "longsandwich_use", { nextAnimation = "idle" } },
			sprint = { "longsandwich_sprint" },
			pickup = { "longsandwich_pickup", { nextAnimation = "idle" } },
			putdown = { "longsandwich_putdown" }

		}
	)
	setTpAnimation(self.tpAnimations, "idle", 5.0)

	local movementAnimations = {
		idle = "longsandwich_idle",

		runFwd = "longsandwich_run_fwd",
		runBwd = "longsandwich_run_bwd",
		sprint = "longsandwich_sprint",

		jump = "longsandwich_jump_start",
		jumpUp = "longsandwich_jump_up",
		jumpDown = "longsandwich_jump_down",

		land = "longsandwich_land",
		landFwd = "longsandwich_jump_land_fwd",
		landBwd = "longsandwich_jump_land_bwd",

		crouchIdle = "longsandwich_crouch_idle",
		crouchFwd = "longsandwich_crouch_fwd",
		crouchBwd = "longsandwich_crouch_bwd"
	}

	for name, animation in pairs(movementAnimations) do
		self.tool:setMovementAnimation(name, animation)
	end

	if self.tool:isLocal() then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				idle = { "longsandwich_idle", { looping = true } },

				sprintInto = { "longsandwich_sprint_into", { nextAnimation = "sprintIdle", blendNext = 0.2 } },
				sprintIdle = { "longsandwich_sprint_idle", { looping = true } },
				sprintExit = { "longsandwich_sprint_exit", { nextAnimation = "idle", blendNext = 0 } },

				use = { "longsandwich_use", { nextAnimation = "idle" } },

				equip = { "longsandwich_pickup", { nextAnimation = "idle" } },
				unequip = { "longsandwich_putdown" }
			}
		)
		setFpAnimation(self.fpAnimations, "idle", 5.0)
	end
	self.blendTime = 0.2
	self.spineWeight = 0
	self.jointWeight = 0
end

function Fork.client_onUpdate(self, dt)
	local isSprinting = self.tool:isSprinting()
	local isCrouching = self.tool:isCrouching()

	if self.tool:isLocal() then
		if self.equipped then
			if isSprinting and self.fpAnimations.currentAnimation ~= "sprintInto" and
				self.fpAnimations.currentAnimation ~= "sprintIdle" then
				swapFpAnimation(self.fpAnimations, "sprintExit", "sprintInto", 0.0)
			elseif not self.tool:isSprinting() and
				(self.fpAnimations.currentAnimation == "sprintIdle" or self.fpAnimations.currentAnimation == "sprintInto") then
				swapFpAnimation(self.fpAnimations, "sprintInto", "sprintExit", 0.0)
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

	local crouchWeight = self.tool:isCrouching() and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight
	local totalWeight = 0.0

	for name, animation in pairs(self.tpAnimations.animations) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min(animation.weight + (self.tpAnimations.blendSpeed * dt), 1.0)

			if animation.looping == true then
				if animation.time >= animation.info.duration then
					animation.time = animation.time - animation.info.duration
				end
			end
			if animation.time >= animation.info.duration - self.blendTime and not animation.looping then
				if (name == "use") then
					setTpAnimation(self.tpAnimations, "idle", 10.0)
				elseif name == "pickup" then
					setTpAnimation(self.tpAnimations, "idle", 0.001)
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

	--[[
	local playerDir = self.tool:getSmoothDirection()
	local angle = math.asin( playerDir:dot( sm.vec3.new( 0, 0, 1 ) ) ) / ( math.pi / 2 )
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
	]]
end

function Fork.client_onEquip(self)
	self.wantEquipped = true

	local currentRenderablesTp = {}
	local currentRenderablesFp = {}

	for k, v in pairs(renderablesTp) do currentRenderablesTp[#currentRenderablesTp + 1] = v end
	for k, v in pairs(renderablesFp) do currentRenderablesFp[#currentRenderablesFp + 1] = v end
	for k, v in pairs(renderables) do
		currentRenderablesTp[#currentRenderablesTp + 1] = v
		currentRenderablesFp[#currentRenderablesFp + 1] = v
	end

	self.tool:setTpRenderables(currentRenderablesTp)
	if self.tool:isLocal() then
		self.tool:setFpRenderables(currentRenderablesFp)
	end

	self:cl_loadAnimations()

	setTpAnimation(self.tpAnimations, "pickup", 0.0001)
	if self.tool:isLocal() then
		swapFpAnimation(self.fpAnimations, "unequip", "equip", 0.2)

		self.tool:setBlockSprint(true)
	end
end

function Fork.client_onUnequip(self)
	self.wantEquipped = false
	self.equipped = false
	if sm.exists(self.tool) then
		setTpAnimation(self.tpAnimations, "putdown")
		if self.tool:isLocal() then
			if self.fpAnimations.currentAnimation ~= "unequip" then
				swapFpAnimation(self.fpAnimations, "equip", "unequip", 0.2)
			end

			self.tool:setBlockSprint(false)
		end
	end
end

function Fork.client_onEquippedUpdate(self, primaryState, secondaryState)

	return true, true
end