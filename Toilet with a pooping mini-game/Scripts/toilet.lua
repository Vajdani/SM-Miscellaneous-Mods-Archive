Toilet = class()

dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"

local shitRange = 15
local shitDelay = {
    min = 1 * 40,
    max = 3 * 40
}
local shitTreshold = 0.8



--Server
function Toilet:sv_explode( timeSpentShitting )
    local mult = math.floor(timeSpentShitting/10/40)
    sm.physics.explode(self.shape.worldPosition, math.max(10/mult, 1), math.max(50/mult, 1), math.max(60/mult, 1), math.max(25/mult, 1), (timeSpentShitting < 30 * 40 and "PropaneTank - ExplosionBig" or "PropaneTank - ExplosionSmall" ) )
end



--Client
function Toilet:client_onCreate()
    self.cl = {}
    self.cl.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/toiletHud.layout", false,
        {
            isHud = true,
            isInteractive = false,
            needsCursor = false,
            hidesHotbar = false,
            isOverlapped = false,
            backgroundAlpha = 0,
        }
    )

    self.cl.shitVal = 0
    self.cl.shitTimer = Timer()
    self.cl.shitTimer:start(math.random(shitDelay.min, shitDelay.max))
    self.cl.progress = 0
    self.cl.shitStartTime = 0

    self.cl.gui:createVerticalSlider( "shitBar", shitRange + 1, 0, "" )
end

function Toilet:client_onUpdate()
    if not self.cl.gui:isActive() then return end

    self.cl.gui:setSliderPosition( "shitBar", self.cl.shitVal )

    self.cl.progress = self.cl.shitTimer.count/self.cl.shitTimer.ticks
    sm.gui.setProgressFraction(self.cl.progress)

    if self.cl.progress >= shitTreshold then
        sm.gui.setInteractionText("", sm.gui.getKeyBinding("Jump", true), "SHIT!!!")
    end

    if self.cl.progress >= 1 then
        self:cl_onShit( false )
    end
end

function Toilet:client_onFixedUpdate( dt )
    if self.cl.shitVal > 0 then
        self.cl.shitTimer:tick()

        --self.cl.shitVal = math.max(self.cl.shitVal - dt / 2, 0)
    else
        self.cl.shitStartTime = 0
    end
end

function Toilet:cl_onShit( success )
    if self.cl.shitVal == 0 then
        self.cl.shitStartTime = sm.game.getCurrentTick()
    end

    self.cl.shitVal = self.cl.shitVal + (success and 1 or -1)
    self.cl.shitTimer:start(math.random(shitDelay.min, shitDelay.max))

    if success then
        sm.audio.play("Horn")
        sm.gui.displayAlertText("#00ff00Successful shit!", 2)
    else
        sm.audio.play("RaftShark")
        sm.gui.displayAlertText("#ff0000Unsuccessful shit! :(", 2)
    end

    if self.cl.shitVal == shitRange then
        self.cl.gui:close()
        self.network:sendToServer("sv_explode", sm.game.getCurrentTick() - self.cl.shitStartTime)
    end
end

function Toilet:client_canInteract()
    sm.gui.setInteractionText("Press", sm.gui.getKeyBinding("Jump", true), "to shit once seated")
    return self.interactable:getSeatCharacter() == nil
end

function Toilet:client_onInteract( char, state )
    if not state then return end

    self.interactable:setSeatCharacter(char)
    self.cl.gui:open()
end

function Toilet:client_onAction( action, state )
    if not state then return true end

    local char = sm.localPlayer.getPlayer().character
    if action == sm.interactable.actions.use then
        self.interactable:setSeatCharacter(char)
        self.cl.gui:close()
        self.cl.shitVal = 0
        self.cl.shitTimer:reset()
    elseif action == sm.interactable.actions.jump and self.cl.shitVal < shitRange then
        self:cl_onShit( self.cl.progress >= shitTreshold or self.cl.shitVal == 0 )
    end

    return not isAnyOf(action, { sm.interactable.actions.zoomIn, sm.interactable.actions.zoomOut })
end

function Toilet:client_onDestroy()
    self.cl.gui:close()
    self.cl.gui:destroy()
end