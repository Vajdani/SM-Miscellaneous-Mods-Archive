dofile "$SURVIVAL_DATA/Scripts/util.lua"

---@class HumanCharacter : CharacterClass
---@field cl table
---@field graphicsLoaded boolean
---@field animationsLoaded boolean
HumanCharacter = class( nil )

local spudgunRend = {
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Base/char_spudgun_base_basic.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Barrel/Barrel_basic/char_spudgun_barrel_basic.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Sight/Sight_basic/char_spudgun_sight_basic.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Stock/Stock_broom/char_spudgun_stock_broom.rend",
	"$GAME_DATA/Character/Char_Tools/Char_spudgun/Tank/Tank_basic/char_spudgun_tank_basic.rend"
}

local anims = {
	--idle = "spudgun_idle",

	sprint = "spudgun_sprint",
	run = "spudgun_run_fwd",
	run_bwd = "spudgun_run_bwd",

	jump = "spudgun_jump",
	jump_up = "spudgun_jump_up",
	jump_down = "spudgun_jump_down",

	jump_land = "spudgun_jump_land",
	jump_land_fwd = "spudgun_jump_land_fwd",
	jump_land_bwd = "spudgun_jump_land_bwd",

	crouch_idle = "spudgun_crouch_idle",
	crouch_fwd = "spudgun_crouch_fwd",
	crouch_bwd = "spudgun_crouch_bwd"
}

local headLerpSpeed = 1.0 / 3.0

function HumanCharacter.client_onCreate( self )

	self.cl = {}
	self.cl.animations = {}
	self.cl.target = nil

	self:client_onRefresh()
end

function HumanCharacter.client_onRefresh( self )
	self.cl.headAngle = 0.5
end

function HumanCharacter.client_onGraphicsLoaded( self )
	self:cl_initGraphics()
	self.graphicsLoaded = true
end

function HumanCharacter.client_onGraphicsUnloaded( self )
	self.graphicsLoaded = false
end

function HumanCharacter.cl_initGraphics( self )
	self.character:setMovementEffects( "$GAME_DATA/Character/mechanic_movement_effects.json" )
	for k, v in pairs(spudgunRend) do
		self.character:addRenderable(v)
	end

	self.cl.animations.shoot = {
		info = self.character:getAnimationInfo( "spudgun_shoot" ),
		time = 0,
		weight = 0
	}

	for normal, gun in pairs(anims) do
		self.cl.animations[normal] = {
			info = self.character:getAnimationInfo( gun ),
			time = 0,
			weight = 0
		}
	end

	self.animationsLoaded = true

	self.cl.blendSpeed = 5.0
	self.cl.blendTime = 0.2

	self.cl.currentAnimation = ""
end

function HumanCharacter.client_onUpdate( self, deltaTime )
	if not self.graphicsLoaded then
		return
	end

	-- Update spine bending animation
	local lookDirection = self.character.direction
	if self.cl.target and sm.exists( self.cl.target ) then
		lookDirection = ( self.cl.target.worldPosition - self.character.worldPosition ):normalize()
	end
	local angle = math.asin( lookDirection:dot( sm.vec3.new( 0, 0, 1 ) ) ) / ( math.pi / 2 )
	local desiredHeadAngle = ( 0.5 + angle * 0.5 )
	local blend = math.pow( 1 - ( 1 - headLerpSpeed ), ( deltaTime * 60 ) )
	self.cl.headAngle = lerp( self.cl.headAngle, desiredHeadAngle, blend )
	self.character:updateAnimation( "spine_bend", 1 - self.cl.headAngle, 1.0, true )

	-- Update animations
	local currentAnimation = self.character:getActiveAnimations()
	self.character:setMovementWeights(1,0)
	for name, animation in pairs(self.cl.animations) do
		if animation.info then
			animation.time = animation.time + deltaTime

			local shoudPlay, normalWeight = self:isActiveAnim(currentAnimation, name)
			if shoudPlay then
				animation.weight = normalWeight
			elseif name == self.cl.currentAnimation then
				animation.weight = math.min(animation.weight+(self.cl.blendSpeed * deltaTime), 1.0)
				if animation.time >= animation.info.duration then
					self.cl.currentAnimation = ""
				end
			else
				animation.weight = math.max(animation.weight-(self.cl.blendSpeed * deltaTime ), 0.0)
			end

			self.character:updateAnimation( animation.info.name, animation.time, animation.weight, shoudPlay )
		end
	end
end

function HumanCharacter.client_onEvent( self, event )
	self:client_handleEvent( event )
end

function HumanCharacter.client_handleEvent( self, event )
	if not self.animationsLoaded then
		return
	end

	if event == "shoot" then
		if self.cl.animations.shoot then
			self.cl.currentAnimation = "shoot"
			self.cl.animations.shoot.time = 0
		end
		if self.graphicsLoaded then
			local catapultPos = self.character:getTpBonePos( "jnt_right_weapon" )
			local catapultRot = self.character:getTpBoneRot( "jnt_right_weapon" )
			local fireOffset = catapultRot * sm.vec3.new( 0, 0, 1 )
			sm.effect.playEffect( "TapeBot - Shoot", catapultPos + fireOffset, nil, catapultRot )
		end
	elseif event == "alerted" then
		print("alert")
	elseif event == "roaming" then
		print("roam")
	elseif event == "hit" then
		self.cl.currentAnimation = ""
	elseif event == "death" then
		if self.character:getCharacterType() == unit_tapebot_red then
			SpawnDebris( self.character, "head_jnt", "Robotparts - RedtapebotHead" )
		else
			SpawnDebris( self.character, "head_jnt", "Robotparts - TapebotHead" )
		end
		SpawnDebris( self.character, "spine1_jnt", "Robotparts - TapebotTorso" )
		SpawnDebris( self.character, "l_arm_jnt", "Robotparts - TapebotLeftarm" )
		sm.effect.playEffect( "TapeBot - Destroyed", self.character.worldPosition, nil, nil, nil, { Color = self.character:getColor() } )
	end
end

function HumanCharacter.sv_n_updateTarget( self, params )
	self.network:sendToClients( "cl_n_updateTarget", params )
end

function HumanCharacter.cl_n_updateTarget( self, params )
	self.cl.target = params.target
end


---@param anims ActiveAnimationInfo[]
---@param anim string
function HumanCharacter:isActiveAnim(anims, anim)
	for k, active in pairs(anims) do
		if active.name == anim then
			return true, active.weight
		end
	end

	return false, 0
end