Grenade_tool = class()

local grende_uuid = sm.uuid.new("27231323-22b2-446b-b27f-7942c47cce46")

function Grenade_tool:client_onCreate()
    g_grenadeTool = self.tool

    self.isLocal = self.tool:isLocal()
    sm.localPlayer.getPlayer():setClientPublicData(
        {
            hasGrenade = false
        }
    )
end

function Grenade_tool:client_onUpdate()
    if not self.isLocal then return end

    local hit, result = sm.localPlayer.getRaycast( 7.5 )
    if not hit then return end

    local shape = result:getShape()
    if not shape or shape.uuid ~= grende_uuid then return end

    sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use", true), "Pick up Grenade")
end

function Grenade_tool:cl_onPickup()
    print("event recieved")

    self.hasGrenade = true
end



function Grenade_tool:sv_onPickup()
    self.network:sendToClients("cl_onPickup")
end