World = class( nil )
World.terrainScript = "$CONTENT_DATA/Scripts/terrain.lua"
World.cellMinX = -2
World.cellMaxX = 1
World.cellMinY = -2
World.cellMaxY = 1
World.worldBorder = true

function World.server_onCreate( self )
    print("World.server_onCreate")

    local storage = self.storage:load() or {}
    local loadedManager = storage.projManager
    g_ProjectileManager = loadedManager or sm.scriptableObject.createScriptableObject( sm.uuid.new("45ce3208-fd94-4471-bf7f-e81b516e83e9"), {}, self.world )

    if g_ProjectileManager ~= loadedManager then --first time load of world
        storage.projManager = g_ProjectileManager
        self.storage:save( storage )
    end
end