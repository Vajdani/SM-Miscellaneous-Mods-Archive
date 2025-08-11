dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"

BlahajHolder = class( nil )

local renderables = {
	"$CONTENT_DATA/Tools/Blahaj/char_blahaj.rend"
}
local renderablesTp = {
    "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_tp_toolgorp.rend",
    "$SURVIVAL_DATA/Character/Char_Tools/Char_toolgorp/char_toolgorp_tp.rend"
}
local renderablesFp = {
    "$SURVIVAL_DATA/Character/Char_Male/Animations/char_male_fp_toolgorp.rend",
    "$SURVIVAL_DATA/Character/Char_Tools/Char_toolgorp/char_toolgorp_fp.rend"
}

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )

function BlahajHolder:client_onCreate()

end

function BlahajHolder:cl_loadAnimations()
    self.tpAnimations = createTpAnimations(
        self.tool,
        {
            idle = { "toolgorp_idle", { looping = true } },
            sprint = { "toolgorp_sprint" },
            pickup = { "toolgorp_pickup", { nextAnimation = "idle" } },
            putdown = { "toolgorp_putdown" }

        }
    )
    local movementAnimations = {

        idle = "toolgorp_idle",

        runFwd = "toolgorp_run_fwd",
        runBwd = "toolgorp_run_bwd",

        sprint = "toolgorp_sprint",

        jump = "toolgorp_jump",
        jumpUp = "toolgorp_jump_up",
        jumpDown = "toolgorp_jump_down",

        land = "toolgorp_jump_land",
        landFwd = "toolgorp_jump_land_fwd",
        landBwd = "toolgorp_jump_land_bwd",

        crouchIdle = "toolgorp_crouch_idle",
        crouchFwd = "toolgorp_crouch_fwd",
        crouchBwd = "toolgorp_crouch_bwd",

        swimIdle = "toolgorp_swim_idle",
        swimFwd = "toolgorp_swim_fwd",
        swimBwd = "toolgorp_swim_bwd"
    }

    for name, animation in pairs( movementAnimations ) do
        self.tool:setMovementAnimation( name, animation )
    end

    if self.tool:isLocal() then
        self.fpAnimations = createFpAnimations(
            self.tool,
            {
                idle = { "toolgorp_idle", { looping = true } },

                sprintInto = { "toolgorp_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
                sprintIdle = { "toolgorp_sprint_idle", { looping = true } },
                sprintExit = { "toolgorp_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },

                jump = { "toolgorp_jump", { nextAnimation = "idle" } },
                land = { "toolgorp_jump_land", { nextAnimation = "idle" } },

                equip = { "toolgorp_pickup", { nextAnimation = "idle" } },
                unequip = { "toolgorp_putdown" }
            }
        )
    end
    setTpAnimation( self.tpAnimations, "idle", 5.0 )
    self.blendTime = 0.2
end

function BlahajHolder:client_onUpdate( dt )
	if self.tool:isLocal() then
		if self.equipped then
			if self.tool:isSprinting() and self.fpAnimations.currentAnimation ~= "sprintInto" and self.fpAnimations.currentAnimation ~= "sprintIdle" then
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

	local crouchWeight = self.tool:isCrouching() and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight
	local totalWeight = 0.0

	for name, animation in pairs( self.tpAnimations.animations ) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min( animation.weight + ( self.tpAnimations.blendSpeed * dt ), 1.0 )

			if animation.time >= animation.info.duration - self.blendTime then
				if ( name == "use" or name == "useempty" ) then
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
end

function BlahajHolder:client_onToggle()
	return false
end

function BlahajHolder:client_onEquip()
    local currentRenderablesTp = {}
	local currentRenderablesFp = {}
	for k,v in pairs( renderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	for k,v in pairs( renderables ) do
        currentRenderablesTp[#currentRenderablesTp+1] = v
        currentRenderablesFp[#currentRenderablesFp+1] = v
    end

	self.tool:setTpRenderables( currentRenderablesTp )
	if self.tool:isLocal() then
		self.tool:setFpRenderables( currentRenderablesFp )
	end

    self:cl_loadAnimations()

    setTpAnimation( self.tpAnimations, "pickup", 0.0001 )
    if self.tool:isLocal() then
        swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
    end

	sm.effect.playEffect( "Glowgorp - Pickup", self.tool:getOwner().character.worldPosition )
	self.wantEquipped = true
end

function BlahajHolder:client_onUnequip()
	self.wantEquipped = false
	self.equipped = false

    setTpAnimation( self.tpAnimations, "putdown" )
	if self.tool:isLocal() and self.fpAnimations.currentAnimation ~= "unequip" then
    	swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
	end
end

function BlahajHolder:client_onEquippedUpdate( lmb )
	return false, false
end