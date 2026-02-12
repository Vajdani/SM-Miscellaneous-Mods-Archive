local angleAxis    = sm.quat.angleAxis
local vec3         = sm.vec3.new
local vec3_up      = vec3(0,0,1)
local vec3_forward = vec3(0,1,0)
local vec3_right   = vec3(1,0,0)
local Deg180       = math.pi
local Deg90        = math.pi/2
local gunOrigin    = vec3(0, 16.5, 4) * 0.25
local yawSpeed     = 0.1
local pitchSpeed   = 0.05
local ReloadTime   = 10

local function BoolToNum(bool)
    return bool and 1 or 0
end



---@class OrbitalCannonMain : HarvestableClass
---@field sv_base Harvestable
---@field sv_gun Harvestable
---@field sv_valve_yaw Harvestable
---@field sv_valve_pitch Harvestable
---@field sv_button Harvestable
---@field cl_base Harvestable
---@field cl_gun Harvestable
---@field cl_valve_yaw Harvestable
---@field cl_valve_pitch Harvestable
---@field cl_button Harvestable
OrbitalCannonMain = class()

g_cannonCount = g_cannonCount or 0

function OrbitalCannonMain:server_onCreate()
    self.sv_base        = self.params.base
    self.sv_gun         = self.params.gun
    self.sv_valve_yaw   = self.params.valve_yaw
    self.sv_valve_pitch = self.params.valve_pitch
    self.sv_button      = self.params.button

    self.sv_yaw = 0
    self.sv_interp_yaw = 0

    self.sv_pitch = 0
    self.sv_interp_pitch = 0

    g_cannonCount = g_cannonCount + 1
    self.idx = g_cannonCount

    self.network:setClientData(self.params, 1)
end

function OrbitalCannonMain:server_onDestroy()
    g_cannonCount = g_cannonCount - 1
end

function OrbitalCannonMain:server_onFixedUpdate(dt)
    local yawInput = self.sv_valve_yaw.publicData.outputs
    self.sv_yaw = self.sv_yaw + (BoolToNum(yawInput[1]) - BoolToNum(yawInput[2])) * dt * yawSpeed

    local pitchInput = self.sv_valve_pitch.publicData.outputs
    self.sv_pitch = sm.util.clamp(self.sv_pitch + (BoolToNum(pitchInput[1]) - BoolToNum(pitchInput[2])) * dt * pitchSpeed, -0.125, 0.75)

    self.sv_interp_yaw = sm.util.lerp(self.sv_interp_yaw, self.sv_yaw, dt * 10)
    self.sv_interp_pitch = sm.util.lerp(self.sv_interp_pitch, self.sv_pitch, dt * 10)

    if (sm.game.getServerTick() + self.idx)%40 == 0 then
        self.network:setClientData({
            yaw = self.sv_yaw,
            interp_yaw = self.sv_interp_yaw,
            pitch = self.sv_pitch,
            interp_pitch = self.sv_interp_pitch
        }, 2)
    end
end


function OrbitalCannonMain:client_onCreate()
    self.cl_base = nil

    self.cl_yaw = 0
    self.cl_interp_yaw = 0

    self.cl_pitch = 0
    self.cl_interp_pitch = 0
end

function OrbitalCannonMain:client_onClientDataUpdate(data, channel)
    if channel == 1 then
        self.cl_base        = data.base
        self.cl_gun         = data.gun
        self.cl_valve_yaw   = data.valve_yaw
        self.cl_valve_pitch = data.valve_pitch
        self.cl_button      = data.button
    else --if channel == 2 then
        self.cl_yaw          = data.yaw
        self.cl_interp_yaw   = data.interp_yaw
        self.cl_pitch        = data.pitch
        self.cl_interp_pitch = data.interp_pitch

        self:ApplyRotation()
    end
end

function OrbitalCannonMain:client_onFixedUpdate(dt)
    local yawInput = self.cl_valve_yaw.clientPublicData.outputs
    self.cl_yaw = self.cl_yaw + (BoolToNum(yawInput[1]) - BoolToNum(yawInput[2])) * dt * yawSpeed

    local pitchInput = self.cl_valve_pitch.clientPublicData.outputs
    self.cl_pitch = sm.util.clamp(self.cl_pitch + (BoolToNum(pitchInput[1]) - BoolToNum(pitchInput[2])) * dt * pitchSpeed, -0.125, 0.75)
end

function OrbitalCannonMain:client_onUpdate(dt)
    self.cl_interp_yaw = sm.util.lerp(self.cl_interp_yaw, self.cl_yaw, dt * 10)
    self.cl_interp_pitch = sm.util.lerp(self.cl_interp_pitch, self.cl_pitch, dt * 10)

    self:ApplyRotation()
end


function OrbitalCannonMain:ApplyRotation()
    local rotation = self.cl_base.worldRotation * angleAxis(self.cl_interp_yaw, vec3_forward)
    local basePos = self.cl_base.worldPosition
    self.harvestable:setPosition(basePos)
    self.harvestable:setRotation(rotation)

    self.cl_gun:setPosition(basePos + rotation * gunOrigin)
    self.cl_gun:setRotation(rotation * angleAxis(self.cl_interp_pitch * Deg90, vec3_right))

    local valveRotation = rotation * angleAxis(-Deg90, vec3_forward)
    self.cl_valve_yaw:setPosition(basePos + rotation * (vec3_right * 2.5 + vec3_forward * 2 + vec3_up * 1))
    self.cl_valve_yaw:setRotation(valveRotation)

    self.cl_valve_pitch:setPosition(basePos + rotation * (vec3_right * 2.5 + vec3_forward * 2))
    self.cl_valve_pitch:setRotation(valveRotation)

    self.cl_button:setPosition(basePos + rotation * (vec3_right * 3 + vec3_forward * 2 - vec3_up))
    self.cl_button:setRotation(rotation * angleAxis(Deg180, vec3_forward))
end



---@class OrbitalCannonGun : HarvestableClass
OrbitalCannonGun = class()

function OrbitalCannonGun:server_onCreate()
    self.sv_fireTimer = sm.game.getServerTick()
end

function OrbitalCannonGun:sv_fire()
    local tick = sm.game.getServerTick()
    if tick < self.sv_fireTimer then return end

    self.sv_fireTimer = tick + 40 * ReloadTime

    sm.effect.playEffect("PropaneTank - ExplosionBig", self.harvestable.worldPosition - self.harvestable.worldRotation * vec3_up * 20)
end



---@class OrbitalCannonValve : HarvestableClass
OrbitalCannonValve = class()

local inputDirections = {
    [1] = true,
    [2] = true
}

function OrbitalCannonValve:server_onCreate()
    self.sv_parent = self.params.parent
    self.sv_actions = {
        [1] = false,
        [2] = false
    }

    self.harvestable.publicData = {
        outputs = self.sv_actions
    }
end

function OrbitalCannonValve:sv_updateInputs(inputs)
    self.sv_actions = inputs
    self.harvestable.publicData.outputs = inputs
    self.network:sendToClients("cl_updateInputs", inputs)
end


function OrbitalCannonValve:client_onCreate()
    self.cl_actions = {
        [1] = false,
        [2] = false
    }

    self.harvestable.clientPublicData = {
        outputs = self.cl_actions
    }
end

function OrbitalCannonValve:client_canInteract()
    local canInteract = self.harvestable:getSeatCharacter() == nil
    if canInteract then
        sm.gui.setInteractionText(sm.gui.getKeyBinding("Use", true), "#{INTERACTION_USE}", "")
    end

    return canInteract
end

function OrbitalCannonValve:client_onInteract(char, state)
    if not state then return end

    self.harvestable:setSeatCharacter(char)
end

function OrbitalCannonValve:client_onAction(action, state)
    if action == 0 then
        return false
    end

    if inputDirections[action] == true then
        self.cl_actions[action] = state
        self.network:sendToServer("sv_updateInputs", self.cl_actions)
    end

    if state and action == 15 then
        self.harvestable:setSeatCharacter(sm.localPlayer.getPlayer().character)
    end

    return not (action == 20 or action == 21)
end

function OrbitalCannonValve:cl_updateInputs(inputs)
    self.cl_actions = inputs
    self.harvestable.clientPublicData.outputs = inputs
end



---@class OrbitalCannonButton : HarvestableClass
OrbitalCannonButton = class()

function OrbitalCannonButton:server_onCreate()
    self.sv_parent = self.params.parent
    self.sv_gun    = self.params.gun
end

function OrbitalCannonButton:server_onProjectile()
    self:sv_onInteract()
end

function OrbitalCannonButton:sv_onInteract()
    sm.event.sendToHarvestable(self.sv_gun, "sv_fire")
end


function OrbitalCannonButton:client_canInteract()
    sm.gui.setInteractionText(sm.gui.getKeyBinding("Use", true), "#{INTERACTION_USE}", "")
    return true
end

function OrbitalCannonButton:client_onInteract(char, state)
    if not state then return end

    self.network:sendToServer("sv_onInteract")
end