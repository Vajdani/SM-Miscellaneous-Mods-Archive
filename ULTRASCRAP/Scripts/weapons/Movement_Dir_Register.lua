Movement_Dir_Register = class()

function Movement_Dir_Register:client_onCreate()
    local player = sm.localPlayer.getPlayer()
    player.clientPublicData = player.clientPublicData or {}
    self.public = player.clientPublicData
end

function Movement_Dir_Register:client_onUpdate()
    self.public.movementDir = self.tool:getRelativeMoveDirection()
end