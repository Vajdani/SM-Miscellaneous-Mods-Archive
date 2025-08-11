Game = class( nil )
Game.enableLimitedInventory = false

dofile( "$SURVIVAL_DATA/Scripts/game/managers/UnitManager.lua" )
dofile "$CONTENT_DATA/Scripts/managers/ProjectileManager.lua"

g_detonateAbleObjects = {
    sm.uuid.new("77331e1a-0b07-427c-acdd-2d090db5c08d")
}
g_cores = {}


function Game.server_onCreate( self )
	print("Game.server_onCreate")
    self.sv = {}
	self.sv.saved = self.storage:load()
    if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.world = sm.world.createWorld( "$CONTENT_DATA/Scripts/World.lua", "World" )
		self.storage:save( self.sv.saved )
	end

    g_unitManager = UnitManager()
	g_unitManager:sv_onCreate( nil, { aggroCreations = true } )
end

function Game.server_onPlayerJoined( self, player, isNewPlayer )
    print("Game.server_onPlayerJoined")
    if isNewPlayer then
        if not sm.exists( self.sv.saved.world ) then
            sm.world.loadWorld( self.sv.saved.world )
        end
        self.sv.saved.world:loadCell( 0, 0, player, "sv_createPlayerCharacter" )
    end

	g_unitManager:sv_onPlayerJoined( player )
end

function Game.sv_createPlayerCharacter( self, world, x, y, player, params )
    local character = sm.character.createCharacter( player, world, sm.vec3.new( 32, 32, 5 ), 0, 0 )
	player:setCharacter( character )
end

function Game:server_onFixedUpdate( dt )
	g_unitManager:sv_onFixedUpdate()
end



function Game:client_onCreate()
    if g_unitManager == nil then
        assert( not sm.isHost )
        g_unitManager = UnitManager()
    end
    g_unitManager:cl_onCreate()
end