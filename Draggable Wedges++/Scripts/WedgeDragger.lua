---@class WedgeDragger : ToolClass
WedgeDragger = class()

local rotations = {
    sm.quat.identity(),
    sm.quat.angleAxis(math.rad(90), sm.vec3.new(0,1,0)),
    sm.quat.angleAxis(math.rad(180), sm.vec3.new(0,1,0)),
    sm.quat.angleAxis(math.rad(270), sm.vec3.new(0,1,0)),
}

local planes = {
    "x", "y", "z"
}

---@param args { shape: Shape, origin : Vec3, scale : Vec3, rot : Vec3 }
function WedgeDragger:sv_placeWedge(args)
    args.shape.body:createWedge(
        sm.uuid.new("56b4d3fc-14bc-11ed-861d-0242ac120002"),
        args.scale * 4,
        args.origin,
        args.rot * sm.vec3.new(0,0,1),
        args.rot * sm.vec3.new(1,0,0)
    )
end



function WedgeDragger:client_onCreate()
    self.wedge = sm.effect.createEffect("ShapeRenderable")
    self.wedge:setParameter("uuid", sm.uuid.new("56b4d3fc-14bc-11ed-861d-0242ac120002"))
    self.wedge:setParameter("visualization", true)

    self.rotationIndex = 1
    self.dragPlaneIndex = 1
end

function WedgeDragger:client_onDestroy()
    if not sm.exists(self.wedge) then return end
    self.wedge:destroy()
end

function WedgeDragger:client_onToggle()
    if self.dragOrigin then
        self.dragPlaneIndex = (self.dragPlaneIndex % 4) + 1
    else
        self.rotationIndex = (self.rotationIndex % #rotations) + 1
    end

    return true
end

function WedgeDragger:client_onUnequip()
    if not self.tool:isLocal() then return end

    self.wedge:stop()
end

function WedgeDragger:client_onEquippedUpdate(lmb, rmb, f)
    local hit, result = sm.localPlayer.getRaycast(7.5)
    if not hit then
        if self.wedge:isPlaying() then
            self.wedge:stop()
        end

        return true, false
    end

    if lmb == 3 or rmb == 1 then
        if self.dragPlaneIndex > 1 then
            self.dragPlaneIndex = 1
        else
            if self.dragOrigin then
                self.network:sendToServer("sv_placeWedge", {
                    shape = self.dragShape,
                    origin = self.dragOrigin,
                    scale = self.dragScale,
                    rot = self.dragRotation
                })
            end

            self.dragShape = nil
            self.dragOrigin = nil
            self.dragScale = nil
            self.dragRotation = nil
            self.dragOriginNormal = nil
        end
    end

    local worldPos
    local shape
    if result.type == "terrainSurface" or result.type == "terrainAsset" then
        worldPos = SnapToWorldGrid(result)

        if lmb == 1 then
            self.dragShape = nil
            self.dragOrigin = worldPos
            self.dragOriginNormal = result.normalWorld
        end
    elseif result.type == "body" then
        shape = result:getShape()
        if not shape.isBlock then return true, false end

        local aimPos = shape:getClosestBlockLocalPosition(result.pointWorld) + result.normalLocal
        worldPos = ShapeLocalToWorld(shape, aimPos)

        if lmb == 1 then
            self.dragShape = shape
            self.dragOrigin = aimPos
            self.dragOriginNormal = result.normalWorld
        end
    else
        return true, false
    end

    if self.dragOrigin then
        local pos = self.dragOrigin
        local hitShape = self.dragShape
        if result.type == "terrainSurface" then
            pos = SnapToWorldGrid(result)
        elseif result.type == "body" and self.dragShape.body == result:getBody() then
            hitShape = result:getShape()
            pos = hitShape:getClosestBlockLocalPosition(result.pointWorld) + result.normalLocal
        end

        local startPos
        local endPos
        if self.dragShape then
            startPos = ShapeLocalToWorld(self.dragShape, self.dragOrigin)
            endPos = ShapeLocalToWorld(hitShape, pos)
        else
            startPos = self.dragOrigin
            endPos = SnapToWorldGrid(result)
        end

        sm.particle.createParticle("paint_smoke", startPos)
        sm.particle.createParticle("paint_smoke", endPos, sm.quat.identity(), sm.color.new(0,0,0))

        local scale = ClampScale(pos - self.dragOrigin)
        if self.dragPlaneIndex > 1 then
            scale[planes[self.dragPlaneIndex - 1]] = 0.25
        end

        local offset = scale
        if self.dragShape then
            offset = hitShape.worldRotation * scale * 0.125
        else
            scale = scale
        end

        self.dragScale = (AbsVec3(sm.vec3.new(scale.x, scale.z, scale.y)) + sm.vec3.one()) * 0.25
        self.wedge:setPosition((startPos + offset))
        self.wedge:setScale(self.dragScale)
    else
        self.wedge:setPosition(worldPos)
        self.wedge:setScale(sm.vec3.one() * 0.25)
    end

    local normal
    if self.dragOrigin then
        normal = self.dragShape and self.dragOriginNormal or self.dragOriginNormal
    else
        normal = result.normalWorld
    end

    self.dragRotation = sm.vec3.getRotation(sm.vec3.new(0,1,0), normal) * rotations[self.rotationIndex]
    self.wedge:setRotation(self.dragRotation)

    if not self.wedge:isPlaying() then
        self.wedge:start()
    end

    return true, false
end



function ShapeLocalToWorld(target, position)
	local A = position * 0.25 --target:getClosestBlockLocalPosition( position )/4
	local B = target.localPosition/4 - sm.vec3.one() * 0.125
	local C = target:getBoundingBox()
	return target:transformLocalPoint( A-(B+C*0.5) )
end

function SnapToWorldGrid(result)
    local groundPointOffset = -( sm.construction.constants.subdivideRatio_2 - 0.04 + sm.construction.constants.shapeSpacing + 0.005 )
    local pointLocal = result.pointLocal + result.normalLocal * groundPointOffset

    -- Compute grid pos
    local size = sm.vec3.new( 3, 3, 1 )
    local size_2 = sm.vec3.new( 1, 1, 0 )
    local a = pointLocal * sm.construction.constants.subdivisions
    local gridPos = sm.vec3.new( math.floor( a.x ), math.floor( a.y ), a.z ) - size_2

    -- Compute world pos
    return gridPos * sm.construction.constants.subdivideRatio + ( size * sm.construction.constants.subdivideRatio ) * 0.5 --+ result.normalWorld * 0.25
end

function AbsVec3(vec3)
	return sm.vec3.new(math.abs(vec3.x), math.abs(vec3.y), math.abs(vec3.z))
end

function ClampScale(vec3)
	return sm.vec3.new(sm.util.clamp(vec3.x, -7, 7), sm.util.clamp(vec3.y, -7, 7), sm.util.clamp(vec3.z, 0, 7))
end