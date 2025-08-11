Tool = class()

function Tool:client_onEquippedUpdate(lmb, rmb, f)
    if lmb == 1 or lmb == 2 then
        sm.gui.displayAlertText("hi i am pressing left click", 1)
    end

    sm.gui.setInteractionText("hold f to place")

    return not f, false
end