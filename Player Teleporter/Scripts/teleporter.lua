dofile("$CONTENT_d398b515-50b9-4366-869e-2757e0cc4d48/Scripts/Interface.lua")

Teleporter = class()

local meter = 2
local block = 8
local defaultPos = sm.vec3.new(0,0,0.72)

function Teleporter:server_onCreate()
	self.pos = sm.shape.getWorldPosition( self.shape )
	self.data = {}
	self.tpTrigger = nil
	self.id = self.shape:getId()
	self.help = false

	self.data = self.storage:load()
	if self.data == nil then
		self.data = {
			triggerSize = sm.vec3.one(),
			offset = sm.vec3.zero(),
			tpPos = sm.vec3.zero(),
			tpYaw = 0,
			tpVis = true,
			posVis = true,
			axisVis = false,
			idVis = false,
			unitBlock = false
		}
	else
		self:sv_createTPTrigger({ size = self.data.triggerSize, triggerPos = self.pos + self.data.offset })
		self.network:sendToClients( "cl_createTPPosEffect", self.data.tpPos )
	end

	print("Teleporter data:")
	print(self.data)
	print(" ")

    sm.hook.createHook(self)
end

function Teleporter.server_onHooked(self)
    --[[sm.hook.game.addFunctionGraceful("server_setTP", function(self, params, player)
        -- calls the clear function of the world
        sm.event.sendToWorld(player.character:getWorld(), "sv_e_clear")
    end)

    sm.hook.game.addServerCommandGraceful("/setTP", {}, "#b0a9a9Set teleport position, args:#ff9d00 teleporter ID; x; y; z (the x/y/z values default to the player position)")
    sm.hook.game.addServerCommandGraceful("/setS", {}, "#b0a9a9Set teleport area scale, args:#ff9d00 teleporter ID; x; y; z")
    sm.hook.game.addServerCommandGraceful("/setO", {}, "#b0a9a9Set teleport area offset, args:#ff9d00 teleporter ID; x; y; z")
    sm.hook.game.addServerCommandGraceful("/create", {}, "#b0a9a9Create teleporter, args:#ff9d00 teleporter ID")
    sm.hook.game.addServerCommandGraceful("/reset", {}, "#b0a9a9Resets teleporter, args:#ff9d00 teleporter ID")
    sm.hook.game.addServerCommandGraceful("/unit", {}, "#b0a9a9Toggles unit type, args:#ff9d00 teleporter ID")
    sm.hook.game.addServerCommandGraceful("/frame", {}, "#b0a9a9Toggles teleport area effect, args:#ff9d00 teleporter ID")
    sm.hook.game.addServerCommandGraceful("/arrow", {}, "#b0a9a9Toggles teleport position effect, args:#ff9d00 teleporter ID")
    sm.hook.game.addServerCommandGraceful("/axis", {}, "#b0a9a9Toggles axis visualization effect, args:#ff9d00 teleporter ID")

    sm.gui.chatMessage("#ff9d00/setTP #b0a9a9is now available")
    sm.gui.chatMessage("#ff9d00/setS #b0a9a9is now available")
    sm.gui.chatMessage("#ff9d00/setO #b0a9a9is now available")
    sm.gui.chatMessage("#ff9d00/create #b0a9a9is now available")
    sm.gui.chatMessage("#ff9d00/reset #b0a9a9is now available")
    sm.gui.chatMessage("#ff9d00/unit #b0a9a9is now available")
    sm.gui.chatMessage("#ff9d00/frame #b0a9a9is now available")
    sm.gui.chatMessage("#ff9d00/arrow #b0a9a9is now available")
    sm.gui.chatMessage("#ff9d00/axis #b0a9a9is now available")
	]]
end

--Thanks SM Servers mod of the math, very cool
function createColour()
	local r = math.random()
	local g = math.random()
	local b = math.random()
	
	colour = sm.color.new( r, g, b )
	return colour
end

function sigmoid(x, a, b)
	return 1/(1 + math.exp(-2 * a * (x + b)))
end

function colourToHashtag(color)
	col = sm.color.new(
			sigmoid(color.r, 5, -0.25),
			sigmoid(color.g, 5, -0.25),
			sigmoid(color.b, 5, -0.25))
	return "#"..string.sub(tostring(col), 0, 6)
end

function Teleporter:client_onCreate()
	self.gui = sm.gui.createGuiFromLayout( "$CONTENT_e43a45f0-6262-421a-a563-18e4251a8708/Gui/tpConfig21.layout" )

	--normal buttons
	self.gui:setButtonCallback( "Create", "cl_btn_Create" )
	self.gui:setButtonCallback( "Reset", "cl_btn_Reset" )
	self.gui:setButtonCallback( "Help", "cl_btn_Help" )
	self.gui:setButtonCallback( "resetOffset", "cl_btn_resetOffset" )
	self.gui:setButtonCallback( "resetScale", "cl_btn_resetScale" )

	self.gui:setButtonCallback( "tpVis", "cl_btn_tpVis" )
	self.gui:setButtonCallback( "posVis", "cl_btn_posVis" )
	self.gui:setButtonCallback( "axisVis", "cl_btn_axisVis" )
	self.gui:setButtonCallback( "toggleUnit", "cl_btn_toggleUnit" )
	self.gui:setButtonCallback( "idVis", "cl_btn_toggleID" )

	--scale
	--increase
	self.gui:setButtonCallback( "scaleXInc", "cl_scale_XInc" )
	self.gui:setButtonCallback( "scaleYInc", "cl_scale_YInc" )
	self.gui:setButtonCallback( "scaleZInc", "cl_scale_ZInc" )

	--decrease
	self.gui:setButtonCallback( "scaleXDec", "cl_scale_XDec" )
	self.gui:setButtonCallback( "scaleYDec", "cl_scale_YDec" )
	self.gui:setButtonCallback( "scaleZDec", "cl_scale_ZDec" )

	--offset
	--increase
	self.gui:setButtonCallback( "offsetXInc", "cl_offset_XInc" )
	self.gui:setButtonCallback( "offsetYInc", "cl_offset_YInc" )
	self.gui:setButtonCallback( "offsetZInc", "cl_offset_ZInc" )

	--decrease
	self.gui:setButtonCallback( "offsetXDec", "cl_offset_XDec" )
	self.gui:setButtonCallback( "offsetYDec", "cl_offset_YDec" )
	self.gui:setButtonCallback( "offsetZDec", "cl_offset_ZDec" )

	self.gui:setVisible( "helpWindow", false )
	self.gui:setVisible( "helpWindow2", false )

	--Number above the part
	self.idGUI = sm.gui.createNameTagGui()
	self.idGUI:setWorldPosition( self.shape.worldPosition + sm.vec3.new( 0, 0, 0.72 ) )
	self.idGUI:setRequireLineOfSight( false )
	self.idGUI:setMaxRenderDistance( 1000 )

	local colour = createColour()
	self.idGUI:setText("Text", colourToHashtag(colour)..tostring(self.id))
	if self.data.idVis then
		self.idGUI:open()
	end

	--FX
	self.hologramEffects = {}
	self.hologramEffects[1] = sm.effect.createEffect( "Teleporter - StripMarkerX" )
	self.hologramEffects[2] = sm.effect.createEffect( "Teleporter - StripMarkerY" )
	self.hologramEffects[3] = sm.effect.createEffect( "Teleporter - StripMarkerZ" )

	self.minColor = sm.color.new( 0.0, 0.0, 0.8, 0.0 )
	self.maxColor = sm.color.new( 0.0, 0.6, 1.0, 8.0 )

	self.tpPosEffect = sm.effect.createEffect( "Chest - Arrow" )

	self.axisEffect = sm.effect.createEffect( "Axis - Marker" )
	self.axisEffect:setPosition( self.pos )
	self.axisEffect:setRotation( sm.quat.new( 0.707, 0, 0, 0.707 ) )
end

--normal buttons
function Teleporter:cl_btn_Create()
	if sm.exists(self.tpTrigger) then
		self.network:sendToServer("sv_destroyTPTrigger")
	end
	self.network:sendToServer("sv_createTPTrigger", { size = self.data.triggerSize, triggerPos = self.pos })
end

function Teleporter:cl_btn_Reset()
	self.data = {
		triggerSize = sm.vec3.one(),
		offset = sm.vec3.zero(),
		tpPos = sm.vec3.zero(),
		tpYaw = 0,
		tpVis = true,
		posVis = true,
		idVis = false,
		unitBlock = false
	}
	self.tpTrigger = nil
	self.network:sendToServer("sv_displayMsg", "#b0a9a9Teleporter data of shape#ff9d00 "..self.id.." #b0a9a9has been reset!")
end

function Teleporter:cl_btn_Help()
	self.help = not self.help
	self.gui:setVisible( "helpWindow", self.help )
	self.gui:setVisible( "helpWindow2", self.help )
end

function Teleporter:cl_btn_resetOffset()
	self.data.offset = sm.vec3.zero()
	self.network:sendToServer("sv_triggerSetOffset", self.data.offset)
end

function Teleporter:cl_btn_resetScale()
	self.data.triggerSize = sm.vec3.one()
	self.network:sendToServer("sv_triggerSetSize", self.data.triggerSize)
end

function Teleporter:cl_btn_tpVis()
	self.data.tpVis = not self.data.tpVis
end

function Teleporter:cl_btn_posVis()
	self.data.posVis = not self.data.posVis
end

function Teleporter:cl_btn_axisVis()
	self.data.axisVis = not self.data.axisVis
end

function Teleporter:cl_btn_toggleUnit()
	self.data.unitBlock = not self.data.unitBlock
	
	if sm.exists(self.tpTrigger) then
		self.network:sendToServer("sv_triggerSetSize", self.data.triggerSize)
		self.network:sendToServer("sv_triggerSetOffset", self.data.offset)
	end
	self.network:sendToServer("sv_displayMsg", "#b0a9a9Adjusted the size of shape#ff9d00 "..self.id.."#b0a9a9's the teleporter to:#ff9d00 "..tostring(self.data.triggerSize))
	self.network:sendToServer("sv_correctHologram")
end

function Teleporter:cl_btn_toggleID()
	self.data.idVis = not self.data.idVis
end

--scale
--increase
function Teleporter:cl_scale_XInc()
	self.network:sendToServer("sv_triggerSetSize", self.data.triggerSize + sm.vec3.new(1,0,0))
end

function Teleporter:cl_scale_YInc()
	self.network:sendToServer("sv_triggerSetSize", self.data.triggerSize + sm.vec3.new(0,1,0))
end

function Teleporter:cl_scale_ZInc()
	self.network:sendToServer("sv_triggerSetSize", self.data.triggerSize + sm.vec3.new(0,0,1))
end

--decrease
function Teleporter:cl_scale_XDec()
	if self.data.triggerSize.x > 1 then
		self.network:sendToServer("sv_triggerSetSize", self.data.triggerSize - sm.vec3.new(1,0,0))
	end
end

function Teleporter:cl_scale_YDec()
	if self.data.triggerSize.y > 1 then
		self.network:sendToServer("sv_triggerSetSize", self.data.triggerSize - sm.vec3.new(0,1,0))
	end
end

function Teleporter:cl_scale_ZDec()
	if self.data.triggerSize.z > 1 then
		self.network:sendToServer("sv_triggerSetSize", self.data.triggerSize - sm.vec3.new(0,0,1))
	end
end

--offset
--increase
function Teleporter:cl_offset_XInc()
	self.network:sendToServer("sv_triggerSetOffset", self.data.offset + sm.vec3.new(1,0,0))
end

function Teleporter:cl_offset_YInc()
	self.network:sendToServer("sv_triggerSetOffset", self.data.offset + sm.vec3.new(0,1,0))
end

function Teleporter:cl_offset_ZInc()
	self.network:sendToServer("sv_triggerSetOffset", self.data.offset + sm.vec3.new(0,0,1))
end

--decrease
function Teleporter:cl_offset_XDec()
	self.network:sendToServer("sv_triggerSetOffset", self.data.offset - sm.vec3.new(1,0,0))
end

function Teleporter:cl_offset_YDec()
	self.network:sendToServer("sv_triggerSetOffset", self.data.offset - sm.vec3.new(0,1,0))
end

function Teleporter:cl_offset_ZDec()
	self.network:sendToServer("sv_triggerSetOffset", self.data.offset - sm.vec3.new(0,0,1))
end

--other functions
function checkPos( area, areaPos, pos )
	--dumb
	--[[local areaTable = {
		area.x,
		area.y,
		area.z
	}
	table.sort(areaTable)
	local highest = areaTable[3]
	
	print(highest)
	print((pos - areaPos):length())
	
	if (pos - areaPos):length() + 1 < highest then
		--print(false)
		return false
	else
		--print(true)
		return true
	end]]

	return true
end

function Teleporter:sv_triggerSetSize( size )
	local valid = checkPos(size, self.pos + self.data.offset, self.data.tpPos)
	if sm.exists(self.tpTrigger) and valid then
		self.data.triggerSize = size
		if self.data.unitBlock then
			size = size / block
		else
			size = size / meter
		end
		
		self:sv_saveData()
		self.tpTrigger:setSize( size )
		self.network:sendToClients("cl_displayMsg", "#b0a9a9Resized teleporter of shape #ff9d00 "..self.id.." #b0a9a9to:#ff9d00 "..tostring(self.data.triggerSize))
		self.network:sendToClients("cl_correctHologram")
	elseif not valid then
		self.network:sendToClients("cl_displayMsg", "#b0a9a9Couldn't resize teleporter of shape #ff9d00 "..self.id.."#b0a9a9, the teleport position is inside of the teleport area.")
	end
end

function Teleporter:sv_triggerSetOffset( offset )
	local valid = checkPos(self.data.triggerSize, self.pos + offset, self.data.tpPos)
	if sm.exists(self.tpTrigger) and valid then
		self.data.offset = offset
		if self.data.unitBlock then
			offset = offset / block
		else
			offset = offset / meter
		end
		
		self:sv_saveData()
		self.tpTrigger:setWorldPosition( self.pos + offset )
		self.network:sendToClients("cl_displayMsg", "#b0a9a9Moved teleporter of shape#ff9d00 "..self.id.." #b0a9a9to:#ff9d00 "..tostring(self.pos + offset))
		self.network:sendToClients("cl_correctHologram")
	elseif not valid then
		self.network:sendToClients("cl_displayMsg", "#b0a9a9Couldn't move teleporter of shape #ff9d00 "..self.id.."#b0a9a9, the teleport position is inside of the teleport area.")
	end
end

function Teleporter:sv_displayMsg( msg )
	self.network:sendToClients("cl_displayMsg", msg)
end

function Teleporter:cl_displayMsg( msg )
	sm.gui.displayAlertText(msg, 2.5)
end

function Teleporter:sv_saveData()
	self.storage:save( self.data )
	--[[print("Saved teleporter data:")
	print(self.data)
	print(" ")]]
end

function Teleporter:sv_correctHologram()
	self.network:sendToClients("cl_correctHologram")
end

function Teleporter:cl_correctHologram()
	for i = 1, 3 do
		if self.data.unitBlock then
			self.hologramEffects[i]:setScale( (self.data.triggerSize / block) * 0.5)
			self.hologramEffects[i]:setPosition( self.pos + (self.data.offset / block) )
		else
			self.hologramEffects[i]:setScale( (self.data.triggerSize / meter) * 0.5)
			self.hologramEffects[i]:setPosition( self.pos + (self.data.offset / meter) )
		end
	end
end

function Teleporter:client_onUpdate()	
	--Display unit mode
	if not self.data.unitBlock then
		self.gui:setText( "toggleUnit", "Unit type: #ff9d00meters" )
	else
		self.gui:setText( "toggleUnit", "Unit type: #ff9d00blocks" )
	end

	--Display scale
	self.gui:setText( "scaleX", "#ff9d00"..tostring( ("%.1f"):format(self.data.triggerSize.x) ) )
	self.gui:setText( "scaleY", "#ff9d00"..tostring( ("%.1f"):format(self.data.triggerSize.y) ) )
	self.gui:setText( "scaleZ", "#ff9d00"..tostring( ("%.1f"):format(self.data.triggerSize.z) ) )
	
	--Display offset
	local offsetDisplay = self.data.offset
	if self.data.unitBlock then
		offsetDisplay = offsetDisplay/2
	end
	self.gui:setText( "offsetX", "#ff9d00"..tostring( ("%.1f"):format(offsetDisplay.x) ) )
	self.gui:setText( "offsetY", "#ff9d00"..tostring( ("%.1f"):format(offsetDisplay.y) ) )
	self.gui:setText( "offsetZ", "#ff9d00"..tostring( ("%.1f"):format(offsetDisplay.z) ) )
	
	--Manage effects and text GUI
	if self.tpTrigger ~= nil and not self.hologramEffects[1]:isPlaying() and self.data.tpVis then
		for i = 1, 3 do
			self.hologramEffects[i]:start()
		end
	elseif self.tpTrigger == nil and self.hologramEffects[1]:isPlaying() or not self.data.tpVis then
		for i = 1, 3 do
			self.hologramEffects[i]:stopImmediate()
		end
	end
	
	for i = 1, 3 do
		self.hologramEffects[i]:setParameter( "minColor", self.minColor )
		self.hologramEffects[i]:setParameter( "maxColor", self.maxColor )
	end
	
	if self.data.tpPos ~= sm.vec3.zero() and not self.tpPosEffect:isPlaying() and self.data.posVis then
		self.tpPosEffect:start()
	elseif self.data.tpPos == sm.vec3.zero() and self.tpPosEffect:isPlaying() or not self.data.posVis then
		self.tpPosEffect:stopImmediate()
	end
	
	if self.data.axisVis then
		--If it doesnt get started every frame, it will disappear after a few seconds
		self.axisEffect:start()
	else
		self.axisEffect:stopImmediate()
	end
	
	if self.data.idVis and not self.idGUI:isActive() then
		self.idGUI:open()
	elseif not self.data.idVis and self.idGUI:isActive() then
		self.idGUI:close()
	end
end

function Teleporter:client_onInteract( char, lookAt )
	if lookAt then
		self.gui:open()
		if self.data.tpPos == sm.vec3.zero() then
			self.data.tpPos = defaultPos
			self.network:sendToServer("sv_displayMsg", "#b0a9a9Teleport position defaulted to:#ff9d00 "..tostring(self.data.tpPos))
			self.network:sendToServer("sv_createTPPosEffect", self.data.tpPos)
			self.network:sendToServer("sv_createTPTrigger", { size = self.data.triggerSize, triggerPos = self.pos })
		end
	end
end

function Teleporter:sv_createTPTrigger( args )
	print(args)
	if args.size == nil or args.size == sm.vec3.zero() then
		args.size = sm.vec3.one()
	end

	local size = args.size
	if self.data.unitBlock then
		size = size / block
	else
		size = size / meter
	end

	if checkPos( args.size, args.triggerPos, self.data.tpPos ) then
		self.tpTrigger = sm.areaTrigger.createBox( size, args.triggerPos, sm.quat.identity(), sm.areaTrigger.filter.character )
		self.tpTrigger:bindOnEnter( "sv_teleportCharacter" )
		self:sv_correctHologram()

		self:sv_saveData()
		self.network:sendToClients( "cl_displayMsg", "#b0a9a9Teleporter for shape#ff9d00 "..self.id.." #b0a9a9created!" )
		print( "Created teleporter for shape "..self.id )
	end
end

function Teleporter:sv_destroyTPTrigger()
	--self.data.tpPos = sm.vec3.zero()
	sm.areaTrigger.destroy(self.tpTrigger)
	self.tpTrigger = nil
	self.data.offset = sm.vec3.zero()
	self.data.triggerSize = sm.vec3.one()

	self:sv_saveData()
	print( "Destroyed teleporter of shape "..self.id )
	self.network:sendToClients( "cl_displayMsg", "#b0a9a9Teleporter of shape#ff9d00 "..self.id.." #b0a9a9destroyed!" )
end

function Teleporter:sv_teleportCharacter( trigger, result )
	for _, character in pairs(result) do
		local newCharacter = sm.character.createCharacter( character:getPlayer(), character:getWorld(), self.data.tpPos, self.data.tpYaw, 0, character )
		character:getPlayer():setCharacter( newCharacter )
		self.network:sendToClient( newCharacter:getPlayer(), "cl_displayMsg", "#b0a9a9You've been teleported!" )
	end
end

function Teleporter:server_onProjectile( hitPos, hitTime, hitVelocity, projectileName, attacker, damage )
	if projectileName == "smallpotato" and sm.exists(self.tpTrigger) then
		self:sv_destroyTPTrigger()
	elseif projectileName ~= "smallpotato" then
		if self.data.tpPos ~= sm.vec3.zero() and self.tpTrigger == nil then
			self:sv_createTPTrigger({ size = self.data.triggerSize, triggerPos = self.pos + self.data.offset })
			return
		end
		
		local char = attacker:getCharacter()
		local charDir = char:getDirection()
		self.data.tpPos = char:getWorldPosition()
		self.data.tpYaw = math.atan2(charDir.y,charDir.x)
		
		self.network:sendToClient( attacker, "cl_displayMsg", "#b0a9a9Teleport postion has been set!#ff9d00 "..tostring(self.data.tpPos) )
		self.network:sendToClients( "cl_createTPPosEffect", self.data.tpPos )
	end
end

function Teleporter:sv_createTPPosEffect( pos )
	self.network:sendToClients("cl_createTPPosEffect", pos)
end

function Teleporter:cl_createTPPosEffect( pos )
	if self.tpPosEffect:isPlaying() then
		self.tpPosEffect:stopImmediate()
	end

	self.tpPosEffect:setPosition( sm.vec3.new(pos.x, pos.y, pos.z + 1.5) )
	self.tpPosEffect:start()
end

function Teleporter:server_onDestroy()
	if self.tpTrigger ~= nil then
		print( "Destroyed teleporter shape "..self.id )
		sm.areaTrigger.destroy(self.tpTrigger)
	end
end

function Teleporter:client_onDestroy()
	if self.gui then
		self.gui:close()
	end

	if self.idGUI then
		self.idGUI:close()
	end
	
	for i = 1, 3 do
		self.hologramEffects[i]:stopImmediate()
	end
	self.tpPosEffect:stopImmediate()
	self.axisEffect:stopImmediate()
	
	self.gui:destroy()
	self.idGUI:destroy()
end