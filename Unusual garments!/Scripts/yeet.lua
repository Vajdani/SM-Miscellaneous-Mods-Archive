
Ballsacker = class()

function Ballsacker:client_onCreate()
    print("fuck you")
    self.balls = sm.effect.createEffect("UI - GarmentBoxIdleCommon", self.interactable)
    self.balls:start()
end

function Ballsacker:client_onDestroy(dt)
    self.balls:stop()
    self.balls:destroy()
    self.balls = nil
end