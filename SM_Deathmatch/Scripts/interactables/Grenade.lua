---@class Grenade : ShapeClass
Grenade = class()
Grenade.lifeTime = 6 * 40

function Grenade:server_onCreate()
    local public = self.interactable:getPublicData()
    self.spawnTick = public.spawnTick or sm.game.getServerTick()
    public.spawnTick = self.spawnTick

    self.canExplodeOnCharacterHit = true
end

function Grenade:server_onFixedUpdate()
    if sm.game.getServerTick() - self.spawnTick >= self.lifeTime then
        self:sv_explode()
    end
end

function Grenade:server_onCollision( other )
    if other == self.interactable:getPublicData().owner or not self.canExplodeOnCharacterHit then return end

    if type(other) ~= "Character" then
        self.canExplodeOnCharacterHit = false
        return
    end

    self:sv_explode()
end

function Grenade:sv_explode()
    sm.physics.explode( self.shape.worldPosition, 5, 5, 7, 25, "PropaneTank - ExplosionSmall", self.shape )
    self.shape:destroyShape( 0 )
end

function Grenade:sv_onPickup( tool )
    sm.event.sendToTool(tool, "sv_onPickup")

    self.shape:destroyShape( 0 )
end



function Grenade:client_onInteract( char, state )
    if not state then return end

    self.network:sendToServer("sv_onPickup", g_grenadeTool)
end