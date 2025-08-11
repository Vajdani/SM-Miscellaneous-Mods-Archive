---@class UK_Projectile
---@field pos Vec3
---@field dir Vec3
---@field stats table
---@field target Shape|Character|Body
---@field lifeTime number
---@field hitbox AreaTrigger
---@field effect Effect
---@field name string


---@class ProjectileManager : ScriptableObjectClass
ProjectileManager = class()
ProjectileManager.isSaveObject = true

g_projectileDatabase = sm.json.open("$CONTENT_DATA/Scripts/projectileDatabase.json")
ProjectileManager.onHitFunctions = {
    ["coin"] = function( contents, result )
        for k, v in pairs(contents) do
            if type(v) ~= "Character" then
                return true
            end
        end

        return result.type ~= "unknown" and result.type ~= "character"
    end
}

function ProjectileManager:server_onCreate()
    print("ProjectileManager:server_onCreate")

    self.sv = {}
    self.sv.projectiles = {} --self.storage:load() or {}

    if #self.sv.projectiles > 0 then
        self.network:sendToClients("cl_loadProjectilesFromStorage", self.sv.projectiles)
    end
end

function ProjectileManager:sv_createProjectile( args )
    local projectileData = g_projectileDatabase[args.name]

    if not projectileData then
        sm.log.error("ProjectileManager: Failed to create projectile, invalid name!")
        return
    end

    local projectile = {
        name = args.name,
        pos = args.pos,
        dir = args.dir,
        stats = projectileData.stats,
        target = projectileData.homing and args.target or nil,
        lifeTime = 0
    }
    self.sv.projectiles[#self.sv.projectiles+1] = projectile
    self.storage:save(self.sv.projectiles)

    projectileData.name = args.name
    self.network:sendToClients("cl_createProjectile", { args = args, projData = projectileData })
end

function ProjectileManager:server_onFixedUpdate( dt )
    for k, projectile in pairs(self.sv.projectiles) do
        ---@type UK_Projectile
        local cl_proj = self.cl.projectiles[k]
        projectile.lifeTime = projectile.lifeTime + dt

        local contents = cl_proj.hitbox:getContents()
        local hit, result = sm.physics.raycast(cl_proj.pos, cl_proj.pos + cl_proj.dir / 2)
        local onHit = self.onHitFunctions[projectile.name]
        local shouldDelete = #contents > 0 or hit
        if onHit ~= nil then
            shouldDelete = onHit( contents, result )
        end

        if projectile.lifeTime >= projectile.stats.maxLifeTime or shouldDelete then
            for i, obj in pairs(contents) do
                if type(obj) == "Character" then
                    --apply damage
                end
            end

            local raycastHit = result:getCharacter()
            if not isAnyOf(raycastHit, contents) then
                --appply damage
            end

            sm.effect.playEffect("Part - Upgrade", cl_proj.pos)

            self.sv.projectiles[k] = nil
            self.network:sendToClients("cl_destroyProjectile", k)
        end
    end
end




function ProjectileManager:client_onCreate()
    print("ProjectileManager:client_onCreate")

    self.cl = {}
    self.cl.projectiles = {}
end

function ProjectileManager:cl_loadProjectilesFromStorage( data )

end

function ProjectileManager:cl_createProjectile( data )
    local projectileData = data.projData
    local args = data.args
    local scale = TableToVec3(projectileData.hitbox)
    local rot = sm.vec3.getRotation( sm.vec3.new(0,1,0), args.dir )

    local projectile = {
        hitbox = sm.areaTrigger.createBox( scale / 8, args.pos, rot, -1, { type = projectileData.name } ),
        effect = sm.effect.createEffect("ShapeRenderable"),
        pos = args.pos,
        dir = args.dir,
        stats = projectileData.stats,
        target = projectileData.homing and args.target or nil
    }

    projectile.effect:setParameter("uuid", sm.uuid.new("77331e1a-0b07-427c-acdd-2d090db5c08d"))
    projectile.effect:setPosition(args.pos)
    projectile.effect:setRotation(rot)
    projectile.effect:setScale(scale / 4)
    projectile.effect:start()

    self.cl.projectiles[#self.cl.projectiles+1] = projectile
end

function ProjectileManager:cl_destroyProjectile( index )
    local projectile = self.cl.projectiles[index]
    sm.areaTrigger.destroy(projectile.hitbox)
    projectile.effect:destroy()
    self.cl.projectiles[index] = nil

    print("projectile destroyed")
end

function ProjectileManager:client_onUpdate( dt )
    local adjust = dt / (1/40)

    for k, projectile in pairs(self.cl.projectiles) do
        local stats = projectile.stats

        if stats.hasGravity then projectile.dir.z = sm.util.clamp(projectile.dir.z - dt, -1, 1) end

        projectile.pos = projectile.pos + projectile.dir * stats.velocity * adjust
        projectile.effect:setPosition(projectile.pos)
        projectile.hitbox:setWorldPosition(projectile.pos)
    end
end