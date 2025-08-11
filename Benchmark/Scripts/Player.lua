---@class Player : PlayerClass
Player = class()

function Player:server_onCreate()
	print("Player.server_onCreate")
end

local uuid = sm.uuid.new("9f0f56e8-2c31-4d83-996c-d00a9b296c3f")
local uuid2 = sm.uuid.new("a6c6ce30-dd47-4587-b475-085d55c6a3b4")
local vec3_new = sm.vec3.new
local rotation = sm.quat.identity()
local size = vec3_new(1,1,1)
local limit = 4 * 4096 - 1
if not count then
	count = 0
end

function Player:sv_spawnParts()
	-- sm.physics.setGravity(10)

	-- self.sus = self.sus or {}

	local char = self.player.character
	local center = char.worldPosition + char.direction * 10

	local amount = 16
	local half_neg, half_pos = amount * -0.5, amount * 0.5 - 1
	for x = half_neg, half_pos do
		for y = half_neg, half_pos do
			for z = half_neg, half_pos do
				if count == limit then
					sm.log.warning("limit reached")
					return
				end

				-- sm.shape.createPart(uuid, center + vec3_new(x, y, z) * 0.25)
				sm.shape.createBlock(uuid2, size, center + vec3_new(x, y, z) * 0.25)
				-- sm.debris.createDebris(uuid2, center + vec3_new(x, y, z) * 0.25, rotation)

				-- local effect = sm.effect.createEffect("Explosion - Debris")
				-- effect:setParameter("material", uuid2)
				-- effect:setPosition(center + vec3_new(x, y, z) * 0.25)
				-- effect:start()
				-- self.sus[#self.sus+1] = effect

				count = count + 1
			end
		end
	end

	print(count)
end

function Player:sv_clearParts()
	for k, v in pairs(sm.body.getAllBodies()) do
		for _k, _v in pairs(v:getCreationShapes()) do
			_v:destroyShape()
		end
	end

	count = 0

	-- for k, v in pairs(self.sus or {}) do
	-- 	v:destroy()
	-- end
	-- self.sus = {}
end

function Player:client_onReload()
	-- self.network:sendToServer("sv_spawnParts")
	self:sv_spawnParts()
end

function Player:client_onInteract(char, state)
	if not state then return end

	local hit, result = sm.localPlayer.getRaycast(7.5)
	-- if not hit or result.type ~= "body" or not result:getShape().interactable then
	if not hit then
		self.network:sendToServer("sv_clearParts")
	end
end