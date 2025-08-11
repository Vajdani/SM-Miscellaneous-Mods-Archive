---@class RingManager : ToolClass
RingManager = class()

function RingManager:server_onCreate()
    g_ringManager = self.tool
    self.rings = sm.storage.load(4012) or {}
    self.network:sendToClients("cl_loadRings", self.rings)
end

function RingManager:sv_updateRing(player)
    for k, ringedPlayer in pairs(self.rings) do
        if ringedPlayer == player then
            self.network:sendToClients("cl_addRing", { player = player, state = false })
            table.remove(self.rings, k)
            sm.storage.save(4012, self.rings)
            return
        end
    end

    self.network:sendToClients("cl_addRing", { player = player, state = true })
    table.insert(self.rings, player)
    sm.storage.save(4012, self.rings)
end



function RingManager:client_onCreate()
    self.cl_rings = {}
end

function RingManager:cl_loadRings(rings)
    for k, player in pairs(rings) do
        self:cl_addRing({ player = player, state = true })
    end
end

local ringRend = "$CONTENT_DATA/Character/Char_ring/char_ring.rend"
function RingManager:cl_addRing(ring)
    local player = ring.player
    local character = player.character
    local state = ring.state

    player.clientPublicData.ringEquipped = state
    self.cl_rings[player.id] = state and { player = player, character = character } or nil

    if not sm.exists(character) then return end

    if ring.state then
        character:addRenderable(ringRend)
        if player == sm.localPlayer.getPlayer() then
            sm.localPlayer.addRenderable(ringRend)
        end
    else
        character:removeRenderable(ringRend)
        if player == sm.localPlayer.getPlayer() then
            sm.localPlayer.removeRenderable(ringRend)
        end
    end
end

function RingManager:client_onFixedUpdate()
    for k, data in pairs(self.cl_rings) do
        if not sm.exists(data.character) then
            self.cl_rings[k].character = data.player.character
        else
            if not data.character:getTpBoneRot( "jnt_ring" ) then
                self:cl_addRing({ player = data.player, state = true })
            end
        end
    end
end