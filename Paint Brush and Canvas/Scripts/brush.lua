dofile "$CONTENT_DATA/Scripts/drawUtils.lua"
local drawPointUUID = sm.uuid.new("55095c0a-c77d-47e4-a971-ffb7cc16bc34")

Line_draw = class()
local vec3_up = sm.vec3.new(0, 0, 1)
function Line_draw:init( thickness, colour )
    self.effect = sm.effect.createEffect("ShapeRenderable")
    self.effect:setParameter("uuid", drawPointUUID)
    self.effect:setParameter("color", colour)
    self.effect:setScale( sm.vec3.one() * thickness )

    self.thickness = thickness
end


---@param startPos Vec3
---@param endPos Vec3
function Line_draw:update( startPos, endPos, scaleMult, up )
    local delta = endPos - startPos
    local length = delta:length()

    if length <= 0.01 then
        self.effect:stop()
        return
    end

    local rot = BetterGetRotation(delta, up or vec3_up)
    local distance = sm.vec3.new(self.thickness, self.thickness * (scaleMult or 1), length)

    self.effect:setPosition(startPos + delta * 0.5)
    self.effect:setScale(distance)
    self.effect:setRotation(rot)

    if not self.effect:isPlaying() then
        self.effect:start()
    end
end

function Line_draw:updateLineModel( uuid )
	self.effect:stop()
	self.effect:setParameter("uuid", uuid)
	self.effect:start()
end



dofile "$GAME_DATA/Scripts/game/AnimationUtil.lua"
dofile "$SURVIVAL_DATA/Scripts/util.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_harvestable.lua"
dofile "$SURVIVAL_DATA/Scripts/game/survival_shapes.lua"
dofile "$SURVIVAL_DATA/Scripts/game/util/Timer.lua"
---@class Timer
---@field count number
---@field ticks number
---@field start function 
---@field stop function 
---@field reset function 
---@field tick function 
---@field done function 


---@class Brush : ToolClass
---@field tpAnimations table
---@field fpAnimations table
---@field blendTime number
---@field drawPointLine table
---@field isLocal boolean
---@field gui GuiInterface
---@field colour_current Color
---@field colour_old Color
---@field visualization Effect
---@field panelHideTimer Timer
Brush = class()

local renderables =   {
	--"$GAME_DATA/Character/Char_Tools/Char_painttool/char_painttool.rend"
	"$CONTENT_DATA/Tools/char_paint_brush.rend"
}
local renderablesTp = {
	"$GAME_DATA/Character/Char_Male/Animations/char_male_tp_painttool.rend",
	"$GAME_DATA/Character/Char_Tools/Char_painttool/char_painttool_tp_animlist.rend"}
local renderablesFp = {
	"$GAME_DATA/Character/Char_Tools/Char_painttool/char_painttool_fp_animlist.rend"
}

local canvasUUID = sm.uuid.new("0be11a4f-3161-4964-a874-f0fdd1e30b65")
local creationCanvasUUID = sm.uuid.new("0646746e-e5a4-446a-b33b-800b8820b035")
local drawPointColour = sm.color.new("#00ff00")
local scale = sm.vec3.one() / 6
local shapes = {
	"Square",
	"Circle",
	"Hollow Square",
	"Hollow Circle",
	"Star",
	"Arrow"
}
local shapeNameToUUID = {
	Square = 				drawPointUUID,
	Circle = 				sm.uuid.new("50f2679a-0e2a-4aa6-9587-f583def9e384"),
	["Hollow Square"] = 	sm.uuid.new("cea640af-affe-4245-9a1d-38a292c18479"),
	["Hollow Circle"] = 	sm.uuid.new("fa7c3710-30bb-40ba-b787-8e0c76036d2e"),
	Star = 					sm.uuid.new("d72dcec6-ced0-4875-8c41-fbc47d6b7778"),
	Arrow = 				sm.uuid.new("6f38814a-955d-44a8-bceb-93d522277ca2")
}
local vec3_zero = sm.vec3.zero()
local sliderLength = 100
local size_quarter = 0.25
local size_eigthth = 0.125
local visSizeMult = size_eigthth * size_quarter

sm.tool.preloadRenderables( renderables )
sm.tool.preloadRenderables( renderablesTp )
sm.tool.preloadRenderables( renderablesFp )


function Brush.client_onCreate( self )
	self:cl_loadAnimations()

	self.isLocal = self.tool:isLocal()

	local defaultColour = sm.color.new(PAINT_COLORS[1])
	self.colour_current = defaultColour
	self.colour_old = defaultColour
	self.colour_transition = 0

	if not self.isLocal then return end

	self.shouldRegisterF = true
	self.drawPoint = nil
	self.drawPointEffect = nil
	self.canvas = nil
	self.drawPointLine = Line_draw()
	self.drawPointLine:init( size_eigthth, drawPointColour )

	self.colour_id = 1
	self.sizeX = 1
	self.sizeY = 1
	self.shapeToDraw = shapeNameToUUID["Square"]
	self.shapeRot = 0
	self.panelHideTimer = Timer()
	self.panelHideTimer:start( 20 )
	self.panelHideTimer.count = self.panelHideTimer.ticks

	self.visualization = sm.effect.createEffect("ShapeRenderable")
	self.visualization:setParameter("uuid", self.shapeToDraw)
	self.visualization:setParameter("visualization", true)
	self.visualization:setScale(sm.vec3.one() * visSizeMult)

	self.gui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/draw.layout")
	for button_id, colour in pairs( PAINT_COLORS ) do
        local base = "ColorBtn_"..button_id
        self.gui:setButtonCallback( base, "cl_colourPick" )
        self.gui:setColor( base.."_icon", sm.color.new(colour) )
    end

	self.gui:setButtonState("ColorBtn_"..self.colour_id, true)
	self.gui:setOnCloseCallback("cl_onGuiClosed")
	self.gui:createHorizontalSlider( "slider_sizeX", sliderLength, 0, "cl_slider_sizeX", false )
	self.gui:createHorizontalSlider( "slider_sizeY", sliderLength, 0, "cl_slider_sizeY", false )
	self.gui:createDropDown( "dropdown_shape", "cl_dropdown_shape", shapes )
	self.gui:createHorizontalSlider( "slider_rotation", 361, 0, "cl_slider_rotation", false )
	self.gui:setText("textbox_rotation", "Shape Rotation: "..self.shapeRot.."°")
	self.gui:setMeshPreview( "brushPreview", self.shapeToDraw )
	self.gui:setText("textbox_sizeX", "X: "..tostring(self.sizeX))
	self.gui:setText("textbox_sizeY", "Y: "..tostring(self.sizeY))
end

function Brush:client_onDestroy()
	if not self.isLocal then return end

	if self.drawPointEffect then
		self.drawPointEffect:stopImmediate()
		self.drawPointEffect:destroy()
	end

	self.drawPointLine.effect:stopImmediate()
	self.drawPointLine.effect:destroy()
	self.visualization:destroy()
end

-- #region cl gui
function Brush:cl_onGuiOpen()
	if self.isLocal then
		setFpAnimation( self.fpAnimations, "colourpick_idle", 0.25 )
	end
	setTpAnimation( self.tpAnimations, "colourpick_idle", 5 )
end

function Brush:cl_onGuiClosed()
	self.network:sendToServer("sv_onGuiClosed")
end

function Brush:cl_n_onGuiClosed()
	sm.audio.play("Blueprint - Close", self.tool:getOwner().character.worldPosition)

	if self.isLocal then
		setFpAnimation( self.fpAnimations, "colourpick", 0.15 )
	end
	setTpAnimation( self.tpAnimations, "colourpick", 10.0 )
end

function Brush:cl_updateToolColour( index )
	self.colour_old = self.colour_current
	self.colour_current = sm.color.new(PAINT_COLORS[index])
	self.colour_transition = 0
end

function Brush:cl_colourPick( button )
	self.gui:setButtonState("ColorBtn_"..self.colour_id, false)
	self.colour_id = tonumber(button:sub(10, 11))
	self.gui:setButtonState("ColorBtn_"..self.colour_id, true)
	sm.audio.play("PaintTool - ColorPick")
	self.gui:setColor("brushPreview", sm.color.new(PAINT_COLORS[self.colour_id]))

	--self.gui:close()
	self.network:sendToServer("sv_updateToolColour", self.colour_id)
end

function Brush:cl_slider_sizeX( position )
	self.sizeX = position + 1
	self.visualization:setScale(sm.vec3.new(0.125, self.sizeY * visSizeMult, self.sizeX * visSizeMult))
	self.gui:setText("textbox_sizeX", "X: "..tostring(self.sizeX))
	sm.audio.play("SequenceController change rotation")
end

function Brush:cl_slider_sizeY( position )
	self.sizeY = position + 1
	self.visualization:setScale(sm.vec3.new(0.125, self.sizeY * visSizeMult, self.sizeX * visSizeMult))
	self.gui:setText("textbox_sizeY", "Y: "..tostring(self.sizeY))
	sm.audio.play("SequenceController change rotation")
end

function Brush:cl_dropdown_shape( option )
	self.shapeToDraw = shapeNameToUUID[option]
	self.drawPointLine:updateLineModel(self.shapeToDraw)

	self.visualization:stop()
	self.visualization:setParameter("uuid", self.shapeToDraw)
	self.visualization:start()

	self.gui:setMeshPreview( "brushPreview", self.shapeToDraw )

	sm.audio.play("Blueprint - Open")
end

function Brush:cl_slider_rotation( position )
	self.shapeRot = position
	self.gui:setText("textbox_rotation", "Shape Rotation: "..self.shapeRot.."°")
	sm.audio.play("SequenceController change rotation")

	self.panelHideTimer:reset()
	self.gui:setVisible("panel_colour", false)
	self.gui:setVisible("panel_size", false)
	self.gui:setVisible("panel_preview", false)
end
-- #endregion


-- #region
function Brush:sv_onGuiClosed()
	self.network:sendToClients( "cl_n_onGuiClosed" )
end

function Brush:sv_updateToolColour( index )
	self.network:sendToClients("cl_updateToolColour", index)
end

function Brush:sv_onGuiOpen()
	self.network:sendToClients( "cl_onGuiOpen" )
end
-- #endregion

function Brush:client_onFixedUpdate()
	if not self.isLocal then return end

	self.panelHideTimer:tick()
	if self.panelHideTimer:done() then
		self.gui:setVisible("panel_colour", true)
		self.gui:setVisible("panel_size", true)
		self.gui:setVisible("panel_preview", true)
	end
end

function Brush.client_onUpdate( self, dt )
	-- First person animation
	local isSprinting = self.tool:isSprinting()
	local isCrouching = self.tool:isCrouching()
	local isEquipped = self.tool:isEquipped()

	if self.colour_transition < 1 then
		self.colour_transition = math.min(self.colour_transition + dt * 2, 1)
		local newColour = colourLerp( self.colour_old, self.colour_current, self.colour_transition )

		self.tool:setTpColor( newColour )
		if self.isLocal then
			self.tool:setFpColor( newColour )
		end
	end

	if self.isLocal then
		if isEquipped then
			if isSprinting and self.fpAnimations.currentAnimation ~= "sprintInto" and self.fpAnimations.currentAnimation ~= "sprintIdle" then
				swapFpAnimation( self.fpAnimations, "sprintExit", "sprintInto", 0.0 )
			elseif not self.tool:isSprinting() and ( self.fpAnimations.currentAnimation == "sprintIdle" or self.fpAnimations.currentAnimation == "sprintInto" ) then
				swapFpAnimation( self.fpAnimations, "sprintInto", "sprintExit", 0.0 )
			end
		end
		updateFpAnimations( self.fpAnimations, isEquipped, dt )

		if self.gui:isActive() then
			self.gui:setSliderPosition( "slider_sizeX", self.sizeX - 1 )
			self.gui:setSliderPosition( "slider_sizeY", self.sizeY - 1 )
		end
	end

	local crouchWeight = self.tool:isCrouching() and 1.0 or 0.0
	local normalWeight = 1.0 - crouchWeight
	local totalWeight = 0.0

	for name, animation in pairs( self.tpAnimations.animations ) do
		animation.time = animation.time + dt

		if name == self.tpAnimations.currentAnimation then
			animation.weight = math.min( animation.weight + ( self.tpAnimations.blendSpeed * dt ), 1.0 )

			if animation.looping == true then
				if animation.time >= animation.info.duration then
					animation.time = animation.time - animation.info.duration
				end
			end
			if animation.time >= animation.info.duration - self.blendTime and not animation.looping then
				if name == "paint" or name == "colourpick" or name == "erase" then
					setTpAnimation( self.tpAnimations, "idle", 10.0 )
				elseif name == "pickup" then
					setTpAnimation( self.tpAnimations, "idle", 0.001 )
				elseif animation.nextAnimation ~= "" then
					setTpAnimation( self.tpAnimations, animation.nextAnimation, 0.001 )
				end

			end
		else
			animation.weight = math.max( animation.weight - ( self.tpAnimations.blendSpeed * dt ), 0.0 )
		end

		totalWeight = totalWeight + animation.weight
	end

	totalWeight = totalWeight == 0 and 1.0 or totalWeight
	for name, animation in pairs( self.tpAnimations.animations ) do

		local weight = animation.weight / totalWeight
		if name == "idle" then
			self.tool:updateMovementAnimation( animation.time, weight )
		elseif animation.crouch then
			self.tool:updateAnimation( animation.info.name, animation.time, weight * normalWeight )
			self.tool:updateAnimation( animation.crouch.name, animation.time, weight * crouchWeight )
		else
			self.tool:updateAnimation( animation.info.name, animation.time, weight )
		end
	end
end

function Brush:client_onEquip( animate )
	if animate then
		sm.audio.play( "PaintTool - Equip", self.tool:getPosition() )
	end

	local currentRenderablesTp = {}
	local currentRenderablesFp = {}

	for k,v in pairs( renderablesTp ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderablesFp ) do currentRenderablesFp[#currentRenderablesFp+1] = v end
	for k,v in pairs( renderables ) do currentRenderablesTp[#currentRenderablesTp+1] = v end
	for k,v in pairs( renderables ) do currentRenderablesFp[#currentRenderablesFp+1] = v end

	self.tool:setTpRenderables( currentRenderablesTp )
	self.tool:setTpColor(self.colour_current)
	if self.isLocal then
		self.tool:setFpColor(self.colour_current)
		self.tool:setFpRenderables( currentRenderablesFp )
	end

	self:cl_loadAnimations()

	setTpAnimation( self.tpAnimations, "pickup", 0.0001 )
	if self.isLocal then
		swapFpAnimation( self.fpAnimations, "unequip", "equip", 0.2 )

		if self.drawPointEffect then
			self.drawPointEffect:start()
		end
	end
end

function Brush:client_onUnequip( animate )
	if not sm.exists( self.tool ) then return end

	if animate then
		sm.audio.play( "PaintTool - Unequip", self.tool:getPosition() )
	end

	setTpAnimation( self.tpAnimations, "putdown" )
	if self.isLocal then
		self.drawPointLine.effect:stop()
		if self.drawPointEffect then
			self.drawPointEffect:stop()
		end
		self.visualization:stop()

		if self.fpAnimations.currentAnimation ~= "unequip" then
			swapFpAnimation( self.fpAnimations, "equip", "unequip", 0.2 )
		end
	end
end

function Brush:client_onEquippedUpdate( lmb, rmb, f )
	local valid, shape, hitPoint, normal = self:canDraw()
	local canLineDraw = self.canvas ~= nil and shape == self.canvas

	if valid then
		local transformedDrawPoint
		if self.drawPoint and canLineDraw then
			transformedDrawPoint = self.canvas:transformLocalPoint(self.drawPoint)
			self.drawPointLine:update( transformedDrawPoint, hitPoint, self.sizeY * size_quarter, shape.at )

			if self.visualization:isPlaying() then
				self.visualization:stop()
			end
		else
			self.visualization:setPosition(hitPoint)
			--sm.particle.createParticle("paint_smoke", hitPoint + calculateRightVector(normal))
			--sm.particle.createParticle("paint_smoke", hitPoint + normal, sm.quat.identity(), sm.color.new(0,0,0))
			local default = shape.up
			local rot
			if self.shapeRot == 0 then
				rot = BetterGetRotation(default, shape.at)
			elseif self.shapeRot == 180 then
				rot = BetterGetRotation(-default, shape.at)
			else
				rot = BetterGetRotation(
					default:rotate( -math.rad(self.shapeRot), shape.right ),
					default
				)
			end

			self.visualization:setRotation(rot)
			if not self.visualization:isPlaying() then
				self.visualization:start()
			end
		end

		sm.gui.setCenterIcon( "Use" )
		sm.gui.setInteractionText(
			sm.gui.getKeyBinding( "Create", true ).."Paint on Canvas\t",
			sm.gui.getKeyBinding( "Attack", true ).."Clear Selected Position/Canvas",
			""
		)
		sm.gui.setInteractionText(
			sm.gui.getKeyBinding( "NextCreateRotation", true ).."Adjust Settings\t",
			sm.gui.getKeyBinding( "ForceBuild", true ).."Select Point\t",
			sm.gui.getKeyBinding( "Reload", true ).."Paint Canvas"
		)

		local x, y = sm.localPlayer.getMouseDelta()
		local mouseMovement = x + y
		if lmb == 1 or lmb == 2 and (mouseMovement ~= 0 or shape.velocity ~= vec3_zero or shape.body.angularVelocity ~= vec3_zero or self.tool:getOwner().character.velocity:length2() > 0.1) then
			local data = {
				board = shape,
				colour = self.colour_current,
				size = { x = self.sizeX * size_quarter, y = self.sizeY * size_quarter },
				uuid = self.shapeToDraw,
				normal = normal
			}

			--local angularVel = shape.body.angularVelocity
			if self.drawPoint ~= nil and canLineDraw then
				data.pos = {
					startPoint = self.drawPoint, -- angularVel,
					endPoint = shape:transformPoint(hitPoint) -- angularVel
				}
			else
				data.pos = shape:transformPoint( hitPoint ) -- angularVel
				data.rot = self.shapeRot
			end

			self.network:sendToServer("sv_n_onDraw", data )

			if lmb ~= 2 then
				self.network:sendToServer("sv_onUse", "paint" )
			end
		end

		if rmb == 1 then
			if self.drawPoint ~= nil then
				self.canvas = nil
				self.drawPoint = nil
				self.drawPointEffect:stopImmediate()
				self.drawPointEffect:destroy()
				self.drawPointEffect = nil

				sm.gui.displayAlertText("#00eeeeDraw point cleared!", 2.5)
			else
				self.network:sendToServer("sv_n_onClear", shape.interactable)
				sm.gui.displayAlertText("#00ff00Canvas cleared!", 2.5)
			end

			self.network:sendToServer("sv_onUse", "erase" )
		end

		if f and self.shouldRegisterF then
			self.shouldRegisterF = false

			self.canvas = shape
			self.drawPoint = shape:transformPoint( hitPoint )

			if self.drawPointEffect and sm.exists(self.drawPointEffect) then
				self.drawPointEffect:stopImmediate()
				self.drawPointEffect:destroy()
				self.drawPointEffect = nil
			end

			self.drawPointEffect = sm.effect.createEffect( "ShapeRenderable", shape.interactable )
			self.drawPointEffect:setParameter("uuid", drawPointUUID)
			self.drawPointEffect:setParameter("color", drawPointColour)
			self.drawPointEffect:setOffsetPosition( self.drawPoint )
			self.drawPointEffect:setScale( scale )
			self.drawPointEffect:start()

			sm.gui.displayAlertText("#00ffffDraw point selected!", 2.5)
		elseif not f then
			self.shouldRegisterF = true
		end
	elseif self.visualization:isPlaying() then
		self.visualization:stop()
	end

	if (not valid or not self.drawPoint or not canLineDraw) and self.drawPointLine.effect:isPlaying() then
		self.drawPointLine.effect:stop()
	end

	return true, true
end

function Brush:client_onToggle()
	self.gui:setMeshPreview( "brushPreview", self.shapeToDraw )
	self.gui:open()
	self.network:sendToServer("sv_onGuiOpen")

	return true
end

function Brush:client_onReload()
	local valid, shape, hitPoint, normal = self:canDraw()
	if valid then
		self.network:sendToServer("sv_setCanvasColour", { board = shape, colour = self.colour_current })
		self.network:sendToServer("sv_onUse", "paint" )
		sm.gui.displayAlertText("#00ffffCanvas painted!", 2.5)
	end

	return true
end

function Brush:sv_setCanvasColour( args )
	args.board:setColor( args.colour )
end

function Brush:cl_onUse( anim )
	--local sound = { paint = "PaintTool - Paint", erase = "PaintTool - Erase" }
	--sm.audio.play(sound[anim], self.tool:getOwner().character.worldPosition)
	if anim == "erase" then
		sm.audio.play("PaintTool - Erase", self.tool:getOwner().character.worldPosition)
	end

	if self.isLocal then
		setFpAnimation( self.fpAnimations, anim, 0.25 )
	end
	setTpAnimation( self.tpAnimations, anim, 10.0 )
end

function Brush:sv_n_onDraw( args )
	local sent = {
		pos = args.pos,
		colour = args.colour,
		size = args.size,
		uuid = args.uuid,
		rot = args.rot,
		normal = args.normal
	}
	sm.event.sendToInteractable( args.board.interactable, "sv_onDraw", sent )
end

function Brush:sv_onUse( anim )
	self.network:sendToClients( "cl_onUse", anim )
end

function Brush:sv_n_onClear( board )
	sm.event.sendToInteractable( board, "sv_onClear" )
end


-- #region util
function Brush.canDraw()
	local hit, result = sm.localPlayer.getRaycast( 7.5 )
	local shape

	if hit then
		local hitBody = result:getBody()
		if hitBody then
			for k, body in pairs(hitBody:getCreationBodies()) do
				for _k, int in pairs(body:getInteractables()) do
					local _shape = int:getShape()
					if _shape.uuid == creationCanvasUUID then
						shape = _shape
						break
					end
				end
			end
		end

		if not shape then
			local hitShape = result:getShape()
			shape = (hitShape and hitShape.uuid == canvasUUID) and hitShape or nil
		end
	end

	return shape ~= nil, shape, result.pointWorld, result.normalWorld
end

function colourLerp(c1, c2, t)
    local r = sm.util.lerp(c1.r, c2.r, t)
    local g = sm.util.lerp(c1.g, c2.g, t)
    local b = sm.util.lerp(c1.b, c2.b, t)
    return sm.color.new(r,g,b)
end
-- #endregion



function Brush.cl_loadAnimations( self )
	self.tpAnimations = createTpAnimations(
		self.tool,
		{
			idle = { "painttool_idle", { looping = true } },

			paint = { "painttool_paint", { nextAnimation = "idle" } },
			erase = { "painttool_erase", { nextAnimation = "idle" } },
			colourpick = { "painttool_colorpick", { nextAnimation = "idle" } },
			colourpick_idle = { "painttool_colorpick_idle", { looping = true } },

			sprint = { "painttool_sprint" },
			pickup = { "painttool_pickup", { nextAnimation = "idle" } },
			putdown = { "painttool_putdown" }

		}
	)
	local movementAnimations = {

		idle = "painttool_idle",
		idleRelaxed = "painttool_idle_relaxed",

		runFwd = "painttool_run_fwd",
		runBwd = "painttool_run_bwd",
		sprint = "painttool_sprint",

		jump = "painttool_jump",
		jumpUp = "painttool_jump_up",
		jumpDown = "painttool_jump_down",

		land = "painttool_jump_land",
		landFwd = "painttool_jump_land_fwd",
		landBwd = "painttool_jump_land_bwd",

		crouchIdle = "painttool_crouch_idle",
		crouchFwd = "painttool_crouch_fwd",
		crouchBwd = "painttool_crouch_bwd"
	}

	for name, animation in pairs( movementAnimations ) do
		self.tool:setMovementAnimation( name, animation )
	end

	if self.isLocal then
		self.fpAnimations = createFpAnimations(
			self.tool,
			{
				idle = { "painttool_idle", { looping = true } },

				sprintInto = { "painttool_sprint_into", { nextAnimation = "sprintIdle",  blendNext = 0.2 } },
				sprintIdle = { "painttool_sprint_idle", { looping = true } },
				sprintExit = { "painttool_sprint_exit", { nextAnimation = "idle",  blendNext = 0 } },

				paint = { "painttool_paint", { nextAnimation = "idle" } },
				erase = { "painttool_erase", { nextAnimation = "idle" } },
				colourpick = { "painttool_colorpick", { nextAnimation = "idle" } },
				colourpick_idle = { "painttool_colorpick_idle", { looping = true } },

				equip = { "painttool_pickup", { nextAnimation = "idle" } },
				unequip = { "painttool_putdown" }
			}
		)
	end

	setTpAnimation( self.tpAnimations, "idle", 5.0 )
	self.blendTime = 0.2
end