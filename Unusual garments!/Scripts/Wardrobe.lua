---@diagnostic disable: need-check-nil, undefined-global, deprecated
-- Dressbot.lua --
dofile("$SURVIVAL_DATA/Scripts/util.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")

Dressbot = class()

local OpenShutterDistance = 4.0
local CloseShutterDistance = 6.0

-- Server

function Dressbot.server_onCreate(self)
	self:sv_init()
end

function Dressbot.server_onDestroy(self)
	self.storage:save(self.sv.saved)
end

function Dressbot.server_canErase(self)
	if self.sv.saved.currentProcess ~= nil then
		return false
	end
	return true
end

function Dressbot.server_onUnload(self)
	self.storage:save(self.sv.saved)
end

function Dressbot.server_onRefresh(self)
	self:sv_init()
end

function Dressbot.sv_init(self)
	self.sv = {}

	self.sv.saved = self.storage:load()

	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.currentProcess = nil
		self.storage:save(self.sv.saved)
	end
	self.network:setClientData(self.sv.saved.currentProcess)
	sm.effect.playEffect("UI - GarmentBoxIdleCommon", self.shape.worldPosition)
end
local unlockPrice = 60
local itemUUIDs = {
	battery = sm.uuid.new("910a7f2c-52b0-46eb-8873-ad13255539af"),
	garmentBoxes = {
		common = sm.uuid.new("63695efd-0862-49f2-ace6-4d1758147fae"),
		rare = sm.uuid.new("27a221b1-9809-4df1-901a-caafe119c9b6"),
		epic = sm.uuid.new("7ab0cac7-b055-4283-b0bc-f85dd4d0416b")
	}
}

function Dressbot:client_onTinker(character, state)
	if not state then return end
	local unusuals, inventory = self.cl.infuse, sm.localPlayer.getInventory()

	unusuals.infuseGui = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Layouts/dressbot_infuse.layout", true, {
		isHud = false,
		isInteractive = true,
		needsCursor = true,
		hidesHotbar = false,
		isOverlapped = true,
		backgroundAlpha = 0.25
	})
	unusuals.infuseGui:open()

	--Get a list of all garment boxes | IDs 1 - epic, 2 - rare, 3 - epic
	unusuals.garmentBoxes = {}
	for i = 1, inventory:getSize(), 1 do
		local itemdata = inventory:getItem(i)
		if itemdata.uuid == itemUUIDs.garmentBoxes.common then
			unusuals.garmentBoxes[#unusuals.garmentBoxes + 1] = 1
		elseif itemdata.uuid == itemUUIDs.garmentBoxes.rare then
			unusuals.garmentBoxes[#unusuals.garmentBoxes + 1] = 2
		elseif itemdata.uuid == itemUUIDs.garmentBoxes.epic then
			unusuals.garmentBoxes[#unusuals.garmentBoxes + 1] = 3
		end
	end
	self.cl.infuse.currentPage = 1

	--Set button callbacks
	unusuals.infuseGui:setButtonCallback("infuse_button_craft", "cl_onInfuse")

	unusuals.infuseGui:setButtonCallback("infuse_button_garmentboxes_left", "cl_page_minus_1")
	unusuals.infuseGui:setButtonCallback("infuse_button_garmentboxes_right", "cl_page_plus_1")

	unusuals.infuseGui:setButtonCallback("infuse_garmentboxes_button_1", "cl_select_garment_1")
	unusuals.infuseGui:setButtonCallback("infuse_garmentboxes_button_2", "cl_select_garment_2")
	unusuals.infuseGui:setButtonCallback("infuse_garmentboxes_button_3", "cl_select_garment_3")
end

function Dressbot:cl_onInfuse()
	local inventory = sm.localPlayer.getInventory()
	if inventory:canSpend(itemUUIDs.battery, unlockPrice) then
		print("Wowie! You're so rich!")
	else
		print("Fuck you peasant!")
	end
end

function Dressbot:cl_page_minus_1()
	if self.cl.infuse.currentPage == 1 then return end
	self.cl.infuse.currentPage = self.cl.infuse.currentPage - 1
end

function Dressbot:cl_page_plus_1()
	print(self.cl.infuse.currentPage, self.cl.infuse.pageCount)
	if self.cl.infuse.currentPage >= self.cl.infuse.pageCount or sm.game.getLimitedInventory() then return end
	self.cl.infuse.currentPage = self.cl.infuse.currentPage + 1
end

function Dressbot:cl_select_garment_1()
	self:cl_select_garment(1)
end

function Dressbot:cl_select_garment_2()
	self:cl_select_garment(2)
end

function Dressbot:cl_select_garment_3()
	self:cl_select_garment(3)
end

function Dressbot:cl_select_garment(slot)
	print(slot)
end

function Dressbot:client_onFixedUpdate(dt)
	local unusuals, inventory = self.cl.infuse, sm.localPlayer.getInventory()

	if not (unusuals.infuseGui and sm.exists(unusuals.infuseGui) and unusuals.infuseGui:isActive()) then return end

	--Get battery count
	unusuals.infuseGui:setText("infuse_resource", (sm.game.getLimitedInventory() and tostring(sm.container.totalQuantity(inventory, itemUUIDs.battery)) or "*") .. "/" .. tostring(unlockPrice))

	--Get garment box count
	local pageCount = sm.container.totalQuantity(inventory, itemUUIDs.garmentBoxes.common) +
					  sm.container.totalQuantity(inventory, itemUUIDs.garmentBoxes.rare) +
					  sm.container.totalQuantity(inventory, itemUUIDs.garmentBoxes.epic)
	pageCount = math.ceil(pageCount / 3)
	if pageCount == 0 then
		unusuals.infuseGui:setText("infuse_garmentboxes_pagecount", 0 .. "/" .. (sm.game.getLimitedInventory() and tostring(pageCount) or "*"))
	else
		unusuals.infuseGui:setText("infuse_garmentboxes_pagecount", tostring(unusuals.currentPage) .. "/" .. (sm.game.getLimitedInventory() and tostring(pageCount) or "*"))
	end

	self.cl.infuse.pageCount = pageCount

	--Fill slots with garment boxes
	if sm.game.getCurrentTick() % 40 ~= 0 then return end

	local garmentBoxID = unusuals.garmentBoxes[unusuals.currentPage]
	if garmentBoxID == 1 then
		unusuals.infuseGui:stopEffect("infuse_garmentboxes_widget_1", "UI - GarmentBoxIdleCommon", true)
		unusuals.infuseGui:playEffect("infuse_garmentboxes_widget_1", "UI - GarmentBoxIdleCommon", true)
	elseif garmentBoxID == 2 then
		unusuals.infuseGui:stopEffect("infuse_garmentboxes_widget_1", "UI - GarmentBoxIdleRare", true)
		unusuals.infuseGui:playEffect("infuse_garmentboxes_widget_1", "UI - GarmentBoxIdleRare", true)
	elseif garmentBoxID == 3 then
		unusuals.infuseGui:stopEffect("infuse_garmentboxes_widget_1", "UI - GarmentBoxIdleEpic", true)
		unusuals.infuseGui:playEffect("infuse_garmentboxes_widget_1", "UI - GarmentBoxIdleEpic", true)
	end

	local garmentBoxID = unusuals.garmentBoxes[unusuals.currentPage + 1]
	if garmentBoxID == 1 then
		unusuals.infuseGui:stopEffect("infuse_garmentboxes_widget_2", "UI - GarmentBoxIdleCommon", true)
		unusuals.infuseGui:playEffect("infuse_garmentboxes_widget_2", "UI - GarmentBoxIdleCommon", true)
	elseif garmentBoxID == 2 then
		unusuals.infuseGui:stopEffect("infuse_garmentboxes_widget_2", "UI - GarmentBoxIdleRare", true)
		unusuals.infuseGui:playEffect("infuse_garmentboxes_widget_2", "UI - GarmentBoxIdleRare", true)
	elseif garmentBoxID == 3 then
		unusuals.infuseGui:stopEffect("infuse_garmentboxes_widget_2", "UI - GarmentBoxIdleEpic", true)
		unusuals.infuseGui:playEffect("infuse_garmentboxes_widget_2", "UI - GarmentBoxIdleEpic", true)
	end

	local garmentBoxID = unusuals.garmentBoxes[unusuals.currentPage + 2]
	if garmentBoxID == 1 then
		unusuals.infuseGui:stopEffect("infuse_garmentboxes_widget_3", "UI - GarmentBoxIdleCommon", true)
		unusuals.infuseGui:playEffect("infuse_garmentboxes_widget_3", "UI - GarmentBoxIdleCommon", true)
	elseif garmentBoxID == 2 then
		unusuals.infuseGui:stopEffect("infuse_garmentboxes_widget_3", "UI - GarmentBoxIdleRare", true)
		unusuals.infuseGui:playEffect("infuse_garmentboxes_widget_3", "UI - GarmentBoxIdleRare", true)
	elseif garmentBoxID == 3 then
		unusuals.infuseGui:stopEffect("infuse_garmentboxes_widget_3", "UI - GarmentBoxIdleEpic", true)
		unusuals.infuseGui:playEffect("infuse_garmentboxes_widget_3", "UI - GarmentBoxIdleEpic", true)
	end

end

function Dressbot.server_onFixedUpdate(self)
	if self.sv.saved.currentProcess then
		local recipe = self:getRecipe(self.sv.saved.currentProcess.itemId)

		if self.sv.saved.currentProcess.time < recipe.craftTime then
			self.sv.saved.currentProcess.time = self.sv.saved.currentProcess.time + 1
			if sm.game.getCurrentTick() % 40 ~= 0 then return end
			self.network:setClientData(self.sv.saved.currentProcess) --TODO: Less frequent --Did it for ya Axolot -xoxo, Donut
		end
	end
end

function Dressbot.sv_n_craft(self, params, player)
	local recipe = self:getRecipe(params.itemId)
	-- Charge container
	sm.container.beginTransaction()
	for _, ingredient in ipairs(recipe.ingredientList) do
		sm.container.spend(player:getInventory(), ingredient.itemId, ingredient.quantity)
	end
	if sm.container.endTransaction() or not sm.game.getLimitedInventory() then -- Can afford
		print("Crafting:", params.itemId)
		self.sv.saved.currentProcess = { itemId = params.itemId, time = -1 }
		self.storage:save(self.sv.saved)
	else
		print("Can't afford to craft")
	end
end

function Dressbot.sv_n_unbox(self, params, player)
	self.sv.saved.currentProcess = nil
	self.storage:save(self.sv.saved)
	self.network:setClientData(self.sv.saved.currentProcess)
	self.network:sendToClients("cl_n_onUnbox", player)
end

-- Common util
function Dressbot.getRecipe(self, stringUuid)
	local recipe = g_craftingRecipes["dressbot"].recipes[stringUuid]
	if recipe then
		return recipe
	end
	return nil
end

-- Client

function Dressbot.client_onCreate(self)
	self:cl_init()
end

function Dressbot.client_onRefresh(self)
	if self.cl then
		if self.cl.user then
			local player = sm.localPlayer.getPlayer()
			player.clientPublicData.interactableCameraData = nil
			self.cl.user:setLockingInteractable(nil)
		end
	end
	self.cl.guiCustomizationInterface:close()
	self:cl_init()
end

function Dressbot.client_canErase(self)
	if self.cl.currentProcess ~= nil then
		sm.gui.displayAlertText("#{INFO_BUSY}", 1.5)
		return false
	end
	return true
end

function Dressbot.cl_init(self)
	self.cl = {}
	self.cl.pullback = 1
	self.cl.pullbackSeated = 1
	self.cl.cameraDirection = sm.vec3.new(0, 1, 0)
	self.cl.cameraHeading = 0
	self.cl.cameraDesiredHeading = self.cl.cameraHeading
	self.cl.cameraPitch = 0
	self.cl.cameraDesiredPitch = self.cl.cameraPitch
	self.cl.cameraPosition = self.shape.worldPosition - self.cl.cameraDirection
	self.cl.input = sm.vec3.new(0, 0, 0)
	self.cl.cameraPullback = 4
	self.cl.desiredCameraPullback = self.cl.cameraPullback

	self.cl.currentProcess = nil
	self.cl.guiCustomizationInterface = sm.gui.createCharacterCustomizationGui()
	self.cl.guiCustomizationInterface:setOnCloseCallback("cl_onClose")

	self.cl.guiDressbotInterface = sm.gui.createDressBotGui()
	self.cl.guiDressbotInterface:setGridButtonCallback("CraftButton", "cl_onCraft")
	self.cl.guiDressbotInterface:setButtonCallback("UnboxButton", "cl_onUnbox")
	self.cl.guiDressbotInterface:addGridItemsFromFile("BoxGrid", "$SURVIVAL_DATA/CraftingRecipes/dressbot.json")

	self.cl.infuse = {}

	-- Setup animations
	local animations = {}
	animations["Unfold"] = self:cl_createAnimation("Unfold", true)
	animations["Idle"] = self:cl_createAnimation("Idle", true)
	animations["Craft_start"] = self:cl_createAnimation("Craft_start", true)
	animations["Craft_loop01"] = self:cl_createAnimation("Craft_loop01", true)
	animations["Craft_loop02"] = self:cl_createAnimation("Craft_loop02", true)
	animations["Craft_finish"] = self:cl_createAnimation("Craft_finish", true)

	self.cl.animations = animations
	self:cl_setAnimation(self.cl.animations["Unfold"], 0.0)

	self.cl.doorAnimation = self:cl_createAnimation("Control_doors", true)
	self.cl.doorAnimation.isActive = true

	-- Setup effects
	self.cl.startEffect = sm.effect.createEffect("Dressbot - Start", self.interactable)
	self.cl.idleEffect = sm.effect.createEffect("Dressbot - Idle", self.interactable)
	self.cl.work01Effect = sm.effect.createEffect("Dressbot - Work01", self.interactable)
	self.cl.work02Effect = sm.effect.createEffect("Dressbot - Work02", self.interactable)
	self.cl.workHeadEffect = sm.effect.createEffect("Dressbot - HeadWork01", self.interactable, "spool_jnt")
	self.cl.finishEffect = sm.effect.createEffect("Dressbot - Finish", self.interactable)
	self.cl.doorEffect = sm.effect.createEffect("Dressbot - Opendoors", self.interactable)
end

function Dressbot.client_canInteract(self)
	local interactRange = 7.5
	local success, result = sm.localPlayer.getRaycast(interactRange)

	local outputPosition = sm.shape.getWorldPosition(self.shape) + self.shape.right * -1.85 + self.shape.up * 0.5 + self.shape.at * -0.5
	local outputDistance = (result.pointWorld - outputPosition):length()
	local outputSphereRadius = 2.0
	local outputWeightedValue = outputDistance / outputSphereRadius

	local keyBindingText = sm.gui.getKeyBinding("Use", true)
	local keyBindingTextSecondary = sm.gui.getKeyBinding("Tinker", true)

	if outputWeightedValue < 1.0 then
		sm.gui.setInteractionText("", keyBindingText, "#{INTERACTION_USE_DRESSBOT}")
		sm.gui.setInteractionText("", keyBindingTextSecondary, "Infuse Hologram Modules")
	else
		sm.gui.setInteractionText("", keyBindingText, "#{INTERACTION_USE_WARDROBE}")
		sm.gui.setInteractionText("", keyBindingTextSecondary, "Infuse Hologram Modules")
	end

	return true
end

function Dressbot.client_onInteract(self, character, state)
	if state == true then
		local interactRange = 7.5
		local success, result = sm.localPlayer.getRaycast(interactRange)

		local outputPosition = sm.shape.getWorldPosition(self.shape) + self.shape.right * -1.85 + self.shape.up * 0.5 + self.shape.at * -0.5
		local outputDistance = (result.pointWorld - outputPosition):length()
		local outputSphereRadius = 2.0
		local outputWeightedValue = outputDistance / outputSphereRadius

		if outputWeightedValue < 1.0 then
			self.cl.guiDressbotInterface:open()
		else
			self:cl_openCustomization(character)
		end
	end
end

function Dressbot.cl_onClose(self)
	if self.cl.user then
		local player = self.cl.user:getPlayer()
		player.clientPublicData.interactableCameraData = nil
		self.cl.user:setLockingInteractable(nil)
		self.cl.user = nil
		self.cl.input = sm.vec3.new(0, 0, 0)
		self.cl.cameraDirection = sm.vec3.new(0, 1, 0)
		self.cl.cameraPosition = self.shape.worldPosition - self.cl.cameraDirection
		self.cl.cameraHeading = 0
		self.cl.cameraDesiredHeading = self.cl.cameraHeading
		self.cl.cameraPitch = 0
		self.cl.cameraDesiredPitch = self.cl.cameraPitch
	end
end

function Dressbot.client_onAction(self, controllerAction, state)
	if state == true then
		if controllerAction == sm.interactable.actions.zoomIn then
			self.cl.desiredCameraPullback = math.max(self.cl.desiredCameraPullback - 1, 1)
		elseif controllerAction == sm.interactable.actions.zoomOut then
			self.cl.desiredCameraPullback = math.min(self.cl.desiredCameraPullback + 1, 10)
		elseif controllerAction == sm.interactable.actions.left then
			self.cl.input.x = -1
		elseif controllerAction == sm.interactable.actions.right then
			self.cl.input.x = 1
		elseif controllerAction == sm.interactable.actions.forward then
			self.cl.input.y = 1
		elseif controllerAction == sm.interactable.actions.backward then
			self.cl.input.y = -1
		else
			return false
		end
	else
		if controllerAction == sm.interactable.actions.left then
			self.cl.input.x = 0
		elseif controllerAction == sm.interactable.actions.right then
			self.cl.input.x = 0
		elseif controllerAction == sm.interactable.actions.forward then
			self.cl.input.y = 0
		elseif controllerAction == sm.interactable.actions.backward then
			self.cl.input.y = 0
		else
			return false
		end
	end
	return true
end

function Dressbot.client_onUpdate(self, dt)
	self:cl_selectAnimation()
	self:cl_updateAnimations(dt)

	local character = sm.localPlayer.getPlayer().character
	if self.cl.user and self.cl.user == character then
		local epsilon = 0.000244140625
		--local mouseSpeed = 1.0
		local mouseSpeed = 12.0
		local relX = self.cl.input.x * mouseSpeed * math.pi * 0.001
		local relY = self.cl.input.y * mouseSpeed * math.pi * 0.001
		self.cl.cameraDesiredPitch = self.cl.cameraDesiredPitch - relY
		self.cl.cameraDesiredHeading = self.cl.cameraDesiredHeading + relX

		-- Avoid pitching beyond straight up and straight down
		if self.cl.cameraDesiredPitch > math.pi * 0.5 - epsilon then
			self.cl.cameraDesiredPitch = math.pi * 0.5 - epsilon
		end
		if self.cl.cameraDesiredPitch < -math.pi * 0.5 + epsilon then
			self.cl.cameraDesiredPitch = -math.pi * 0.5 + epsilon
		end

		-- Keep heading within 0 and 2*pi
		while self.cl.cameraDesiredHeading > math.pi * 2 do
			self.cl.cameraDesiredHeading = self.cl.cameraDesiredHeading - math.pi * 2
			self.cl.cameraHeading = self.cl.cameraHeading - math.pi * 2
		end
		while self.cl.cameraDesiredHeading < 0 do
			self.cl.cameraDesiredHeading = self.cl.cameraDesiredHeading + math.pi * 2
			self.cl.cameraHeading = self.cl.cameraHeading + math.pi * 2
		end

		-- Smooth heading and pitch movement
		local cameraLerpSpeed = 1.0 / 6.0
		local blend = 1 - math.pow(1 - cameraLerpSpeed, dt * 60)
		self.cl.cameraHeading = sm.util.lerp(self.cl.cameraHeading, self.cl.cameraDesiredHeading, blend)
		self.cl.cameraPitch = sm.util.lerp(self.cl.cameraPitch, self.cl.cameraDesiredPitch, blend)
		self.cl.cameraDirection = sm.vec3.new(0, 1, 0)
		self.cl.cameraDirection = self.cl.cameraDirection:rotateX(self.cl.cameraPitch)
		self.cl.cameraDirection = self.cl.cameraDirection:rotateZ(self.cl.cameraHeading)

		-- Smooth pullback
		local pullbackSteps = 0.5
		self.cl.cameraPullback = sm.util.lerp(self.cl.cameraPullback, self.cl.desiredCameraPullback, blend)

		-- Adjust sideways camera offset based on FOV settings
		local fovScale = (sm.camera.getFov() - 45) / 45
		local cameraOffset45 = 0.5
		local cameraOffset90 = 1.0
		local left = sm.vec3.new(0, 0, 1):cross(self.cl.cameraDirection)
		left.z = 0.0
		if left:length() >= FLT_EPSILON then
			left = left:normalize()
		end
		local cameraOffset = left * lerp(cameraOffset45, cameraOffset90, fovScale)

		-- Adjust camera position if the view is blocked
		local fraction = sm.camera.cameraSphereCast(0.2, character.worldPosition + cameraOffset,
			-self.cl.cameraDirection * self.cl.cameraPullback * pullbackSteps)
		self.cl.cameraPosition = character.worldPosition + cameraOffset -
		self.cl.cameraDirection * self.cl.cameraPullback * pullbackSteps * fraction

		-- Finalize
		local interactableCameraData = {}
		interactableCameraData.hideGui = false
		interactableCameraData.cameraState = sm.camera.state.cutsceneTP
		interactableCameraData.cameraPosition = self.cl.cameraPosition
		interactableCameraData.cameraDirection = self.cl.cameraDirection
		interactableCameraData.cameraFov = sm.camera.getDefaultFov()
		interactableCameraData.lockedControls = false
		self.cl.user:getPlayer().clientPublicData.interactableCameraData = interactableCameraData
	end
end

function Dressbot.cl_openCustomization(self, character)
	if self.cl.user == nil then
		character:setLockingInteractable(self.interactable)
		self.cl.user = character
		--audio event

		self.cl.guiCustomizationInterface:open()

		self.cl.cameraDirection = -character:getDirection()
		local direction = sm.vec3.new(self.cl.cameraDirection.x, self.cl.cameraDirection.y, 0)
		if direction:length() >= FLT_EPSILON then
			self.cl.cameraDirection = direction:normalize()
		end
		self.cl.cameraPosition = character.worldPosition - self.cl.cameraDirection * self.cl.cameraPullback
		self.cl.cameraDesiredHeading = math.atan2(-self.cl.cameraDirection.x, self.cl.cameraDirection.y)
		self.cl.cameraHeading = self.cl.cameraDesiredHeading
		self.cl.cameraDesiredPitch = math.asin(self.cl.cameraDirection.z)
		self.cl.cameraPitch = self.cl.cameraDesiredPitch
	end
end

function Dressbot.cl_onCraft(self, buttonName, index, data)
	self.network:sendToServer("sv_n_craft", { itemId = data.itemId })
end

function Dressbot.cl_onUnbox(self, buttonName)
	self.network:sendToServer("sv_n_unbox")
end

function Dressbot.cl_n_onUnbox(self, player)
	if player ~= sm.localPlayer.getPlayer() then
		self.cl.guiDressbotInterface:clearGrid("ProcessGrid")
	end
end

function Dressbot.client_onClientDataUpdate(self, data)
	self.cl.currentProcess = data
	if data ~= nil then
		local recipe = self:getRecipe(data.itemId)

		self.cl.guiDressbotInterface:setGridItem("ProcessGrid", 0, { itemId = data.itemId })
		self.cl.guiDressbotInterface:setData("Progress", { craftTime = recipe.craftTime, elapsedTime = data.time })
	end
end

-- Animations
function Dressbot.cl_createAnimation(self, name, playForward)
	local animation =
	{
		-- Required
		name = name,
		playProgress = 0.0,
		playTime = self.interactable:getAnimDuration(name),
		isActive = false,
		-- Optional
		playForward = (playForward or playForward == nil)
	}
	return animation
end

function Dressbot.cl_setAnimation(self, animation, playProgress)
	self:cl_unsetAnimation()
	animation.isActive = true
	animation.playProgress = playProgress
	self.interactable:setAnimEnabled(animation.name, true)
end

function Dressbot.cl_unsetAnimation(self)
	for name, animation in pairs(self.cl.animations) do
		animation.isActive = false
		animation.playProgress = 0.0
		self.interactable:setAnimEnabled(animation.name, false)
		self.interactable:setAnimProgress(animation.name, animation.playProgress)
	end
end

function Dressbot.cl_selectAnimation(self)
	-- Open/Close shutter
	if self.cl.doorAnimation.isActive then
		if math.abs(self.cl.doorAnimation.playProgress) >= 1.0 then
			if GetClosestPlayer(self.shape.worldPosition, OpenShutterDistance, self.shape.body:getWorld()) ~= nil then
				if self.cl.doorAnimation.playForward == false then
					self.cl.doorEffect:start()
				end
				self.cl.doorAnimation.playForward = true
			elseif GetClosestPlayer(self.shape.worldPosition, CloseShutterDistance, self.shape.body:getWorld()) == nil then
				if self.cl.doorAnimation.playForward == true then
					self.cl.doorEffect:start()
				end
				self.cl.doorAnimation.playForward = false
			end
		end
	end

	if self.cl.currentProcess then
		local recipe = self:getRecipe(self.cl.currentProcess.itemId)
		if self.cl.currentProcess.time < recipe.craftTime then
			-- Crafting
			if self.cl.animations["Idle"].isActive then
				self:cl_setAnimation(self.cl.animations["Craft_start"], 0.0)
				self.cl.startEffect:start()
			elseif self.cl.animations["Craft_start"].isActive and self.cl.animations["Craft_start"].playProgress >= 1.0 then
				self:cl_setAnimation(self.cl.animations["Craft_loop01"], 0.0)
				self.cl.work01Effect:start()
				self.cl.workHeadEffect:start()
			elseif (self.cl.animations["Craft_loop01"].isActive and self.cl.animations["Craft_loop01"].playProgress >= 1.0) or (self.cl.animations["Craft_loop02"].isActive and self.cl.animations["Craft_loop02"].playProgress >= 1.0) then
				self.cl.work01Effect:stop()
				self.cl.work02Effect:stop()
				local craftLoop = randomStackAmount(1, 1.285, 2) --67% craftloop1, 33% craftloop2
				if craftLoop == 2 and self.cl.animations["Craft_loop02"].playTime * 40 <= recipe.craftTime - self.cl.currentProcess.time then
					self:cl_setAnimation(self.cl.animations["Craft_loop02"], 0.0)
					self.cl.work02Effect:start()
					self.cl.workHeadEffect:start()
				else
					self:cl_setAnimation(self.cl.animations["Craft_loop01"], 0.0)
					self.cl.work01Effect:start()
					self.cl.workHeadEffect:start()
				end
			end
		else
			-- Finish crafting
			if not self.cl.animations["Craft_finish"].isActive and not self.cl.animations["Idle"].isActive then
				self:cl_setAnimation(self.cl.animations["Craft_finish"], 0.0)
				self.cl.work01Effect:stop()
				self.cl.work02Effect:stop()
				self.cl.finishEffect:start()
			end
		end
	else
		-- Idle
		if self.cl.animations["Craft_finish"].isActive or self.cl.animations["Craft_loop02"].isActive or self.cl.animations["Craft_start"].isActive then
			self:cl_setAnimation(self.cl.animations["Idle"], 0.0)
			self.cl.idleEffect:start()
		elseif self.cl.animations["Unfold"].isActive and self.cl.animations["Unfold"].playProgress >= 1.0 then
			self:cl_setAnimation(self.cl.animations["Idle"], 0.0)
			self.cl.idleEffect:start()
		elseif self.cl.animations["Idle"].isActive and self.cl.animations["Idle"].playProgress >= 1.0 then
			self:cl_setAnimation(self.cl.animations["Idle"],
				(self.cl.animations["Idle"].playProgress - 1.0) * self.cl.animations["Idle"].playTime)
			self.cl.idleEffect:start()
		end
	end
end

function Dressbot.cl_updateAnimations(self, dt)
	for name, animation in pairs(self.cl.animations) do
		self:cl_updateAnimation(animation, dt)
	end
	self:cl_updateAnimation(self.cl.doorAnimation, dt)
end

function Dressbot.cl_updateAnimation(self, animation, dt)
	if animation.isActive then
		self.interactable:setAnimEnabled(animation.name, true)
		if animation.playForward then
			animation.playProgress = animation.playProgress + dt / animation.playTime
			if animation.playProgress > 1.0 then
				animation.playProgress = 1.0
			end
			self.interactable:setAnimProgress(animation.name, animation.playProgress)
		else
			animation.playProgress = animation.playProgress - dt / animation.playTime
			if animation.playProgress < -1.0 then
				animation.playProgress = -1.0
			end
			self.interactable:setAnimProgress(animation.name, 1.0 + animation.playProgress)
		end
	end
end