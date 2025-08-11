dofile "$SURVIVAL_DATA/Scripts/game/SurvivalGame.lua"

Game = class( SurvivalGame )

function Game.server_onCreate( self )
    SurvivalGame.server_onCreate( self )
	print("Game.server_onCreate")
end
