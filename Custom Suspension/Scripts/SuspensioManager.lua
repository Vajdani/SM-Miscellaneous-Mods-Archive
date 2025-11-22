---@class SuspensioManager : ToolClass
SuspensioManager = class()

function SuspensioManager:server_onCreate()
    if g_suspensioManager then return end

    g_suspensioManager = self
end

local customUUID = sm.uuid.new("64900993-568c-416a-b73a-318fcc874f53")
function SuspensioManager:server_onFixedUpdate()
    if g_suspensioManager ~= self then return end

    -- print("szuszpéncióné")
    -- for k, body in pairs(sm.body.getAllBodies()) do
    --     for _k, joint in pairs(body:getJoints()) do
    --         if joint.uuid == customUUID then
    --             -- print("wao")
    --             -- print("a")
    --             joint:setTargetLength(1, 100)
    --         end
    --     end
    -- end
end