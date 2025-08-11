--Globals
vec3_up = sm.vec3.new(0,0,1)



--functions
function GetLength( table )
    local count = 0
    for k, v in pairs(table) do
        count = count + 1
    end

    return count
end

function GetValueByIndex( table, index )
    local count = 0
    for k, v in pairs(table) do
        count = count + 1
        if count == index then
            return k, v
        end
    end

    return 0, {}
end

function ColourLerp(c1, c2, t)
    local r = sm.util.lerp(c1.r, c2.r, t)
    local g = sm.util.lerp(c1.g, c2.g, t)
    local b = sm.util.lerp(c1.b, c2.b, t)
    return sm.color.new(r,g,b)
end

function TableToVec3( table )
    return sm.vec3.new(table.x, table.y, table.z)
end

function Raycast_GetHitObj(raycastResult)
    return raycastResult:getShape() or
    raycastResult:getBody() or
    raycastResult:getCharacter() or
    raycastResult:getHarvestable() or
    raycastResult:getJoint() or
    raycastResult.type
end


---Returns whether the provided character is standing on the ground.
---@param character Character
---@return boolean
---@return RaycastResult
function Char_IsOnGround( character )
    local feetPos = character.worldPosition - sm.vec3.new(0,0,character:getHeight() / 2)
	local endPoint = feetPos - sm.vec3.new(0,0,0.25)
	local hit, result = sm.physics.spherecast( feetPos, endPoint, 0.25, character, 1 + 2 + 128 + 256 + 32768 )
    return hit, result
end

---@param moveDir Vec3
---@param char Character
---@return Vec3
function TranslateMovementDir( moveDir, char )
    local dir = char.direction
    local right = CalculateRightVector( dir )
    local fwd = vec3_up:cross(right)

    local returned = sm.vec3.zero()
    returned = returned + fwd * moveDir.y
    returned = returned + right * moveDir.x

    return returned
end

---@param rayResult RaycastResult
---@return table
function RayResultToTable( rayResult )
    return {
        valid = rayResult.valid,
        originWorld = rayResult.originWorld,
        directionWorld = rayResult.directionWorld,
        normalWorld = rayResult.normalWorld,
        normalLocal = rayResult.normalLocal,
        pointWorld = rayResult.pointWorld,
        pointLocal = rayResult.pointLocal,
        type = rayResult.type,
        fraction = rayResult.fraction,
    }
end


--Thanks QMark

---@param vector Vec3
---@return Vec3
function CalculateRightVector(vector)
    local yaw = math.atan2(vector.y, vector.x) - math.pi / 2
    return sm.vec3.new(math.cos(yaw), math.sin(yaw), 0)
end

---@param vector Vec3
---@return Vec3
function CalculateUpVector(vector)
    return CalculateRightVector(vector):cross(vector)
end



--Classes
Line = class()

---@param thickness number
---@param colour Color
function Line:init( thickness, colour )
    self.effect = sm.effect.createEffect("ShapeRenderable")
	self.effect:setParameter("uuid", sm.uuid.new("628b2d61-5ceb-43e9-8334-a4135566df7a"))
    self.effect:setParameter("color", colour)
    self.effect:setScale( sm.vec3.one() * thickness )

    self.thickness = thickness
	self.spinTime = 0
end

---@param startPos Vec3
---@param endPos Vec3
---@param dt number
---@param spinSpeed number
function Line:update( startPos, endPos, dt, spinSpeed )
	local delta = endPos - startPos
    local length = delta:length()

    if length <= 0.01 then
        self:stop()
        return
	end

	local rot = sm.vec3.getRotation(vec3_up, delta)
	local speed = spinSpeed or 1
    local deltaTime = dt or 0
	self.spinTime = self.spinTime + deltaTime * speed
	rot = rot * sm.quat.angleAxis( math.rad(self.spinTime), vec3_up )

	local distance = sm.vec3.new(self.thickness, self.thickness, length)

	self.effect:setPosition(startPos + delta * 0.5)
	self.effect:setScale(distance)
	self.effect:setRotation(rot)

    if not self.effect:isPlaying() then
        self.effect:start()
    end
end

function Line:stop()
	self.effect:stop()
end