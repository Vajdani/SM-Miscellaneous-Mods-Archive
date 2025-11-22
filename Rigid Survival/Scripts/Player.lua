dofile "$SURVIVAL_DATA/Scripts/game/SurvivalPlayer.lua"

Player = class( SurvivalPlayer )

function Player.server_onCreate( self )
    SurvivalPlayer.server_onCreate( self )
	print("Player.server_onCreate")
end

function Player:client_onCreate()
    SurvivalPlayer.client_onCreate( self )

    --Doesn't work! Thank you Axolot Games!
    g_survivalHud:setText("LogbookBinding", sm.gui.getKeyBinding("Reload", false))

    sm.gui.chatMessage(("#00ff00The logbook can be opened with your reload key.\n\t#ffffffDefault binding: #df7f00R\n\t#ffffffCurrent binding: #df7f00%s"):format(sm.gui.getKeyBinding("Reload", false)))
end

function Player:client_onReload()
    sm.tool.forceTool(g_lobook)

    return true
end