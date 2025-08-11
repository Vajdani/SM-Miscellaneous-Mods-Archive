MyTool = class()

function MyTool:client_onCreate()
    print("tool has been created on the client")
end

function MyTool:client_onEquippedUpdate(lmb, rmb, f)
    if lmb == 1 or lmb == 2 then
        sm.gui.setInteractionText("I am holding left click")
    end

    if rmb == 1 or rmb == 2 then
        sm.gui.setInteractionText("I am holding right click")
    end

    if f then
        sm.gui.setInteractionText("I am holding f")
    end

    return true, true
end