local vec3_up = sm.vec3.new(0,0,1)
local vec3_zero = sm.vec3.zero()
local tool_input = sm.uuid.new("3ec0581e-b63c-4f6f-b941-19ca663fa970")

g_heroDatabase = sm.json.open("$CONTENT_DATA/Scripts/json/heroDatabase.json")

---@param vector Vec3
---@return Vec3
local function calculateRightVector(vector)
    local yaw = math.atan2(vector.y, vector.x) - math.pi / 2
    return sm.vec3.new(math.cos(yaw), math.sin(yaw), 0)
end

local function calculateUpVector(vector)
    return calculateRightVector(vector):cross(vector)
end

--dofile "$GAME_DATA/Scripts/game/BasePlayer.lua"
---@class Player : PlayerClass
Player = class() --class( BasePlayer )

function Player:server_onCreate()
	print("Player.server_onCreate")

	sm.container.beginTransaction()
	self.player:getHotbar():setItem(0, tool_input, 1)
	sm.container.endTransaction()

	self.collectedHeroes = {
		g_heroDatabase[1],
		g_heroDatabase[2]
	}
	self.selectedHero = 1
end

function Player:server_onFixedUpdate()
	if true then return end
	self.collectedHeroes = {
		g_heroDatabase[1],
		g_heroDatabase[2],
		g_heroDatabase[3],
		g_heroDatabase[4],
		g_heroDatabase[5],
		g_heroDatabase[6]
	}
end

function Player:sv_cycleHero( change )
	if #self.collectedHeroes <= 1 then return end

	if change == 1 then
		self.selectedHero = self.selectedHero < #self.collectedHeroes and self.selectedHero + change or 1
	else
		self.selectedHero = self.selectedHero > 1 and self.selectedHero + change or #self.collectedHeroes
	end

	local hero = self.collectedHeroes[self.selectedHero]
	sm.event.sendToCharacter(g_heroChar, "sv_changeHero", { hero = hero })
end

function Player:sv_spawn(pos)
	sm.unit.createUnit(sm.uuid.new("e60594b7-97c2-41e3-aa2d-805b6a223de2"), pos)
end

function Player:sv_clear()
	for k, unit in pairs(sm.unit.getAllUnits()) do
		unit:destroy()
	end
end


---@type Player
g_heroController = g_heroController or nil
function Player:client_onCreate()
	print("Player.client_onCreate")

	g_heroController = sm.player.getAllPlayers()[1]
end

function Player:client_onUpdate(dt)
	local cam = sm.camera
	if not g_heroChar or not sm.exists(g_heroChar) then
		if cam.getCameraState() ~= 0 then
			cam.setCameraState(0)
			self.selectedHero = 1
		end
		return
	end

	if cam.getCameraState() ~= 3 then
		cam.setCameraState(3)
		cam.setFov(cam.getDefaultFov())
	end

	local dir = g_heroController.character and g_heroController.character.direction or vec3_up
	local pos = g_heroChar.worldPosition - dir * 1.5 + (calculateRightVector(dir) + vec3_up) * 0.5
	local lerp = dt * 15
	cam.setPosition(sm.vec3.lerp(cam.getPosition(), pos, lerp))
	cam.setDirection(sm.vec3.lerp(cam.getDirection(), dir, lerp))
end

function Player:client_onInteract(character, state)
	if not state then return end

	if character:isCrouching() then
		self.network:sendToServer("sv_clear")
		return
	end

	local hit, result = sm.localPlayer.getRaycast(100)
	if hit then
		self.network:sendToServer("sv_spawn", result.pointWorld)
	end
end

function Player:cl_cycleHero( args )
	self.network:sendToServer("sv_cycleHero", args.change)
end



-- #region Hero unit
---@class Hero_unit : UnitClass
Hero_unit = class()

---@type Character
g_heroChar = g_heroChar or nil

function Hero_unit:server_onCreate()
	print("Hero Unit created")
end

function Hero_unit:server_onDestroy()
	print("Hero Unit destroyed")
	g_heroController.character:setWorldPosition(vec3_up)
end

---@param moveDir Vec3
---@param char Character
function Hero_unit:translateDir( moveDir, char )
    local fwd = char.direction; fwd.z = 0; fwd:normalize()
    local right = fwd:cross(sm.vec3.new(0,0,1))

    local returned = sm.vec3.zero()
    returned = returned + fwd * moveDir.y
    returned = returned + right * moveDir.x

	if returned ~= vec3_zero then
		return returned:normalize()
	end

	return returned
end

function Hero_unit:server_onFixedUpdate()
	local char = self.unit.character
	if not char or not sm.exists(char) then return end

	local pChar = g_heroController.character
	if pChar and sm.exists(pChar) then
		pChar:setWorldPosition(char.worldPosition - vec3_up * 10)
		self.unit:setFacingDirection(pChar.direction)

		local moveDir = self:translateDir(g_moveDir or vec3_zero, char)
		print(moveDir)
		self.unit:setMovementDirection(moveDir)
		self.unit:setMovementType(moveDir == vec3_zero and "stand" or "sprint")
	end
end


-- #endregion


-- #region Hero character
dofile( "$SURVIVAL_DATA/Scripts/game/characters/BaseCharacter.lua" )
---@class Hero_char : CharacterClass
---@field renderables table
---@field cutsceneAnimations table
---@field animations table
---@field FPanimations table
---@field graphicsLoaded boolean
---@field animationsLoaded boolean
---@field isLocal boolean
---@field blendSpeed number
---@field blendTime number
---@field koEffect Effect
---@field diveEffect Effect
Hero_char = class() --class( BaseCharacter )

function Hero_char.server_onCreate( self )
	--BaseCharacter.server_onCreate( self )

	self.heroData = g_heroDatabase[1]
end

function Hero_char:sv_changeHero( args )
	local hero = args.hero
	self.heroData = hero
	self.network:sendToClients("cl_changeHero", hero)
end

function Hero_char:server_onFixedUpdate()
	if not self.character or not sm.exists(self.character) then return end

	self.character.movementSpeedFraction = self.heroData.stats.movementSpeed
end



function Hero_char.client_onCreate( self )
	g_heroChar = self.character

	--BaseCharacter.client_onCreate( self )
	self.animations = {}
	--self.isLocal = self.character:getPlayer() == sm.localPlayer.getPlayer()
	--TODO isLocal check that works the first frame, sm.localPlayer.getPlayer() crashes the game
	self.isLocal = false
	print( "-- Hero_char created --" )
	self:client_onRefresh()
end

function Hero_char.client_onDestroy( self )
	print( "-- Hero_char destroyed --" )
end

function Hero_char.client_onRefresh( self )
	print( "-- Hero_char refreshed --" )
end

function Hero_char.client_onGraphicsLoaded( self )
	--BaseCharacter.client_onGraphicsLoaded( self )

	self.isLocal = self.character:getPlayer() == sm.localPlayer.getPlayer()
	self.diveEffect = sm.effect.createEffect( "Mechanic underwater", self.character, "jnt_head" )
	self.koEffect = sm.effect.createEffect( "Mechanic - KoLoop", self.character, "jnt_head" )

	self.graphicsLoaded = true

	-- Third person animations
	self.animations = {}
	self.cutsceneAnimations = {}

	self.blendSpeed = 5.0
	self.blendTime = 0.2

	self.currentAnimation = ""

	-- First person animations
	if self.isLocal then
		self.FPanimations = {}

		self.currentFPAnimation = ""
	end
	self.animationsLoaded = true

	self.renderables = {}
	self:cl_changeHero( g_heroDatabase[1] )
	--self.character:addRenderable( "$SURVIVAL_DATA/Character/Char_Male/Head/Male/char_male_head01/char_male_head01.rend" )
end

function Hero_char:cl_changeHero( hero )
	local character = self.character
	sm.effect.playHostedEffect( "Part - Upgrade", character )

	for k, rend in pairs(self.renderables) do
		character:removeRenderable(rend)
	end

	self.renderables = {}
	for k, rend in pairs(hero.renderables) do
		character:addRenderable(rend)
		self.renderables[#self.renderables+1] = rend
	end

	sm.gui.displayAlertText("Switched to hero: #df7f00"..hero.name, 2.5)
end

function Hero_char.client_onGraphicsUnloaded( self )
	--BaseCharacter.client_onGraphicsUnloaded( self )
	self.graphicsLoaded = false
	if self.diveEffect then
		self.diveEffect:destroy()
		self.diveEffect = nil
	end

	if self.koEffect then
		self.koEffect:destroy()
		self.koEffect = nil
	end
end

function Hero_char.client_onUpdate( self, deltaTime )
	--BaseCharacter.client_onUpdate( self, deltaTime )
	if not self.graphicsLoaded then
		return
	end

	if self.character:isDowned() and not self.koEffect:isPlaying() then
		sm.effect.playEffect( "Mechanic - Ko", self.character.worldPosition )
		self.koEffect:start()
	elseif not self.character:isDowned() and self.koEffect:isPlaying() then
		self.koEffect:stop()
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

function Hero_char.client_onEvent( self, event )
	self:cl_handleEvent( event )
end

function Hero_char.cl_e_onEvent( self, event )
	self:cl_handleEvent( event )
end

function Hero_char.cl_handleEvent( self, event )
	if not self.animationsLoaded then
		return
	end

	if self.currentAnimation == "" then
		if event == "hit" then
			sm.effect.playEffect( "Character - Hit", self.character.worldPosition )
		else
			self.currentAnimation = ""
			self.currentFPAnimation = ""
		end
	end
end

function Hero_char.cl_e_onCancel( self )
	-- Abort cutscene animations
	if isAnyOf( self.currentAnimation, self.cutsceneAnimations ) then
		self.animations[self.currentAnimation].time = 0
		self.currentAnimation = ""
	end
end
-- #endregion