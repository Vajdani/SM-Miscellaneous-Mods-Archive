Game = class( nil )
Game.enableLimitedInventory = true
Game.enableRestrictions = true
Game.enableFuelConsumption = false
Game.enableAmmoConsumption = false
Game.enableUpgrade = false

dofile( "$SURVIVAL_DATA/Scripts/game/managers/UnitManager.lua" )

g_disableScrapHarvest = true
g_weaponUUIDs = {
    hammer = sm.uuid.new("bb641a4f-e391-441c-bc6d-0ae21a069476"),
    spudgun = sm.uuid.new("c5ea0c2f-185b-48d6-b4df-45c386a575cc"),
    shotgun = sm.uuid.new("f6250bf4-9726-406f-a29a-945c06e460e5"),
    gatling = sm.uuid.new("9fde0601-c2ba-4c70-8d5c-2a7a9fdd122b"),

	grenadelauncher = sm.uuid.new("204ccb8b-14e7-44c4-b979-9b11c4269533")
}
g_weaponUUIDs_reverse = {
    ["bb641a4f-e391-441c-bc6d-0ae21a069476"] = "hammer",
    ["c5ea0c2f-185b-48d6-b4df-45c386a575cc"] = "spudgun",
    ["f6250bf4-9726-406f-a29a-945c06e460e5"] = "shotgun",
    ["9fde0601-c2ba-4c70-8d5c-2a7a9fdd122b"] = "gatling",

	["204ccb8b-14e7-44c4-b979-9b11c4269533"] = "grenadelauncher"
}
g_weaponToAmmoType = {
    spudgun = "rounds",
    shotgun = "shells",
    gatling = "rounds",
    plasmarifle = "cells",
    railcannon = "cells",
    grenadelauncher = "grenades",
    rocketlauncher = "rockets"
}
g_ammoPickupAmounts = {
    rounds = 50,
    shells = 8,
    cells = 100,
    grenades = 6,
    rockets = 5
}

function Game.server_onCreate( self )
	print("Game.server_onCreate")

    g_arenaData = sm.json.open("$CONTENT_DATA/Scripts/arenas.json")
    g_currentArena = sm.storage.load( "CURRENTARENA" ) or 1
    g_respawnPoints = g_arenaData[g_currentArena].respawnPoints

    self.sv = {}
	self.sv.saved = self.storage:load()
    if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.world = sm.world.createWorld( "$CONTENT_DATA/Scripts/World.lua", "World" )
        self.sv.saved.world:setTerrainScriptData( { path = g_arenaData[g_currentArena].path } )
		self.storage:save( self.sv.saved )
	end

	g_unitManager = UnitManager()
	g_unitManager:sv_onCreate( self.sv.saved.overworld )
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

function Game.sv_createPlayerCharacter( self, world, x, y, player, params )
    local character = sm.character.createCharacter( player, world, sm.vec3.new( 32, 32, 5 ), 0, 0 )
	player:setCharacter( character )
end

function Game:sv_sendPlayerEvent( data, caller )
    sm.event.sendToPlayer( caller, data.event, data.args )
end

function Game:sv_changeArenaTo( index )
	g_currentArena = index
	sm.storage.save( "CURRENTARENA", g_currentArena )

	--thanks MrCrackx for the kewl coed
	local newWorld = sm.world.createWorld( "$CONTENT_DATA/Scripts/World.lua", "World" )
	local arena = g_arenaData[g_currentArena]
	newWorld:setTerrainScriptData( { path = arena.path } )

	if not sm.exists( newWorld ) then
		sm.world.loadWorld( newWorld )
	end

	for k, player in pairs( sm.player.getAllPlayers() ) do
		local playerChar = player:getCharacter()
		if sm.exists( playerChar ) then
			local newChar = sm.character.createCharacter( player, newWorld, sm.vec3.new( 32, 32, 5 ), _, _, playerChar )
			player:setCharacter( nil )
			player:setCharacter( newChar )
		end
	end

	self.sv.saved.world:destroy()
	self.sv.saved.world = newWorld

	self.storage:save( self.sv.saved )
end

function Game:sv_recreatePickps()
	sm.event.sendToWorld( self.sv.saved.world, "sv_deletePickups" )
	sm.event.sendToWorld( self.sv.saved.world, "sv_createPickups" )
end

function Game:sv_toggleInv()
	sm.game.setLimitedInventory( not sm.game.getLimitedInventory() )
end



function Game:client_onCreate()
    self:cl_bindCommands()
end

function Game:cl_bindCommands()
	sm.game.bindChatCommand( "/die", {}, "cl_command_die", "Kill player" )
	sm.game.bindChatCommand( "/setStats", { { "int", "health", false }, { "int", "armour", false } }, "cl_command_stats", "Set player stats" )
	sm.game.bindChatCommand( "/setHazard", { { "string", "hazard", false } }, "cl_command_hazard", "Set player hazard" )
    sm.game.bindChatCommand( "/arena", { { "int", "wave", true } }, "cl_command_arena", "load into another arena" )
    sm.game.bindChatCommand( "/rpickup", {}, "cl_command_recreatePickups", "Recreate pickups" )
    sm.game.bindChatCommand( "/inv", {}, "cl_command_toggleInv", "Toggle unlimited inventory" )
end

function Game:cl_command_die()
    self.network:sendToServer("sv_sendPlayerEvent", { event = "sv_takeDamage", args = { damage = 999, source = "Game" } })
end

function Game:cl_command_stats( params )
    self.network:sendToServer("sv_sendPlayerEvent", { event = "sv_setStats", args = { health = params[2], armour = params[3] } })
end

function Game:cl_command_hazard( params )
    self.network:sendToServer("sv_sendPlayerEvent", { event = "sv_setHazard", args = params[2] })
end

function Game:cl_command_arena( params )
    print(#g_arenaData)
	if g_arenaData == nil or #g_arenaData == 0 then
		return
	end

    if g_currentArena == params[2] then return end

    if params[2] <= #g_arenaData and params[2] > 0 then
		self.network:sendToServer( "sv_changeArenaTo", params[2] )
	else
		sm.gui.displayAlertText("Invalid arena index specified! It must be between #df7f001 #ffffffand #df7f00"..tostring(#g_arenaData), 5)
	end
end

function Game:cl_command_recreatePickups()
	self.network:sendToServer( "sv_recreatePickps" )
end

function Game:cl_command_toggleInv()
	self.network:sendToServer( "sv_toggleInv" )
end