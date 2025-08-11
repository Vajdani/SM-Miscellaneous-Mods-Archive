---@class Player : PlayerClass
---@field sv PlayerSvTable
---@field cl table
---@field slideDir Vec3
Player = class()

---@class PlayerSvTable
local PlayerSvTable = {}
---@type boolean
PlayerSvTable.sliding = false
---@type Vec3
PlayerSvTable.slideDir = sm.vec3.zero()
---@type Character
PlayerSvTable.whiplashTarget = {}

local DefaultSlideDir = sm.vec3.new(0,1,0)
local SlideForce = 4
local WhiplashLineVars = {
	thickness = 0.1,
	colour = sm.color.new(0.25,0.25,0.25)
}
local WhiplashRange = 100
local WhiplashSpeed = 10

dofile "$CONTENT_DATA/Scripts/util.lua"

function Player:server_onCreate()
	g_userData = sm.json.open("$CONTENT_DATA/userData.json")

	self.sv = {}
	self.sv.sliding = false
	self.sv.slideDir = sm.vec3.zero()
	self.sv.whiplashTarget = nil
end

function Player:server_onFixedUpdate( dt )
	--print(self.sv.whiplashTarget)

	local char = self.player.character
	if not char then return end

	local prevTarget = self.sv.whiplashTarget
	if self.sv.whiplashTarget and sm.exists(self.sv.whiplashTarget) then
		local dir = (self.sv.whiplashTarget.worldPosition - char.worldPosition)
		if dir:length2() > 2 then
			--sm.physics.applyImpulse( char, dir:normalize() * char.mass * WhiplashSpeed )
			char:setWorldPosition( sm.vec3.lerp(char.worldPosition, self.sv.whiplashTarget.worldPosition, dt) )
		else
			self.sv.whiplashTarget = nil
		end
	else
		self.sv.whiplashTarget = nil
	end

	if prevTarget ~= self.sv.whiplashTarget then self.network:sendToClients("cl_onWhiplashEnd") end

	if self.sv.sliding then
		local worldPos = char.worldPosition
		local hit, result = sm.physics.raycast(worldPos, worldPos - vec3_up)
		local finalDir =  self.sv.slideDir + sm.vec3.new( 0,0, sm.util.clamp( math.abs(result.normalWorld.z - 1) * 5, -1, 1) )
		local force = char:isOnGround() and SlideForce or SlideForce / 4
		sm.physics.applyImpulse( char, finalDir * char.mass * force )
	end
end

function Player:sv_updateSlideState( dir )
	self.sv.sliding = dir ~= nil
	self.sv.slideDir = dir
end

function Player:sv_onWhiplash( args )
	self.sv.whiplashTarget = args.target
	self.network:sendToClients("cl_onWhiplash", args)
end

function Player:sv_onInteract()
	sm.unit.createUnit(unit_totebot_green, sm.vec3.zero() + vec3_up * 2)
end



function Player:client_onCreate()
	self:cl_init()
end

function Player:client_onRefresh()
	self:cl_init()
end

function Player:cl_init()
	self.cl = {}
	self.cl.whiplashLine = Line()
	self.cl.whiplashLine:init( WhiplashLineVars.thickness, WhiplashLineVars.colour )
	self.cl.whiplashTarget = nil
	self.cl.whiplashStartPos = sm.vec3.zero()
	self.cl.whiplashEndPos = sm.vec3.zero()
	self.cl.whiplashAnimActive = false

	if self.player ~= sm.localPlayer.getPlayer() then return end

	g_userData = sm.json.open("$CONTENT_DATA/userData.json")
	g_weapons = {}

	self.cl.sliding = false
	self.cl.canSlide = true

	self.cl.slamming = false
	self.cl.canPowerSlam = false
end

function Player:client_onFixedUpdate()
	if self.player ~= sm.localPlayer.getPlayer() then return end

	--print(g_weapons)
	local char = self.player.character
	if not char then return end

	if self.cl.slamming or not self.cl.whiplashTarget or type(self.cl.whiplashTarget) ~= "Character" then self:cl_slide( char ) end

	self:cl_slam( char )
end

function Player:client_onUpdate( dt )
	local char = self.player.character
	if not char then return end

	if self.cl.whiplashAnimActive then
		self.cl.whiplashStartPos = sm.vec3.lerp(self.cl.whiplashStartPos, char.worldPosition, dt * 15)

		local targetPos = self.cl.whiplashStartPos
		local targetIsChar = type(self.cl.whiplashTarget) == "Character"
		local targetExists = self.cl.whiplashTarget ~= nil
		if targetExists then
			if targetIsChar then
				if sm.exists(self.cl.whiplashTarget) then
					targetPos = self.cl.whiplashTarget.worldPosition
				end
			else
				targetPos = self.cl.whiplashTarget
			end
		end

		if not targetExists then
			self.cl.whiplashEndPos = sm.vec3.lerp(self.cl.whiplashEndPos, self.cl.whiplashStartPos, dt * 25)

			if (self.cl.whiplashEndPos - targetPos):length2() <= 0.1 then
				self.cl.whiplashAnimActive = false
				self.cl.whiplashLine:stop()
				return
			end
		else
			self.cl.whiplashEndPos = sm.vec3.lerp( self.cl.whiplashEndPos, targetPos, dt * 10 )

			if (self.cl.whiplashEndPos - targetPos):length2() <= 0.0001 and (not targetIsChar or not sm.exists(self.cl.whiplashTarget)) then
				self.cl.whiplashTarget = nil
			end
		end

		self.cl.whiplashLine:update( self.cl.whiplashStartPos, self.cl.whiplashEndPos )
	end
end

function Player:client_onInteract( char, state )
	if not state then return end
	print("client_onInteract")
	self.network:sendToServer("sv_onInteract")

	return true
end

function Player:client_onReload()
	print("client_onReload")
	local hit, result = sm.localPlayer.getRaycast( WhiplashRange )
	self.network:sendToServer("sv_onWhiplash", { hit = hit, result = RayResultToTable(result), target = result:getCharacter() })

	return true
end

function Player:cl_onWhiplash( args )
	local worldPos = self.player.character.worldPosition
	self.cl.whiplashStartPos = worldPos
	self.cl.whiplashEndPos = worldPos
	self.cl.whiplashLine:stop()
	self.cl.whiplashAnimActive = true
	self.cl.whiplashTarget = args.target or (args.hit and args.result.pointWorld or args.result.originWorld + args.result.directionWorld)

	if self.player ~= sm.localPlayer.getPlayer() or type(args.target) ~= "Character" then return end
	self.cl.sliding = false
	self.network:sendToServer("sv_updateSlideState")
end

function Player:cl_onWhiplashEnd( args )
	self.cl.whiplashTarget = nil
end

function Player:cl_slide( char )
	if not Char_IsOnGround(char) then
		if self.cl.sliding then
			self.cl.sliding = false
			self.cl.canSlide = false
			self.network:sendToServer("sv_updateSlideState")
		end
	else
		local isCrouching = char:isCrouching()
		if not isCrouching then
			self.cl.canSlide = true

			if self.cl.sliding then
				self.cl.sliding = false
				self.network:sendToServer("sv_updateSlideState")
			end
		elseif isCrouching and not self.cl.sliding and self.cl.canSlide then
			self.cl.sliding = true
			local dir = self.player.clientPublicData.movementDir
			self.network:sendToServer("sv_updateSlideState", TranslateMovementDir(dir == sm.vec3.zero() and DefaultSlideDir or dir, self.player.character))
		end
	end

	char.movementSpeedFraction = self.cl.sliding and 0.1 or 1
end

function Player:cl_slam( char )
	if Char_IsOnGround(char) then
		if self.cl.slamming then
			print("slam, powerslam:", self.cl.canPowerSlam)
			self.cl.slamming = false
			self.cl.canPowerSlam = false
		end

		return
	end

	local isCrouching = char:isCrouching()
	if not isCrouching and self.cl.slamming then
		self.cl.canPowerSlam = false
	elseif isCrouching and not self.cl.slamming then
		self.cl.slamming = true
		self.cl.canPowerSlam = true
		self.cl.canSlide = false
	end
end