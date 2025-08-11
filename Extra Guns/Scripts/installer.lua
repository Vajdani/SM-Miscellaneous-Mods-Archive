Installer = class()

function Installer:client_canInteract()
	sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Use" ), "Install extra guns" )
	sm.gui.setInteractionText( "", sm.gui.getKeyBinding( "Tinker" ), "Uninstall extra guns" )

    return true
end

function Installer:client_onInteract()
    local data = sm.json.open( "$CONTENT_8103353f-b3d7-4a52-8cbf-fddcb5b8ae92/json/new_spudguns.json" )
    sm.json.save( data, "$SURVIVAL_DATA/Tools/ToolSets/spudguns.json" )

    local descriptions = sm.json.open( "$CONTENT_8103353f-b3d7-4a52-8cbf-fddcb5b8ae92/json/new_descriptions.json" )
    sm.json.save( descriptions, "$SURVIVAL_DATA/Gui/Language/English/inventoryDescriptions.json" )

    self.network:sendToServer("sv_displayMsg", "Extra guns #ff9d00installed")
end

function Installer:client_onTinker()
    local data = sm.json.open( "$CONTENT_8103353f-b3d7-4a52-8cbf-fddcb5b8ae92/json/default_spudguns.json" )
    sm.json.save( data, "$SURVIVAL_DATA/Tools/ToolSets/spudguns.json" )

    local descriptions = sm.json.open( "$CONTENT_8103353f-b3d7-4a52-8cbf-fddcb5b8ae92/json/default_descriptions.json" )
    sm.json.save( descriptions, "$SURVIVAL_DATA/Gui/Language/English/inventoryDescriptions.json" )

    self.network:sendToServer("sv_displayMsg", "Extra guns #ff9d00uninstalled")
end

function Installer:sv_displayMsg( msg )
    self.network:sendToClients("cl_displayMsg", msg)
end

function Installer:cl_displayMsg( msg )
    sm.gui.displayAlertText(msg.."#ffffff! Rejoin the world for it to take effect!", 2.5)
end