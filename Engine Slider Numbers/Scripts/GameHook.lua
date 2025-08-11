---@diagnostic disable:duplicate-set-field

---@class GameHook : ToolClass
GameHook = class()

local gameHooked = false
local oldHud = sm.gui.createSurvivalHudGui
function hudHook()
    if not gameHooked then
        dofile("$CONTENT_f2c02040-a46f-48ec-a58c-957df08b9fbc/Scripts/vanilla_override.lua")
        gameHooked = true
    end

	return oldHud()
end
sm.gui.createSurvivalHudGui = hudHook

local oldBind = sm.game.bindChatCommand
function bindHook(command, params, callback, help)
    if not gameHooked then
        dofile("$CONTENT_f2c02040-a46f-48ec-a58c-957df08b9fbc/Scripts/vanilla_override.lua")
        gameHooked = true
    end

	return oldBind(command, params, callback, help)
end
sm.game.bindChatCommand = bindHook



oldEngineGui = oldEngineGui or sm.gui.createEngineGui
function sm.gui.createEngineGui(destroyOnClose)
    local gui = {
        subGuis = {},
        sliderData = {}
    }

    local vanilla = oldEngineGui(destroyOnClose)
    local overlay = sm.gui.createGuiFromLayout("$CONTENT_f2c02040-a46f-48ec-a58c-957df08b9fbc/Gui/overlay.layout", false, {
        isHud = true,
        isInteractive = true,
        needsCursor = true,
        hidesHotbar = false,
        isOverlapped = false,
        backgroundAlpha = 0
    })

    vanilla:setVisible("Setting", false)
    overlay:createHorizontalSlider("Setting", 10, 5, "cl_onSliderChange", true, false)

    gui.subGuis.vanilla = vanilla
    gui.subGuis.overlay = overlay

    function gui:addGridItem(gridName, item)end

    function gui:addGridItemsFromFile(gridName, jsonPath, additionalData) end

    function gui:addToPickupDisplay( uuid, difference ) end

    function gui:addListItem(listName, itemName, data) end

    function gui:clearGrid(gridName) end

    function gui:clearList(listName) end

    function gui:close()
        self.subGuis.vanilla:close()
        self.subGuis.overlay:close()
    end

    function gui:createDropDown(widgetName, functionName, options) end

    function gui:createGridFromJson(gridName, index) end

    function gui:createHorizontalSlider(widgetName, range, value, functionName, numbered, inverted) end

    function gui:createVerticalSlider(widgetName, range, value, functionName) end

    function gui:destroy()
        self.subGuis.vanilla:destroy()
        self.subGuis.overlay:destroy()

        self.subGuis = nil
    end

    function gui:isActive()
        return self.subGuis.vanilla:isActive()
    end

    function gui:open()
        self.subGuis.vanilla:open()
        self.subGuis.overlay:open()
    end

    function gui:playEffect(widgetName, effectName, restart)
        if widgetName == "Setting" then
            self.subGuis.overlay:playEffect(widgetName, effectName, restart)
        else
            self.subGuis.vanilla:playEffect(widgetName, effectName, restart)
        end
    end

    function gui:playGridEffect(gridName, index, effectName, restart) end

    function gui:setButtonCallback(buttonName, callback) end

    function gui:setButtonState(buttonName, state) end

    function gui:setColor(widgetName, Color)
        self.subGuis.vanilla:setColor(widgetName, Color)
    end

    function gui:setContainer(gridName, container)
        self.subGuis.vanilla:setContainer(gridName, container)
    end

    function gui:setContainers(gridName, containers)
        self.subGuis.vanilla:setContainers(gridName, containers)
    end

    function gui:setData(widgetName, data)
        self.subGuis.vanilla:setData(widgetName, data)
    end

    function gui:setFadeRange(range) end

    function gui:setFocus(widgetName)
        if widgetName == "Setting" then
            self.subGuis.overlay:setFocus(widgetName)
        else
            self.subGuis.vanilla:setFocus(widgetName)
        end
    end

    function gui:setGridButtonCallback(buttonName, callback) end

    function gui:setGridItem(gridName, index, item) end

    function gui:setGridItemChangedCallback(gridName, callback) end

    function gui:setGridMouseFocusCallback(buttonName, callback) end

    function gui:setGridSize(gridName, index) end

    -- function gui:setHost(object, joint) end

    function gui:setHost(widgetName, shape, joint) end

    function gui:setIconImage(itembox, uuid)
        self.subGuis.vanilla:setIconImage(itembox, uuid)
    end

    function gui:setImage(imagebox, image)
        self.subGuis.vanilla:setImage(imagebox, image)
    end

    function gui:setItemIcon(imagebox, itemResource, itemGroup, itemName)
        self.subGuis.vanilla:setItemIcon(imagebox, itemResource, itemGroup, itemName)
    end

    function gui:setListSelectionCallback(listName, callback) end

    function gui:setMaxRenderDistance(distance) end

    function gui:setMeshPreview(widgetName, uuid) end

    function gui:setOnCloseCallback(callback)
        self.subGuis.vanilla:setOnCloseCallback(callback)
    end

    function gui:setRequireLineOfSight(required) end

    function gui:setSelectedDropDownItem(widget, item) end

    function gui:setSelectedListItem(listName, itemName) end

    function gui:setSliderCallback(sliderName, callback)
        self.subGuis.vanilla:setSliderCallback(sliderName, callback)
    end

    function gui:setSliderData(sliderName, range, position)
        self.subGuis.vanilla:setSliderData(sliderName, range, position)
    end

    function gui:setSliderPosition(sliderName, position)
        self.subGuis.vanilla:setSliderPosition(sliderName, position)
    end

    function gui:setSliderRange(sliderName, range)
        self.subGuis.vanilla:setSliderRange(sliderName, range)
    end

    function gui:setSliderRangeLimit(sliderName, limit)
        self.subGuis.vanilla:setSliderRangeLimit(sliderName, limit)
    end

    function gui:setText(textbox, text)
        self.subGuis.vanilla:setText(textbox, text)
    end

    function gui:setTextAcceptedCallback(editBoxName, callback) end

    function gui:setTextChangedCallback(editBoxName, callback) end

    function gui:setVisible(widgetName, visible)
        if widgetName == "Setting" then
            self.subGuis.overlay:setVisible(widgetName, visible)
        else
            self.subGuis.vanilla:setVisible(widgetName, visible)
        end
    end

    function gui:setWorldPosition(position, world) end

    function gui:stopEffect(widgetName, effectName, immediate)
        if widgetName == "Setting" then
            self.subGuis.overlay:stopEffect(widgetName, effectName, immediate)
        else
            self.subGuis.vanilla:stopEffect(widgetName, effectName, immediate)
        end
    end

    function gui:stopGridEffect(gridName, index, effectName) end

    function gui:trackQuest(name, title, mainQuest, questTasks) end

    function gui:untrackQuest(questName) end


    return gui
end