WideSensor = class()
WideSensor.maxChildCount = -1
WideSensor.maxParentCount = 0
WideSensor.connectionInput = sm.interactable.connectionType.none
WideSensor.connectionOutput = sm.interactable.connectionType.logic
WideSensor.colorNormal = sm.color.new("#0033ff")
WideSensor.colorHighlight = sm.color.new("#0000ff")
WideSensor.poseWeightCount = 1

WideSensor.colourOrder = {
    1, 2, 3, 4, 5,
    11, 12, 13, 14, 15,
    21, 22, 23, 24, 25,
    31, 32, 33, 34, 35,

    6, 7, 8, 9, 10,
    16, 17, 18, 19, 20,
    26, 27, 28, 29, 30,
    36, 37, 38, 39, 40
}

dofile "$SURVIVAL_DATA/Scripts/game/survival_constants.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"

function WideSensor:server_onCreate()
    self.sv = self.storage:load() or {
        sliderPos = 0,
        mode = "Button",
        sound = "Off",
        colour = "Off",
        selectedColourIndex = 1,
        selectedColour = PAINT_COLORS[1],
        angle = 90
    }

    self.network:setClientData( self.sv )
end

function WideSensor:sv_save()
    --print(self.sv)
    self.storage:save( self.sv )
    self.network:setClientData( self.sv )
end

function WideSensor:sv_onSliderChange( position )
    self.sv.sliderPos = position
    self:sv_save()
end

function WideSensor:sv_mode()
    self.sv.mode = self.sv.mode == "Button" and "Switch" or "Button"
    self:sv_save()
end

function WideSensor:sv_sound()
    self.sv.sound = self.sv.sound == "Off" and "On" or "Off"
    self:sv_save()
end

function WideSensor:sv_colour()
    self.sv.colour = self.sv.colour == "Off" and "On" or "Off"
    self:sv_save()
end

function WideSensor:sv_colourPick( button )
    self.sv.selectedColourIndex = tonumber(button:sub(10, 11))
    self.sv.selectedColour = PAINT_COLORS[self.colourOrder[self.sv.selectedColourIndex]]
    self:sv_save()
end

function WideSensor:sv_angleChange( num )
    self.sv.angle = num
    self:sv_save()
end

function WideSensor:server_onFixedUpdate()
    if self.interactable.active ~= self.cl.active then
        self.interactable.active = self.cl.active
        self.interactable.power = self.cl.active and 1 or 0
    end
end



function WideSensor:client_onCreate()
    self.cl = {}
    self.cl.gui = sm.gui.createGuiFromLayout( "$CONTENT_DATA/Gui/sensor.layout", false, {
            isHud = false,
            isInteractive = true,
            needsCursor = true,
            hidesHotbar = false,
            isOverlapped = false,
            backgroundAlpha = 0
        }
    )
    self.cl.gui:setVisible( "ContentPanel",     true    )
    self.cl.gui:setVisible( "UpgradeContainer", false   )
    self.cl.gui:setVisible( "BackgroundSensor", false   )
    self.cl.gui:setVisible( "BackgroundSensorNoUpgrade", true   )

    self.cl.gui:createHorizontalSlider( "RangeSlider", 20, 0, "cl_onSliderChange", true )

    self.cl.gui:setButtonCallback( "ModeToggle", "cl_mode" )
    self.cl.gui:setButtonCallback( "SoundToggle", "cl_sound" )
    self.cl.gui:setButtonCallback( "ColorToggle", "cl_colour" )
    self.cl.gui:setButtonCallback( "ColorHolder", "cl_colourHolder" )
    self.cl.gui:setTextAcceptedCallback( "angleInput", "cl_angleChange" )

    self.cl.gui:setText( "SubTitle", "Senses things in a wider radius")
    self.cl.gui:setText( "Name", "Wide Range Sensor")
    self.cl.gui:setIconImage( "Icon", self.shape.uuid )

    for button_id, colour_id in pairs( self.colourOrder ) do
        local base = "ColorBtn_"..button_id
        self.cl.gui:setButtonCallback( base, "cl_colourPick" )
        self.cl.gui:setColor( base.."_icon", sm.color.new("#"..PAINT_COLORS[colour_id]) )
    end

    self.cl.data = {}
    self.cl.active = false
    self.cl.colourPickerActive = false
    self.cl.switchModeTarget = nil
end

function WideSensor:client_onClientDataUpdate( data, channel )
    local index = self.cl.data.selectedColourIndex or 1
    self.cl.gui:setButtonState( "ColorBtn_"..index, false )
    self.cl.gui:setButtonState( "ColorBtn_"..data.selectedColourIndex, true )

    self.cl.data = data
    self.cl.data.selectedColour = sm.color.new("#"..data.selectedColour)

    if data.mode == "Switch" then
        self.cl.gui:setButtonState( "ModeSwitch", true )
        self.cl.gui:setButtonState( "ModeButton", false )
    else
        self.cl.gui:setButtonState( "ModeSwitch", false )
        self.cl.gui:setButtonState( "ModeButton", true )
    end

    if data.sound == "On" then
        self.cl.gui:setButtonState( "SoundOn", true )
        self.cl.gui:setButtonState( "SoundOff", false )
    else
        self.cl.gui:setButtonState( "SoundOn", false )
        self.cl.gui:setButtonState( "SoundOff", true )
    end

    self.cl.gui:setColor( "ColorHolder_icon", self.cl.data.selectedColour )
    if data.colour == "On" then
        self.cl.gui:setButtonState( "ColorOn", true )
        self.cl.gui:setButtonState( "ColorOff", false )
        self.cl.gui:setVisible( "ColorHolder", true )

    else
        self.cl.colourPickerActive = false
        self.cl.gui:setVisible( "ColorSelectPanel", self.cl.colourPickerActive )
        self.cl.gui:setButtonState( "ColorOn", false )
        self.cl.gui:setButtonState( "ColorOff", true )
        self.cl.gui:setVisible( "ColorHolder", false )
    end

    self.cl.gui:setText( "ModeToggle", self.cl.data.mode )
    self.cl.gui:setText( "SoundToggle", self:onOffColour(self.cl.data.sound) )
    self.cl.gui:setText( "ColorToggle", self:onOffColour(self.cl.data.colour) )
    self.cl.gui:setText( "angleInput", tostring(self.cl.data.angle) )
end

function WideSensor:client_onInteract( char, state )
    if not state then return end

    self.cl.gui:open()
end

function WideSensor:cl_onSliderChange( position )
    self.cl.data.sliderPos = position
    self.network:sendToServer("sv_onSliderChange", position)
end

function WideSensor:cl_mode()
    self.network:sendToServer("sv_mode")
end

function WideSensor:cl_sound()
    self.network:sendToServer("sv_sound")
end

function WideSensor:cl_colour()
    self.network:sendToServer("sv_colour")
end

function WideSensor:cl_colourHolder()
    self.cl.colourPickerActive = not self.cl.colourPickerActive
    self.cl.gui:setVisible( "ColorSelectPanel", self.cl.colourPickerActive )
end

function WideSensor:cl_colourPick( button )
    self.network:sendToServer( "sv_colourPick", button )
end

function WideSensor:cl_angleChange( editBox, text )
    local number = tonumber( text )
    self.network:sendToServer("sv_angleChange", number == nil and 90 or sm.util.clamp(number, 1, 180 --[[360]]))
end

function WideSensor:client_onFixedUpdate( dt ) --client_onUpdate( dt )
    if self.cl.gui:isActive() then
        self.cl.gui:setSliderPosition( "RangeSlider", self.cl.data.sliderPos )
    end

    local hit, result
    local multicastData = self:getMulticastData(sm.util.clamp(self.cl.data.angle, 1, 90), self.cl.data.angle, self.cl.data.sliderPos)
    for k, data in pairs( multicastData ) do
        --sm.particle.createParticle( "paint_smoke", data.startPoint )
        sm.particle.createParticle( "paint_smoke", data.endPoint )
    end

    for k, data in pairs(sm.physics.multicast(multicastData)) do
        hit, result = data[1], data[2]
        if hit == true then
            local hitThing = result:getCharacter() or result:getShape()
            if self.cl.data.colour == "Off" or hitThing:getColor() == self.cl.data.selectedColour then
                break
            end
        end
    end

    local hitThing = result:getCharacter() or result:getShape()
    if hit and (self.cl.data.colour == "Off" or hitThing ~= nil and hitThing:getColor() == self.cl.data.selectedColour --[[or type(hitThing) == "Character" and hitThing:isPlayer()]]) then
        if self.cl.data.mode == "Button" then
            self.cl.active = true
        elseif hitThing ~= self.cl.switchModeTarget then
            self.cl.switchModeTarget = hitThing
            self.cl.active = not self.cl.active
        end
    elseif self.cl.data.mode == "Button" then
        self.cl.active = false
    elseif hitThing == nil then
        self.cl.switchModeTarget = nil
    end

    local pose = self.interactable:getPoseWeight( 0 )
    if self.cl.active and pose == 0 then
        self.interactable:setPoseWeight( 0, 1 )

        if self.cl.data.sound == "On" then
            sm.audio.play("Sensor on", self.shape.worldPosition)
        end
    elseif not self.cl.active and pose == 1 then
        self.interactable:setPoseWeight( 0, 0 )

        if self.cl.data.sound == "On" then
            sm.audio.play("Sensor off", self.shape.worldPosition)
        end
    end
end

function WideSensor:client_onDestroy()
    self.cl.gui:close()
    self.cl.gui:destroy()
end

function WideSensor:getMulticastData( raycastNumber, maxAngle, range )
    local positions = {}
    local half = maxAngle/2
    local pos = self.shape.worldPosition

    local angleStep = maxAngle / raycastNumber

    for i = 0, raycastNumber do
        positions[#positions+1] = {
            type = "ray",
            startPoint = pos,                             --thanks decino and id https://www.youtube.com/watch?v=MsCqLQJ1EOc
            endPoint = pos + (self.shape.up / 4 * (range + 1)):rotate(math.rad(half-maxAngle+angleStep*i), self.shape.at),
            mask = sm.physics.filter.all
        }
    end

    --[[
    for i = 1, range + 1 do
        local fwd = self.shape.up / 4 * i
        positions[#positions+1] = {
            type = "ray",
            startPoint = pos + fwd:rotate(math.rad(-half), self.shape.at),
            endPoint = pos + fwd:rotate(math.rad(half), self.shape.at),
            mask = sm.physics.filter.all
        }
    end
    ]]

    return positions
end

function WideSensor:onOffColour( text )
    if text == "On" then
        return "#269e44"..text
    elseif text == "Off" then
        return "#9e2626"..text
    end
end