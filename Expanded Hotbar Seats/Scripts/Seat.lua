-- Seat_Expanded.lua --
dofile("$SURVIVAL_DATA/Scripts/game/survival_constants.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_shapes.lua")
dofile("$SURVIVAL_DATA/Scripts/game/survival_units.lua")

---@class Seat_Expanded : ShapeClass
---@field cl table
---@field gui GuiInterface
---@field upgradeGui GuiInterface
---@field selectedHotbar number
Seat_Expanded = class()
Seat_Expanded.maxChildCount = 10
Seat_Expanded.connectionOutput = sm.interactable.connectionType.seated
Seat_Expanded.colorNormal = sm.color.new( 0x00ff80ff )
Seat_Expanded.colorHighlight = sm.color.new( 0x6affb6ff )

Seat_Expanded.Levels = {
	["eafb82a0-ad29-46ee-9713-c34254d9775e"] = { maxConnections = 30, title = "#{LEVEL} 5"},
}

--[[ Server ]]

function Seat_Expanded.server_onCreate( self )

end

function Seat_Expanded.server_onFixedUpdate( self )
	self.interactable:setActive( self.interactable:getSeatCharacter() ~= nil )
end

function Seat_Expanded.sv_n_tryUpgrade( self, player )
	local level = self.Levels[tostring( self.shape:getShapeUuid() )]
	if level and level.upgrade then
		local function fnUpgrade()
			local nextLevel = self.Levels[tostring( level.upgrade )]
			assert( nextLevel )
			self.network:sendToClients( "cl_n_onUpgrade", level.upgrade )

			self.shape:replaceShape( level.upgrade )
		end

		if sm.game.getEnableUpgrade() then
			local inventory = player:getInventory()

			if sm.container.totalQuantity( inventory, obj_consumable_component ) >= level.cost then

				if sm.container.beginTransaction() then
					sm.container.spend( inventory, obj_consumable_component, level.cost, true )

					if sm.container.endTransaction() then
						fnUpgrade()
					end
				end
			else
				print( "Cannot afford upgrade" )
			end
		end

	end
end

--[[ Client ]]
local colPerHotbar = {
	[0] = sm.color.new("eeeeeeff"),
	[1] = sm.color.new("7f7f7fff"),
	[2] = sm.color.new("4a4a4aff")
}

function Seat_Expanded.client_onCreate( self )
	self.cl = {}
	self.cl.seatedCharacter = nil
	self.selectedHotbar = 0
end

function Seat_Expanded.client_onDestroy( self )
	if self.gui then
		self.gui:destroy()
		self.gui = nil
	end
end

function Seat_Expanded.client_onUpdate( self, dt )

	-- Update gui upon character change in seat
	local seatedCharacter = self.interactable:getSeatCharacter()
	if self.cl.seatedCharacter ~= seatedCharacter then
		if seatedCharacter and seatedCharacter:getPlayer() and seatedCharacter:getPlayer():getId() == sm.localPlayer.getId() then
			self.gui = sm.gui.createSeatGui()
			self.gui:open()

			self.gui2 = sm.gui.createGuiFromLayout("$CONTENT_DATA/Gui/Inventory.layout", false,
				{
					isHud = true,
					isInteractive = false,
					needsCursor = false,
					hidesHotbar = false,
					isOverlapped = false,
					backgroundAlpha = 0
				}
			)
			self.gui2:setVisible("HotbarGrid", false)
			self.gui2:setVisible("IndicatorPanel", true)
			for i = 1, 3 do
				self.gui2:setVisible("Hotbar_"..i, true)
			end

			self.gui2:open()
		else
			if self.gui then
				self.gui:destroy()
				self.gui = nil

				self.gui2:destroy()
				self.gui2 = nil
			end
		end
		self.cl.seatedCharacter = seatedCharacter
	end

	-- Update gui upon toolbar updates
	if self.gui then

		---@type Interactable[]
		local interactables = {}
		local colour = colPerHotbar[self.selectedHotbar]
		for k, v in pairs(self.interactable:getSeatInteractables()) do
			local shape = v.shape
			local shapeCol = shape.color
			if shapeCol == colour --[[or self.selectedHotbar == 0 and sm.item.getShapeDefaultColor(shape.uuid) == shapeCol]] then
				table.insert(interactables, v)
			end
		end

		for i=1, 10 do
			local value = interactables[i]
			if value --[[and value:getConnectionInputType() == sm.interactable.connectionType.seated]] then
				self.gui:setGridItem( "ButtonGrid", i-1, {
					["itemId"] = tostring(value.shape.uuid),
					["active"] = value.active
				})
			else
				self.gui:setGridItem( "ButtonGrid", i-1, nil)
			end
		end

		for i = 0, 2 do
			self.gui2:setButtonState("Hotbar_"..(i + 1),  i == self.selectedHotbar)
		end
	end

end

function Seat_Expanded.cl_seat( self )
	if sm.localPlayer.getPlayer() and sm.localPlayer.getPlayer():getCharacter() then
		self.interactable:setSeatCharacter( sm.localPlayer.getPlayer():getCharacter() )
	end
end

function Seat_Expanded.client_canInteract( self, character )
	if character:getCharacterType() == unit_mechanic and not character:isTumbling() then
		return true
	end
	return false
end

function Seat_Expanded.client_onInteract( self, character, state )
	if state then
		self:cl_seat()
		if self.shape.interactable:getSeatCharacter() ~= nil then
			sm.gui.displayAlertText( "#{ALERT_DRIVERS_SEAT_OCCUPIED}", 4.0 )
		end
	end
end

function Seat_Expanded.client_canTinker( self, character )
	if not self.shape.usable then
		return false
	end
	local level = self.Levels[tostring( self.shape:getShapeUuid() )]
	if level and level.title then
		return true
	end
	return false
end

function Seat_Expanded.client_onTinker( self, character, state )
	if state then
		self.upgradeGui = sm.gui.createSeatUpgradeGui()
		self.upgradeGui:open()

		self.upgradeGui:setIconImage( "Icon", self.shape:getShapeUuid() )
		self.upgradeGui:setButtonCallback( "Upgrade", "cl_onUpgradeClicked" )

		local level = self.Levels[ tostring( self.shape:getShapeUuid() ) ]

		if level then
			if level.upgrade then
				self.upgradeGui:setIconImage( "UpgradeIcon", level.upgrade )

				local nextLevel = self.Levels[ tostring( level.upgrade ) ]
				local infoData = { Connections = nextLevel.maxConnections - level.maxConnections }

				if nextLevel.allowAdjustingJoints ~= nil then
					if nextLevel.allowAdjustingJoints == true then
						infoData.Settings = "#{UNLOCKED}"
					end
				end
				self.upgradeGui:setData( "UpgradeInfo", infoData )
			else
				self.upgradeGui:setVisible( "UpgradeIcon", false )
			end

			self.upgradeGui:setText( "SubTitle", level.title )

			if sm.game.getEnableUpgrade() and level.cost then
				local inventory = sm.localPlayer.getPlayer():getInventory()
				local availableKits = sm.container.totalQuantity( inventory, obj_consumable_component )
				local upgradeData = { cost = level.cost, available = availableKits }
				self.upgradeGui:setData( "Upgrade", upgradeData )
				self.upgradeGui:setVisible( "Upgrade", true )
			else
				self.upgradeGui:setVisible( "Upgrade", false )
			end
		end
	end
end

function Seat_Expanded.cl_onUpgradeClicked( self, buttonName )
	self.network:sendToServer("sv_n_tryUpgrade", sm.localPlayer.getPlayer() )
end

function Seat_Expanded.cl_n_onUpgrade( self, upgrade )
	local level = self.Levels[tostring( upgrade )]

	if self.upgradeGui and self.upgradeGui:isActive() then
		self.upgradeGui:setIconImage( "Icon", upgrade )

		if sm.game.getEnableUpgrade() and level.cost then
			local inventory = sm.localPlayer.getPlayer():getInventory()
			local availableKits = sm.container.totalQuantity( inventory, obj_consumable_component )
			local upgradeData = { cost = level.cost, available = availableKits }
			self.upgradeGui:setData( "Upgrade", upgradeData )
			self.upgradeGui:setVisible( "Upgrade", true )
		else
			self.upgradeGui:setVisible( "Upgrade", false )
		end

		self.upgradeGui:setText( "SubTitle", level.title )

		if level.upgrade then
			self.upgradeGui:setIconImage( "UpgradeIcon", level.upgrade )

			local nextLevel = self.Levels[ tostring( level.upgrade ) ]
			local infoData = { Connections = nextLevel.maxConnections - level.maxConnections }

			if nextLevel.allowAdjustingJoints ~= nil then
				if nextLevel.allowAdjustingJoints == true then
					infoData.Settings = "#{UNLOCKED}"
				end
			end
			self.upgradeGui:setData( "UpgradeInfo", infoData )
		else
			self.upgradeGui:setVisible( "UpgradeIcon", false )
		end
	end

	sm.effect.playHostedEffect( "Part - Upgrade", self.interactable )
end

function Seat_Expanded.client_onAction( self, controllerAction, state )
	local consumeAction = true
	if state == true then
		if controllerAction == sm.interactable.actions.jump then
			self.selectedHotbar = self.selectedHotbar < 2 and self.selectedHotbar + 1 or 0
			sm.gui.displayAlertText("Selected hotbar: "..self.selectedHotbar + 1, 2.5)
		end

		if controllerAction == sm.interactable.actions.use --[[or controllerAction == sm.interactable.actions.jump]] then
			self:cl_seat()
		elseif controllerAction == sm.interactable.actions.item0 or controllerAction == sm.interactable.actions.create then
			self.interactable:pressSeatInteractable( self:getChildIndex(1) )
		elseif controllerAction == sm.interactable.actions.item1 or controllerAction == sm.interactable.actions.attack then
			self.interactable:pressSeatInteractable( self:getChildIndex(2) )
		elseif controllerAction == sm.interactable.actions.item2 then
			self.interactable:pressSeatInteractable( self:getChildIndex(3) )
		elseif controllerAction == sm.interactable.actions.item3 then
			self.interactable:pressSeatInteractable( self:getChildIndex(4) )
		elseif controllerAction == sm.interactable.actions.item4 then
			self.interactable:pressSeatInteractable( self:getChildIndex(5) )
		elseif controllerAction == sm.interactable.actions.item5 then
			self.interactable:pressSeatInteractable( self:getChildIndex(6) )
		elseif controllerAction == sm.interactable.actions.item6 then
			self.interactable:pressSeatInteractable( self:getChildIndex(7) )
		elseif controllerAction == sm.interactable.actions.item7 then
			self.interactable:pressSeatInteractable( self:getChildIndex(8) )
		elseif controllerAction == sm.interactable.actions.item8 then
			self.interactable:pressSeatInteractable( self:getChildIndex(9) )
		elseif controllerAction == sm.interactable.actions.item9 then
			self.interactable:pressSeatInteractable( self:getChildIndex(10) )
		else
			consumeAction = false
		end
	else
		if controllerAction == sm.interactable.actions.item0 or controllerAction == sm.interactable.actions.create then
			self.interactable:releaseSeatInteractable( self:getChildIndex(1) )
		elseif controllerAction == sm.interactable.actions.item1 or controllerAction == sm.interactable.actions.attack then
			self.interactable:releaseSeatInteractable( self:getChildIndex(2) )
		elseif controllerAction == sm.interactable.actions.item2 then
			self.interactable:releaseSeatInteractable( self:getChildIndex(3) )
		elseif controllerAction == sm.interactable.actions.item3 then
			self.interactable:releaseSeatInteractable( self:getChildIndex(4) )
		elseif controllerAction == sm.interactable.actions.item4 then
			self.interactable:releaseSeatInteractable( self:getChildIndex(5) )
		elseif controllerAction == sm.interactable.actions.item5 then
			self.interactable:releaseSeatInteractable( self:getChildIndex(6) )
		elseif controllerAction == sm.interactable.actions.item6 then
			self.interactable:releaseSeatInteractable( self:getChildIndex(7) )
		elseif controllerAction == sm.interactable.actions.item7 then
			self.interactable:releaseSeatInteractable( self:getChildIndex(8) )
		elseif controllerAction == sm.interactable.actions.item8 then
			self.interactable:releaseSeatInteractable( self:getChildIndex(9) )
		elseif controllerAction == sm.interactable.actions.item9 then
			self.interactable:releaseSeatInteractable( self:getChildIndex(10) )
		else
			consumeAction = false
		end
	end
	return consumeAction
end

function Seat_Expanded.client_getAvailableChildConnectionCount( self, connectionType )
	local level = self.Levels[tostring( self.shape:getShapeUuid() )]
	assert(level)
	local maxButtonCount = level.maxConnections or 255
	return maxButtonCount - #self.interactable:getChildren( sm.interactable.connectionType.seated )
end

function Seat_Expanded:getChildIndex(child)
	local interactables = {}
	local colour = colPerHotbar[self.selectedHotbar]
	for k, v in pairs(self.interactable:getSeatInteractables()) do
		local shape = v.shape
		local shapeCol = shape.color
		if shapeCol == colour then
			table.insert(interactables, k)
		end
	end

	local index = interactables[child]
	return index and index - 1 or -1
end

Saddle = class( Seat_Expanded )
Saddle.Levels = {
	["d5c819fa-fd10-4b27-8bf4-c030b74c8b06"] = { maxConnections = 10, title = "#{LEVEL} 5" },
}