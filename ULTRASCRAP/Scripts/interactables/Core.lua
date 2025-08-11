---@class Core : ShapeClass
Core = class()

function Core:server_onCreate()
    self.id = #g_cores + 1
    g_cores[self.id] = self.shape
end

function Core:server_onCollision()
    self:sv_detonate()
end

function Core:sv_detonate( factor )
    local multiplier = (1 + (factor or 0) / 2)
    sm.physics.explode( self.shape.worldPosition, 4 * multiplier, 5 * multiplier, 7 * multiplier, 75 * multiplier, "PropaneTank - ExplosionSmall", self.shape )
    self.shape:destroyShape()
    g_cores[self.id] = nil
end