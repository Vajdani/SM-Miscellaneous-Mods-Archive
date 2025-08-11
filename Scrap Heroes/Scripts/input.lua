---@class Input : ToolClass
Input = class()

function Input:client_onCreate()
    if self.tool:isLocal() then
        sm.tool.forceTool(self.tool)
    end
end

function Input:client_onFixedUpdate()
    g_moveDir = self.tool:getRelativeMoveDirection()
end

function Input:client_onToggle()
    sm.event.sendToPlayer(g_heroController, "cl_cycleHero", { change = -1 })
    return true
end

function Input:client_onReload()
    sm.event.sendToPlayer(g_heroController, "cl_cycleHero", { change = 1 })
    return true
end