---@class Flag : ShapeClass
Flag = class()
Flag.colorHighlight = sm.color.new("#dddddd")
Flag.colorNormal = sm.color.new( "#bbbbbb" )
Flag.connectionInput = sm.interactable.connectionType.logic
Flag.connectionOutput = sm.interactable.connectionType.none
Flag.maxChildCount = 0
Flag.maxParentCount = 1
Flag.flagCount = 2 - 1

local ico_use = sm.gui.getKeyBinding("Use", true)
local clamp = sm.util.clamp

function Flag:server_onCreate()
    local data = self.storage:load()
    self.flagIndex = data and data.index or 0
    self.network:sendToClients("cl_changeFlag", self.flagIndex)
end

function Flag:sv_changeFlag()
    self.flagIndex = self.flagIndex < self.flagCount and self.flagCount + 1 or 0
    self.storage:save({ index = self.flagIndex })
    self.network:sendToClients("cl_changeFlag", self.flagIndex)
end


function Flag:client_onCreate()
    self.interactable:setAnimEnabled("deploy", true)
    self.deploy_dur = self.interactable:getAnimDuration("deploy")
    self.deploy_counter = 1

    self.interactable:setAnimEnabled("wave", true)
    self.wave_dur = self.interactable:getAnimDuration("wave")
    self.wave_counter = 0
end

function Flag:client_onUpdate(dt)
    local parent = self.interactable:getSingleParent()

    self.deploy_counter = clamp(self.deploy_counter + dt * ((not parent or parent.active) and 1 or -1), 0, 1)
    self.interactable:setAnimProgress("deploy", self.deploy_counter)

    self.wave_counter = clamp(self.wave_counter + dt * (self.deploy_counter == 1 and 15 or -30), 0, self.wave_dur)
    local progress = self.wave_counter / self.wave_dur
    self.interactable:setAnimProgress("wave", progress)
    if progress >= 1 then self.wave_counter = 0 end
end

function Flag:client_canInteract()
    sm.gui.setInteractionText("", ico_use, "Change flag")

    return true
end

function Flag:client_onInteract(character, state)
    if not state then return end

    self.network:sendToServer("sv_changeFlag")
end

function Flag:cl_changeFlag(index)
    self.interactable:setUvFrameIndex(index)
end