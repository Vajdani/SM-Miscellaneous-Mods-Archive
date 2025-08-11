---@class World : WorldClass
World = class()
World.terrainScript = "$CONTENT_DATA/Scripts/terrain.lua"
-- World.groundMaterialSet = "$CONTENT_DATA/Terrain/materialset.json"
World.cellMinX = 0
World.cellMaxX = 0
World.cellMinY = 0
World.cellMaxY = 0
World.worldBorder = true
World.enableAssets = false
World.enableClutter = false
World.enableHarvestables = false
World.enableCreations = false
World.enableKinematics = false
World.enableNodes = false
World.enableSurface = true
World.isStatic = true

function World:server_onCreate()
    print("World.server_onCreate")
end