---@class Cake : ShapeClass
---@field colOffset number
Cake = class()
Cake.colorHighlight = sm.color.new("#dddddd")
Cake.colorNormal = sm.color.new( "#bbbbbb" )
Cake.connectionInput = sm.interactable.connectionType.none
Cake.connectionOutput = sm.interactable.connectionType.logic
Cake.maxChildCount = -1
Cake.maxParentCount = 0

local ico_use = sm.gui.getKeyBinding("Use", true)
local colours = {
    "#ff0000",
    "#ffff00",
    "#00ff00",
    "#00ffff",
    "#0000ff",
    "#ff00ff"
}

function Cake:server_onCreate()
    self.playing = false
    self.interactable.active = false
end

function Cake:sv_toggle()
    self.playing = not self.playing
    self.interactable.active = self.playing
    self.network:sendToClients("cl_toggle", self.playing)
end



function Cake:client_onCreate()
    self.music = sm.effect.createEffect("Cake - Music", self.interactable)
    self.music:setOffsetRotation(sm.vec3.getRotation(sm.vec3.new(0,1,0), sm.vec3.new(0,0,-1)))
    self.cl_playing = false
    self.colOffset = 1
end

function Cake:client_onFixedUpdate()
    if self.cl_playing and sm.game.getCurrentTick()%10 == 0 then
        sm.gui.displayAlertText(self:getRainbowtext("Happy Birthday Anne!"), 2)
    end
end

function Cake:client_onInteract(character, state)
    if not state then return end

    self.network:sendToServer("sv_toggle")
end

function Cake:client_canInteract()
    sm.gui.setInteractionText("", ico_use, self.cl_playing and "Stop celebrating :(" or "Celebrate!")

    return true
end

function Cake:cl_toggle(state)
    if state then
        self.music:start()
        self.colOffset = 1
        sm.gui.displayAlertText(self:getRainbowtext("Happy Birthday Anne!"), 2)
    else
        self.music:stop()
    end

    self.cl_playing = state
end



function Cake:getRainbowtext(text)
    self.colOffset = self.colOffset < #colours and self.colOffset + 1 or 1
    --self.colOffset = self.colOffset > 1 and self.colOffset - 1 or #colours --cycle backwards

    local new = ""
    local colCounter = self.colOffset
    for i = 1, #text do
        local letter = string.sub(text, i, i)
        if letter == " " then
            new = new..letter
        else
            new = new..colours[colCounter]..letter
            colCounter = colCounter == 1 and #colours or colCounter - 1
        end
    end

    return new
end