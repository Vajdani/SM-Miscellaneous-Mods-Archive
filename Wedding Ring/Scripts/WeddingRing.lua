---@class WeddingRing : ShapeClass
WeddingRing = class()

function WeddingRing:client_canInteract()
    sm.gui.setInteractionText("", sm.gui.getKeyBinding("Use", true), sm.localPlayer.getPlayer().clientPublicData.ringEquipped and "Take off ring" or "Put on ring")

    return true
end

function WeddingRing:client_onInteract(char, state)
    if not state then return end
    self.network:sendToServer("sv_updateRing", sm.localPlayer.getPlayer())
end

function WeddingRing:sv_updateRing(player)
    sm.event.sendToTool(g_ringManager, "sv_updateRing", player)
end