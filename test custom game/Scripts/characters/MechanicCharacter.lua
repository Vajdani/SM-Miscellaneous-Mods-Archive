dofile( "$SURVIVAL_DATA/Scripts/game/characters/BaseCharacter.lua" )

MechanicCharacter = class( BaseCharacter )

local BaguetteSteps = 10

local multiknifeRenderableTp = "$GAME_DATA/Character/Char_Tools/Char_multiknife/char_multiknife_tp.rend"
local multiknifeRenderableFp = "$GAME_DATA/Character/Char_Tools/Char_multiknife/char_multiknife_fp.rend"

local baguetteRenderableTp = "$SURVIVAL_DATA/Character/Char_Tools/Char_longsandwich/char_male_headsandwich.rend"
sm.character.preloadRenderables( { multiknifeRenderableTp, baguetteRenderableTp } )

function MechanicCharacter.server_onCreate( self )
	BaseCharacter.server_onCreate( self )
	local player = self.character:getPlayer()
	if player then
		sm.event.sendToPlayer( player, "sv_e_onSpawnCharacter" )
	end
end

function MechanicCharacter.client_onCreate( self )
	BaseCharacter.client_onCreate( self )
	self.animations = {}
	--self.isLocal = self.character:getPlayer() == sm.localPlayer.getPlayer()
	--TODO isLocal check that works the first frame, sm.localPlayer.getPlayer() crashes the game
	self.isLocal = false
	self.baguetteDesiredElapsed = 0.0
	self.hasBaguette = false
	self.chewing = false
	print( "-- MechanicCharacter created --" )
	self:client_onRefresh()
end

function MechanicCharacter.client_onDestroy( self )
	print( "-- MechanicCharacter destroyed --" )
end

function MechanicCharacter.client_onRefresh( self )
	print( "-- MechanicCharacter refreshed --" )
end

function MechanicCharacter.client_onGraphicsLoaded( self )
	BaseCharacter.client_onGraphicsLoaded( self )

	self.isLocal = self.character:getPlayer() == sm.localPlayer.getPlayer()
	self.diveEffect = sm.effect.createEffect( "Mechanic underwater", self.character, "jnt_head" )
	self.refineEffect = sm.effect.createEffect( "Multiknife - Use" )
	self.koEffect = sm.effect.createEffect( "Mechanic - KoLoop", self.character, "jnt_head" )
	self.chewEffect = sm.effect.createEffect( "Mechanic - EatBaguette", self.character, "jnt_head" )
		
	self.graphicsLoaded = true
	
	-- Third person animations
	self.animations = {}
	self.animations.refine = {
		info = self.character:getAnimationInfo( "multiknife_use" ),
		time = 0,
		weight = 0
	}

	self.animationBaguetteIdle = {
		info = self.character:getAnimationInfo( "sandwich_eat" ),
		time = 0,
		weight = 0
	}
	self.animationBaguetteChew = {
		info = self.character:getAnimationInfo( "sandwich_idle" ),
		time = 0,
		weight = 0
	}
	self.animationBaguette = {
		info = self.character:getAnimationInfo( "headsandwich_eat" ),
		time = 0,
		weight = 0
	}

	self.animations.dramatics_standup = {
		info = self.character:getAnimationInfo( "dramatics_standup" ),
		time = 0,
		weight = 0
	}

	self.animations.dramatics_victory_in = {
		info = self.character:getAnimationInfo( "dramatics_victory_in" ),
		time = 0,
		weight = 0
	}

	self.animations.dramatics_victory_loop = {
		info = self.character:getAnimationInfo( "dramatics_victory_loop" ),
		time = 0,
		weight = 0,
		looping = true
	}

	self.cutsceneAnimations = { "dramatics_standup" }

	self.blendSpeed = 5.0
	self.blendTime = 0.2

	self.currentAnimation = ""

	-- First person animations
	if self.isLocal then
		self.FPanimations = {}
		self.FPanimations.refine = {
			info = sm.localPlayer.getFpAnimationInfo( "multiknife_use" ),
			time = 0,
			weight = 0
		}
		self.currentFPAnimation = ""
	end

	local mechanicOutfits = {
		{
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Backpack/Outfit_applicator_backpack/char_shared_outfit_applicator_backback.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Gloves/Outfit_applicator_gloves/char_shared_outfit_applicator_gloves.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Hat/Outfit_applicator_hat/char_shared_outfit_applicator_hat.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Jacket/Outfit_applicator_jacket/char_male_outfit_applicator_jacket.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Pants/Outfit_applicator_pants/char_male_outfit_applicator_pants.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Shoes/Outfit_applicator_shoes/char_male_outfit_applicator_shoes.rend"
		},
		{
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Backpack/Outfit_automotive_backpack/char_shared_outfit_automotive_backpack.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Gloves/Outfit_automotive_gloves/char_shared_outfit_automotive_gloves.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Hat/Outfit_automotive_hat/char_male_outfit_automotive_hat.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Jacket/Outfit_automotive_jacket/char_male_outfit_automotive_jacket.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Pants/Outfit_automotive_pants/char_male_outfit_automotive_pants.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Shoes/Outfit_automotive_shoes/char_male_outfit_automotive_shoes.rend"
		},
		{
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Backpack/Outfit_default_backpack/char_shared_outfit_default_backpack.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Gloves/Outfit_default_gloves/char_shared_outfit_default_gloves.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Hair/Male/char_male_hair_01/char_male_hair_01.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Jacket/Outfit_default_jacket/char_male_outfit_default_jacket.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Pants/Outfit_default_pants/char_male_outfit_default_pants.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Shoes/Outfit_default_shoes/char_male_outfit_default_shoes.rend"
		},
		{
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Backpack/Outfit_defaultdamaged_backpack/char_shared_outfit_defaultdamaged_backpack.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Gloves/Outfit_defaultdamaged_gloves/char_male_outfit_defaultdamaged_gloves.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Hair/Male/char_male_hair_01/char_male_hair_01.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Jacket/Outfit_defaultdamaged_jacket/char_male_outfit_defaultdamaged_jacket.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Pants/Outfit_defaultdamaged_pants/char_male_outfit_defaultdamaged_pants.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Shoes/Outfit_defaultdamaged_shoes/char_male_outfit_defaultdamaged_shoes.rend"
		},
		{
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Backpack/Outfit_delivery_backpack/char_shared_outfit_delivery_backpack.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Gloves/Outfit_delivery_gloves/char_male_outfit_delivery_gloves.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Hat/Outfit_delivery_hat/char_male_outfit_delivery_hat.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Jacket/Outfit_delivery_jacket/char_male_outfit_delivery_jacket.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Pants/Outfit_delivery_pants/char_male_outfit_delivery_pants.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Shoes/Outfit_delivery_shoes/char_male_outfit_delivery_shoes.rend"
		},
		{
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Backpack/Outfit_demolition_backpack/char_shared_outfit_demolition_backpack.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Gloves/Outfit_demolition_gloves/char_male_outfit_demolition_gloves.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Hat/Outfit_demolition_hat/char_shared_outfit_demolition_hat.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Hair/Male/char_male_hair_01/char_male_hair_01.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Jacket/Outfit_demolition_jacket/char_male_outfit_demolition_jacket.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Pants/Outfit_demolition_pants/char_male_outfit_demolition_pants.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Shoes/Outfit_demolition_shoes/char_male_outfit_demolition_shoes.rend"
		},
		{
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Backpack/Outfit_engineer_backpack/char_shared_outfit_engineer_backpack.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Gloves/Outfit_engineer_gloves/char_male_outfit_engineer_gloves.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Hat/Outfit_engineer_hat/char_male_outfit_engineer_hat.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Jacket/Outfit_engineer_jacket/char_male_outfit_engineer_jacket.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Pants/Outfit_engineer_pants/char_male_outfit_engineer_pants.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Shoes/Outfit_engineer_shoes/char_male_outfit_engineer_shoes.rend"
		},
		{
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Backpack/Outfit_golf_backpack/char_shared_outfit_golf_backpack.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Gloves/Outfit_golf_gloves/char_male_outfit_golf_gloves.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Hat/Outfit_golf_hat/char_male_outfit_golf_hat.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Jacket/Outfit_golf_jacket/char_male_outfit_golf_jacket.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Pants/Outfit_golf_pants/char_male_outfit_golf_pants.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Shoes/Outfit_golf_shoes/char_male_outfit_golf_shoes.rend"
		},
		{
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Backpack/Outfit_lumberjack_backpack/char_shared_outfit_lumberjack_backpack.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Gloves/Outfit_lumberjack_gloves/char_male_outfit_lumberjack_gloves.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Hat/Outfit_lumberjack_hat/char_male_outfit_lumberjack_hat.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Jacket/Outfit_lumberjack_jacket/char_male_outfit_lumberjack_jacket.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Pants/Outfit_lumberjack_pants/char_male_outfit_lumberjack_pants.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Shoes/Outfit_lumberjack_shoes/char_male_outfit_lumberjack_shoes.rend"
		},
		{
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Backpack/Outfit_painter_backpack/char_shared_outfit_painter_backpack.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Gloves/Outfit_painter_gloves/char_shared_outfit_painter_gloves.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Hat/Outfit_painter_hat/char_male_outfit_painter_hat.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Jacket/Outfit_painter_jacket/char_male_outfit_painter_jacket.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Pants/Outfit_painter_pants/char_male_outfit_painter_pants.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Shoes/Outfit_painter_shoes/char_male_outfit_painter_shoes.rend"
		},
		{
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Backpack/Outfit_stuntman_backpack/char_shared_outfit_stuntman_backpack.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Gloves/Outfit_stuntman_gloves/char_male_outfit_stuntman_gloves.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Hat/Outfit_stuntman_hat/char_male_outfit_stuntman_hat.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Jacket/Outfit_stuntman_jacket/char_male_outfit_stuntman_jacket.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Pants/Outfit_stuntman_pants/char_male_outfit_stuntman_pants.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Shoes/Outfit_stuntman_shoes/char_male_outfit_stuntman_shoes.rend",
		},
		{
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Backpack/Outfit_technician_backpack/char_shared_outfit_technician_backpack.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Gloves/Outfit_technician_gloves/char_male_outfit_technician_gloves.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Hat/Outfit_technician_hat/char_male_outfit_technician_hat.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Hair/Male/char_male_hair_01/char_male_hair_01.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Jacket/Outfit_technician_jacket/char_male_outfit_technician_jacket.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Pants/Outfit_technician_pants/char_male_outfit_technician_pants.rend",
			"$SURVIVAL_DATA/Character/Char_Male/Outfit/Shoes/Outfit_technician_shoes/char_male_outfit_technician_shoes.rend"
		}
	}
	for k, v in pairs(mechanicOutfits) do
		for _k, _v in pairs(v) do
			self.character:addRenderable(_v)
		end
	end

	self.animationsLoaded = true
end

function MechanicCharacter.client_onGraphicsUnloaded( self )
	BaseCharacter.client_onGraphicsUnloaded( self )
	self.graphicsLoaded = false
	if self.diveEffect then
		self.diveEffect:destroy()
		self.diveEffect = nil
	end
	if self.refineEffect then
		self.refineEffect:destroy()
		self.refineEffect = nil
	end
	if self.koEffect then
		self.koEffect:destroy()
		self.koEffect = nil
	end
	if self.chewEffect then
		self.chewEffect:destroy()
		self.chewEffect = nil
	end
end

function MechanicCharacter.client_onUpdate( self, deltaTime )
	BaseCharacter.client_onUpdate( self, deltaTime )
	if not self.graphicsLoaded then
		return
	end

	if self.character:isDowned() and not self.koEffect:isPlaying() then
		sm.effect.playEffect( "Mechanic - Ko", self.character.worldPosition )
		self.koEffect:start()
	elseif not self.character:isDowned() and self.koEffect:isPlaying() then
		self.koEffect:stop()
	end

	local activeAnimations = self.character:getActiveAnimations()
	local debugText = ""
	sm.gui.setCharacterDebugText( self.character, "" ) -- Clear debug text
	if activeAnimations then
		for i, animation in ipairs( activeAnimations ) do
			if animation.name ~= "" and animation.name ~= "spine_turn" then
				local truncatedWeight = math.floor( animation.weight * 10 + 0.5 ) / 10
				sm.gui.setCharacterDebugText( self.character, tostring( animation.name .. " : " .. truncatedWeight ), false ) -- Add debug text without clearing
			end
		end
	end
	
	-- Control diving effect
	if self.diveEffect then
		if self.character:isDiving() then
			if not self.diveEffect:isPlaying() then
				self.diveEffect:start()
			end
		elseif not self.character:isDiving() then
			if self.diveEffect:isPlaying() then
				self.diveEffect:stop()
			end
		end
	end
	
	-- Third person animations
	for name, animation in pairs(self.animations) do
		if animation.info then
			animation.time = animation.time + deltaTime
			
			if animation.info.looping == true then
				if animation.time >= animation.info.duration then
					animation.time = animation.time - animation.info.duration
				end
			end
			if name == self.currentAnimation then
				animation.weight = math.min(animation.weight+(self.blendSpeed * deltaTime), 1.0)
				if animation.time >= animation.info.duration then
					self.currentAnimation = ""
				end
			else
				animation.weight = math.max(animation.weight-(self.blendSpeed * deltaTime ), 0.0)
			end
		
			self.character:updateAnimation( animation.info.name, animation.time, animation.weight )
		end
	end

	-- Baguette animations
	if self.hasBaguette then
		self.animationBaguetteIdle.weight = math.min( self.animationBaguetteIdle.weight + ( self.blendSpeed * deltaTime ), 1.0 )
		self.animationBaguette.weight = math.min( self.animationBaguette.weight + ( self.blendSpeed * deltaTime ), 1.0 )
	else
		self.animationBaguetteIdle.weight = math.max( self.animationBaguetteIdle.weight - ( self.blendSpeed * deltaTime ), 0.0 )
		self.animationBaguette.weight = math.max( self.animationBaguette.weight - ( self.blendSpeed * deltaTime ), 0.0 )
	end
	if self.chewing then
		self.animationBaguetteChew.weight = math.min( self.animationBaguetteChew.weight + ( self.blendSpeed * deltaTime ), 1 )
	else
		self.animationBaguetteChew.weight = math.max( self.animationBaguetteChew.weight - ( self.blendSpeed * deltaTime ), 0.0 )
	end

	self.character:setAllowTumbleAnimations( self.hasBaguette or self.chewing )
	if self.animationBaguetteIdle.info then
		self.animationBaguetteIdle.time = self.animationBaguetteIdle.time + deltaTime
		if self.animationBaguetteIdle.time >= self.animationBaguetteIdle.info.duration then
			self.animationBaguetteIdle.time = self.animationBaguetteIdle.time - self.animationBaguetteIdle.info.duration
		end
		self.character:updateAnimation( self.animationBaguetteIdle.info.name, self.animationBaguetteIdle.time, self.animationBaguetteIdle.weight, true )
	end
	if self.animationBaguetteChew.info then
		if self.chewing then
			self.animationBaguetteChew.time = self.animationBaguetteChew.time + deltaTime
			if self.animationBaguetteChew.time >= self.animationBaguetteChew.info.duration then
				self.animationBaguetteChew.time = 0.0
				self.chewing = false
			end
		end
		self.character:updateAnimation( self.animationBaguetteChew.info.name, self.animationBaguetteChew.time, self.animationBaguetteChew.weight, true )
	end
	if self.animationBaguette.info then
		self.animationBaguette.time = self.animationBaguette.time + deltaTime
		self.animationBaguette.time = math.min( self.animationBaguette.time, math.min( self.baguetteDesiredElapsed, self.animationBaguette.info.duration ) )
		self.character:updateAnimation( self.animationBaguette.info.name, self.animationBaguette.time, self.animationBaguette.weight, true )
	end

	-- Play refine effects
	if self.isLocal then
		if self.currentAnimation == "refine" then
			local mayaFrameDuration = 1.0/30.0
			local refineTime = self.animations["refine"].time
			local frameTime = 6 * mayaFrameDuration
			if refineTime >= frameTime and frameTime ~= 0 then
				if self.pendingRefineFlag then
					self.pendingRefineFlag = false
					
					local sucess, result = sm.localPlayer.getRaycast( 7.5, sm.localPlayer.getRaycastStart(), sm.localPlayer.getDirection() )
					local hitShape = result:getShape()
					if sucess and hitShape then
						if sm.localPlayer.isInFirstPersonView() then
							
							local effectPos = sm.localPlayer.getFpBonePos( "pejnt_lazer" )
							if effectPos then
								
								local rot = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), sm.localPlayer.getUp() )
								rot = sm.vec3.getRotation( sm.localPlayer.getUp(), sm.localPlayer.getUp():rotate( ( 40 ) * math.pi / 180, sm.localPlayer.getDirection() ) ) * rot
								
								local fovScale = ( sm.camera.getFov() - 45 ) / 45
								
								local xOffset45 = sm.localPlayer.getRight() * 0.035
								local yOffset45 = sm.localPlayer.getDirection() * 0.6
								local zOffset45 = sm.localPlayer.getUp() * 0.1
								local offset45 = xOffset45 + yOffset45 + zOffset45
								
								local xOffset90 = sm.localPlayer.getRight() * 0.035
								local yOffset90 = sm.localPlayer.getDirection() * 0.2
								local zOffset90 = sm.localPlayer.getUp() * 0.1
								local offset90 = xOffset90 + yOffset90 + zOffset90
								
								local offset = sm.vec3.lerp( offset45, offset90, fovScale )
								
								self.refineEffect:setParameter( "Material", hitShape:getMaterialId() )
								self.refineEffect:setPosition( effectPos + offset )
								self.refineEffect:setRotation( rot )
								self.refineEffect:start()
							end
						end
						
						local params = { effectName = "Multiknife - Hit",
										position = result.pointWorld, 
										rotation = sm.vec3.getRotation( sm.vec3.new( 0, 0, 1 ), 
										result.normalWorld ), 
										effectParams = { Material = hitShape:getMaterialId(), Size = 0.005, Velocity = 10 }, 
										player = sm.localPlayer.getPlayer() }
						self:cl_onEffect( params )
						self.network:sendToServer( "sv_network_onEffect", params )
						
					end
					
				end
			elseif refineTime < frameTime and frameTime ~= 0 then
				self.pendingRefineFlag = true
			end
		end
	end
	
	-- First person animations
	if self.isLocal then
		for name, animation in pairs( self.FPanimations ) do
			if animation.info then
				animation.time = animation.time + deltaTime
				
				if animation.info.looping == true then
					if animation.time >= animation.info.duration then
						animation.time = animation.time - animation.info.duration
					end
				end
				if name == self.currentFPAnimation then
					animation.weight = math.min(animation.weight+(self.blendSpeed * deltaTime), 1.0)
					if animation.time >= animation.info.duration then
						self.currentFPAnimation = ""
					end
				else
					animation.weight = math.max(animation.weight-(self.blendSpeed * deltaTime ), 0.0)
				end
				sm.localPlayer.updateFpAnimation( animation.info.name, animation.time, animation.weight, animation.info.looping )
			end
		end
	end
end

function MechanicCharacter.client_onEvent( self, event )
	self:cl_handleEvent( event )
end

function MechanicCharacter.cl_e_onEvent( self, event )
	self:cl_handleEvent( event )
end

function MechanicCharacter.cl_handleEvent( self, event )
	if not self.animationsLoaded then
		return
	end
	
	if self.currentAnimation == "" then
		if event == "refine" then
			self.character:addRenderable( multiknifeRenderableTp )
			self.currentAnimation = "refine"
			self.animations.refine.time = 0
			if self.isLocal then
				sm.localPlayer.addRenderable( multiknifeRenderableFp )
				self.currentFPAnimation = "refine"
				self.FPanimations.refine.time = 0
			end
		elseif event == "hit" then
			sm.effect.playEffect( "Character - Hit", self.character.worldPosition )
		else
			self.currentAnimation = ""
			self.currentFPAnimation = ""
		end
	elseif self.currentAnimation == "refine" and event == "refineEnd" then
		self.character:removeRenderable( multiknifeRenderableTp )
		self.currentAnimation = ""
		if self.isLocal then
			sm.localPlayer.removeRenderable( multiknifeRenderableFp )
			self.currentFPAnimation = ""
		end
	end

	if event == "baguette" then
		self.character:addRenderable( baguetteRenderableTp )
		self.baguetteDesiredElapsed = 0.0
		self.hasBaguette = true
	elseif event == "revive" then
		self.character:removeRenderable( baguetteRenderableTp )
		self.hasBaguette = false
	elseif event == "chew" then
		if self.animationBaguette.info then
			self.baguetteDesiredElapsed = math.min( self.baguetteDesiredElapsed + self.animationBaguette.info.duration / BaguetteSteps, self.animationBaguette.info.duration )
		end
		self.chewing = true
		if self.graphicsLoaded then
			self.chewEffect:start()
		end
	elseif event == "dramatics_standup" then
		self.currentAnimation = "dramatics_standup"
		self.animations.dramatics_standup.time = 0
	elseif event == "dramatics_victory_in" then
		self.currentAnimation = "dramatics_victory_in"
		self.animations.dramatics_victory_in.time = 0
	elseif event == "dramatics_victory_loop" then
		self.currentAnimation = "dramatics_victory_loop"
		self.animations.dramatics_victory_loop.time = 0
	end
end

function MechanicCharacter.cl_e_onCancel( self )
	-- Abort cutscene animations
	if isAnyOf( self.currentAnimation, self.cutsceneAnimations ) then
		self.animations[self.currentAnimation].time = 0
		self.currentAnimation = ""
	end
end

function MechanicCharacter.cl_onEffect( self, params )
	sm.effect.playEffect( params.effectName, params.position, params.velocity, params.rotation, params.scale, params.effectParams )
end

function MechanicCharacter.cl_network_onEffect( self, params ) 
	if params.player ~= sm.localPlayer.getPlayer() then
		self:cl_onEffect( params )
	end
end

function MechanicCharacter.sv_network_onEffect( self, params )
	self.network:sendToClients( "cl_network_onEffect", params )
end
