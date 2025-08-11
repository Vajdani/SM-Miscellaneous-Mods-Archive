if not GasEngine then
    dofile "$SURVIVAL_DATA/Scripts/game/interactables/GasEngine.lua"
end

function GasEngine.cl_onSliderChange( self, sliderPos )
	self.network:sendToServer( "sv_setGear", sliderPos + 1 )
	self.client_gearIdx = sliderPos + 1
end