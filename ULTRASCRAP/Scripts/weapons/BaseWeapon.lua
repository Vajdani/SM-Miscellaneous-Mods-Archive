BaseWeapon = class()
BaseWeapon.armStats = {
    feedbacker = {
        cooldown = 40
    },
    knuckleblaster = {
        cooldown = 60
    }
}
g_weaponColours = {
    sm.color.new(0,0,1),
    sm.color.new(0,1,0),
    sm.color.new(1,0,0),
    sm.color.new(1,1,0),
}

dofile "$CONTENT_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"

function BaseWeapon:init( weapon, class )
    self.base_renderables = class.renderables
    self.base_renderablesTp = class.renderablesTp
    self.base_renderablesFp = class.renderablesFp
    self.cl.modIndex = 1
    self.isLocal = self.tool:isLocal()

    if not self.isLocal then return end

    g_weapons[weapon] = self.tool
	self.cl.data = g_userData.weapons[weapon]
    self.cl.weapon = weapon
    self.cl.lmb = 0
    self.cl.rmb = 0

    self.punchHoldTimer = Timer()
    self.punchHoldTimer:start( self.armStats.feedbacker.cooldown )
    self.punchHoldTimer.count = self.punchHoldTimer.ticks
end

function BaseWeapon:sv_onModSwap( index )
    self.network:sendToClients("cl_onModSwap", index)
end

function BaseWeapon:cl_onModSwap( index )
    self.cl.modIndex = index

    local colour = g_weaponColours[index]
    self.tool:setFpColor(colour)
    self.tool:setTpColor(colour)

    sm.audio.play( "PotatoRifle - Equip", self.tool:getPosition() )
    setTpAnimation( self.tpAnimations, "pickup", 0.2 )
    if self.tool:isLocal() then
        --sm.camera.setShake( 0.05 )
        setFpAnimation( self.fpAnimations, "equip", 0.001 )
    end
end

function BaseWeapon:modSwap()
    local nextIndex = self.cl.modIndex < GetLength(self.cl.data.mods) and self.cl.modIndex + 1 or 1
    local modName, nextMod = GetValueByIndex(self.cl.data.mods, nextIndex)

    if nextMod.owned and nextMod.equipped then
        self.network:sendToServer("sv_onModSwap", nextIndex)
    end
end

function BaseWeapon:onEquip()
    local currentRenderablesTp = {}
    local currentRenderablesFp = {}
    local renderables = self.base_renderables[self.cl.modIndex]

    for k,v in pairs( self.base_renderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
    for k,v in pairs( self.base_renderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
    for k,v in pairs( renderables ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
    for k,v in pairs( renderables ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
    self.tool:setTpRenderables( currentRenderablesTp )
    if self.tool:isLocal() then
        self.tool:setFpRenderables( currentRenderablesFp )
    end

    self:loadAnimations()

    setTpAnimation( self.tpAnimations, "pickup", 0.0001 )
	if self.isLocal then
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )
	end

    local colour = g_weaponColours[self.cl.modIndex]
    self.tool:setFpColor(colour)
    self.tool:setTpColor(colour)
end

function BaseWeapon:onEquipped( lmb, rmb, f )
    self.cl.lmb = lmb
    self.cl.rmb = rmb

    self.punchHoldTimer:tick()
    if f and self.punchHoldTimer:done() then
        print("punch")
        self.punchHoldTimer:reset()
    end
end