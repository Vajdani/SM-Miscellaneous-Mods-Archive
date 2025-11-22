dofile "$SURVIVAL_DATA/Scripts/game/SurvivalGame.lua"

Game = class( SurvivalGame )

function Game.server_onCreate( self )
	print( "SurvivalGame.server_onCreate" )
	self.sv = {}
	self.sv.saved = self.storage:load()
	print( "Saved:", self.sv.saved )
	if self.sv.saved == nil then
		self.sv.saved = {}
		self.sv.saved.data = self.data
		printf( "Seed: %.0f", self.sv.saved.data.seed )
		self.sv.saved.overworld = sm.world.createWorld( "$SURVIVAL_DATA/Scripts/game/worlds/Overworld.lua", "Overworld", { dev = self.sv.saved.data.dev }, self.sv.saved.data.seed )
		self.storage:save( self.sv.saved )
	end
	self.data = nil

	print( self.sv.saved.data )
	-- if self.sv.saved.data and self.sv.saved.data.dev then
	-- 	g_godMode = true
	-- 	g_survivalDev = true
	-- 	sm.log.info( "Starting SurvivalGame in DEV mode" )
	-- end

	self:loadCraftingRecipes()
	g_enableCollisionTumble = true

	g_eventManager = EventManager()
	g_eventManager:sv_onCreate()

	g_elevatorManager = ElevatorManager()
	g_elevatorManager:sv_onCreate()






	g_respawnManager = RespawnManager()
	g_respawnManager:sv_onCreate( self.sv.saved.overworld )

	g_beaconManager = BeaconManager()
	g_beaconManager:sv_onCreate()

	g_unitManager = UnitManager()
	g_unitManager:sv_onCreate( self.sv.saved.overworld )

	self.sv.questEntityManager = sm.scriptableObject.createScriptableObject( sm.uuid.new( "c6988ecb-0fc1-4d45-afde-dc583b8b75ee" ) )

	self.sv.questManager = sm.storage.load( STORAGE_CHANNEL_QUESTMANAGER )
	if not self.sv.questManager then
		self.sv.questManager = sm.scriptableObject.createScriptableObject( sm.uuid.new( "83b0cc7e-b164-47b8-a83c-0d33ba5f72ec" ) )
		sm.storage.save( STORAGE_CHANNEL_QUESTMANAGER, self.sv.questManager )
	end





	-- Game script managed global warehouse table
	self.sv.warehouses = sm.storage.load( STORAGE_CHANNEL_WAREHOUSES )
	if self.sv.warehouses then
		print( "Loaded warehouses:" )
		print( self.sv.warehouses )
	else
		self.sv.warehouses = {}
		sm.storage.save( STORAGE_CHANNEL_WAREHOUSES, self.sv.warehouses )
	end












	self.sv.time = sm.storage.load( STORAGE_CHANNEL_TIME )
	if self.sv.time then
		print( "Loaded timeData:" )
		print( self.sv.time )
	else
		self.sv.time = {}
		self.sv.time.timeOfDay = 6 / 24 -- 06:00
		self.sv.time.timeProgress = true
		sm.storage.save( STORAGE_CHANNEL_TIME, self.sv.time )
	end
	self.network:setClientData( { dev = g_survivalDev }, 1 )
	self:sv_updateClientData()

	self.sv.syncTimer = Timer()
	self.sv.syncTimer:start( 0 )
end

function Game.bindChatCommands( self )
	sm.game.bindChatCommand( "/ammo", { { "int", "quantity", true } }, "cl_onChatCommand", "Give ammo (default 50)" )
	sm.game.bindChatCommand( "/spudgun", {}, "cl_onChatCommand", "Give the spudgun" )
	sm.game.bindChatCommand( "/gatling", {}, "cl_onChatCommand", "Give the potato gatling gun" )
	sm.game.bindChatCommand( "/shotgun", {}, "cl_onChatCommand", "Give the fries shotgun" )
	sm.game.bindChatCommand( "/sunshake", {}, "cl_onChatCommand", "Give 1 sunshake" )
	sm.game.bindChatCommand( "/baguette", {}, "cl_onChatCommand", "Give 1 revival baguette" )
	sm.game.bindChatCommand( "/keycard", {}, "cl_onChatCommand", "Give 1 keycard" )
	sm.game.bindChatCommand( "/powercore", {}, "cl_onChatCommand", "Give 1 powercore" )
	sm.game.bindChatCommand( "/components", { { "int", "quantity", true } }, "cl_onChatCommand", "Give <quantity> components (default 10)" )
	sm.game.bindChatCommand( "/glowsticks", { { "int", "quantity", true } }, "cl_onChatCommand", "Give <quantity> components (default 10)" )
	sm.game.bindChatCommand( "/tumble", { { "bool", "enable", true } }, "cl_onChatCommand", "Set tumble state" )
	sm.game.bindChatCommand( "/god", {}, "cl_onChatCommand", "Mechanic characters will take no damage" )
	sm.game.bindChatCommand( "/respawn", {}, "cl_onChatCommand", "Respawn at last bed (or at the crash site)" )
	sm.game.bindChatCommand( "/encrypt", {}, "cl_onChatCommand", "Restrict interactions in all warehouses" )
	sm.game.bindChatCommand( "/decrypt", {}, "cl_onChatCommand", "Unrestrict interactions in all warehouses" )
	sm.game.bindChatCommand( "/limited", {}, "cl_onChatCommand", "Use the limited inventory" )
	sm.game.bindChatCommand( "/unlimited", {}, "cl_onChatCommand", "Use the unlimited inventory" )
	sm.game.bindChatCommand( "/ambush", { { "number", "magnitude", true }, { "int", "wave", true } }, "cl_onChatCommand", "Starts a 'random' encounter" )
	--sm.game.bindChatCommand( "/recreate", {}, "cl_onChatCommand", "Recreate world" )
	sm.game.bindChatCommand( "/timeofday", { { "number", "timeOfDay", true } }, "cl_onChatCommand", "Sets the time of the day as a fraction (0.5=mid day)" )
	sm.game.bindChatCommand( "/timeprogress", { { "bool", "enabled", true } }, "cl_onChatCommand", "Enables or disables time progress" )
	sm.game.bindChatCommand( "/day", {}, "cl_onChatCommand", "Disable time progression and set time to daytime" )
	sm.game.bindChatCommand( "/spawn", { { "string", "unitName", true }, { "int", "amount", true } }, "cl_onChatCommand", "Spawn a unit: 'woc', 'tapebot', 'totebot', 'haybot'" )
	sm.game.bindChatCommand( "/harvestable", { { "string", "harvestableName", true } }, "cl_onChatCommand", "Create a harvestable: 'tree', 'stone'" )
	sm.game.bindChatCommand( "/cleardebug", {}, "cl_onChatCommand", "Clear debug draw objects" )
	sm.game.bindChatCommand( "/import", { { "string", "name", false } }, "cl_onChatCommand", "Imports blueprint $SURVIVAL_DATA/LocalBlueprints/<name>.blueprint" )
	sm.game.bindChatCommand( "/starterkit", {}, "cl_onChatCommand", "Spawn a starter kit" )
	sm.game.bindChatCommand( "/mechanicstartkit", {}, "cl_onChatCommand", "Spawn a starter kit for starting at mechanic station" )
	sm.game.bindChatCommand( "/pipekit", {}, "cl_onChatCommand", "Spawn a pipe kit" )
	sm.game.bindChatCommand( "/foodkit", {}, "cl_onChatCommand", "Spawn a food kit" )
	sm.game.bindChatCommand( "/seedkit", {}, "cl_onChatCommand", "Spawn a seed kit" )
	sm.game.bindChatCommand( "/die", {}, "cl_onChatCommand", "Kill the player" )
	sm.game.bindChatCommand( "/sethp", { { "number", "hp", false } }, "cl_onChatCommand", "Set player hp value" )
	sm.game.bindChatCommand( "/setwater", { { "number", "water", false } }, "cl_onChatCommand", "Set player water value" )
	sm.game.bindChatCommand( "/setfood", { { "number", "food", false } }, "cl_onChatCommand", "Set player food value" )
	sm.game.bindChatCommand( "/aggroall", {}, "cl_onChatCommand", "All hostile units will be made aware of the player's position" )
	sm.game.bindChatCommand( "/goto", { { "string", "name", false } }, "cl_onChatCommand", "Teleport to predefined position" )
	sm.game.bindChatCommand( "/raid", { { "int", "level", false }, { "int", "wave", true }, { "number", "hours", true } }, "cl_onChatCommand", "Start a level <level> raid at player position at wave <wave> in <delay> hours." )
	sm.game.bindChatCommand( "/stopraid", {}, "cl_onChatCommand", "Cancel all incoming raids" )
	sm.game.bindChatCommand( "/disableraids", { { "bool", "enabled", false } }, "cl_onChatCommand", "Disable raids if true" )
	sm.game.bindChatCommand( "/camera", {}, "cl_onChatCommand", "Spawn a SplineCamera tool" )
	sm.game.bindChatCommand( "/noaggro", { { "bool", "enable", true } }, "cl_onChatCommand", "Toggles the player as a target" )
	sm.game.bindChatCommand( "/killall", {}, "cl_onChatCommand", "Kills all spawned units" )
	sm.game.bindChatCommand( "/printglobals", {}, "cl_onChatCommand", "Print all global lua variables" )
	sm.game.bindChatCommand( "/clearpathnodes", {}, "cl_onChatCommand", "Clear all path nodes in overworld" )
	sm.game.bindChatCommand( "/enablepathpotatoes", { { "bool", "enable", true } }, "cl_onChatCommand", "Creates path nodes at potato hits in overworld and links to previous node" )
	sm.game.bindChatCommand( "/activatequest",  { { "string", "name", true } }, "cl_onChatCommand", "Activate quest" )
	sm.game.bindChatCommand( "/completequest",  { { "string", "name", true } }, "cl_onChatCommand", "Complete quest" )
	sm.game.bindChatCommand( "/settilebool",  { { "string", "name", false }, { "bool", "value", false } }, "cl_onChatCommand", "Set named tile value at player position as a bool" )
	sm.game.bindChatCommand( "/settilefloat",  { { "string", "name", false }, { "number", "value", false } }, "cl_onChatCommand", "Set named tile value at player position as a floating point number" )
	sm.game.bindChatCommand( "/settilestring",  { { "string", "name", false }, { "string", "value", false } }, "cl_onChatCommand", "Set named tile value at player position as a bool" )
	sm.game.bindChatCommand( "/printtilevalues",  {}, "cl_onChatCommand", "Print all tile values at player position" )
	sm.game.bindChatCommand( "/reloadcell", {{ "int", "x", true }, { "int", "y", true }}, "cl_onChatCommand", "Reload cells at self or {x,y}" )
	sm.game.bindChatCommand( "/tutorialstartkit", {}, "cl_onChatCommand", "Spawn a starter kit for building a scrap car" )
end