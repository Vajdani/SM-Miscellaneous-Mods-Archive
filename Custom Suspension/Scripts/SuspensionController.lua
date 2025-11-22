---@class SuspensionController : ShapeClass
SuspensionController = class()
SuspensionController.maxChildCount = -1
SuspensionController.connectionOutput = sm.interactable.connectionType.piston

local customUUID = sm.uuid.new("64900993-568c-416a-b73a-318fcc874f53")
local stiffness = 7500 --100000 * 0.1
function SuspensionController:server_onFixedUpdate()
    local children = self.interactable:getJoints() --self.interactable:getChildren(sm.interactable.connectionType.piston)
    for k, joint in pairs(children) do
        if joint.uuid ~= customUUID then
            goto continue
        end

        -- print("success!")
        -- local length = joint:getLength()
        -- local fraction = 1 - (length/2)
        -- joint:setTargetLength(1, 10, stiffness * (1 + fraction))
        joint:setTargetLength(1, 15, stiffness)

        ::continue::
    end
end