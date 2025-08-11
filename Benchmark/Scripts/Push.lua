---@class Push : ToolClass
Push = class()

function Push:sv_push(mul)
    local char = self.tool:getOwner().character
    local pos, dir = char.worldPosition, char.direction
    local force = dir * 100 * mul
    for k, body in pairs(sm.body.getAllBodies()) do
        local shape = body:getShapes()[1]
        if dir:dot((shape.worldPosition - pos):normalize()) > 0.35 then
            sm.physics.applyImpulse(shape, force * math.random(), true)
        end
    end
end


function Push:client_onEquippedUpdate(lmb, rmb, f)
    if lmb == 1 then
        self.network:sendToServer("sv_push", 1)
    end

    if rmb == 1 then
        self.network:sendToServer("sv_push", -1)
    end

    return true, true
end