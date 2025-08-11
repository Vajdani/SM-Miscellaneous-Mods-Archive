---@class Canvas : ShapeClass
Canvas = class()

dofile "$CONTENT_DATA/Scripts/drawUtils.lua"

local scale = sm.vec3.one() / 8
local thickness = 1 / 8

function Canvas:server_onCreate()
    self.saved = self.storage:load() or {}
    if #self.saved > 0 then
        --self.network:sendToClients( "cl_loadSavedDrawing", self.saved )
        --we do a little network spamming :trollos:
        for k, v in pairs(self.saved) do
            v.spawn = true
            self.network:sendToClients("cl_onDraw", v )
        end
    end
end

function Canvas:sv_onDraw( data )
    self.saved[#self.saved+1] = data
    self.storage:save( self.saved )
    self.network:sendToClients("cl_onDraw", data)
end

function Canvas:sv_onClear()
    self.saved = {}
    self.storage:save( self.saved )
    self.network:sendToClients("cl_onClear")
end



function Canvas:client_onCreate()
    self.effects = {}
end

function Canvas:cl_loadSavedDrawing( data )
    for k, v in pairs(data) do
        self:cl_onDraw( v )
    end
end

function Canvas:cl_onDraw( args )
    local effect = sm.effect.createEffect( "ShapeRenderable", self.interactable )
    effect:setParameter("uuid", args.uuid)

    local pos = args.pos
    local shape = self.shape
    if type(pos) == "Vec3" then
        effect:setOffsetPosition( pos )
        effect:setScale(scale * sm.vec3.new(1, args.size.y, args.size.x))

        if args.rot then
            local default = shape.up
            if args.rot == 180 then
                effect:setOffsetRotation(shape:transformRotation(BetterGetRotation(-default, shape.at)))
            elseif args.rot ~= 0 then
                local rot = BetterGetRotation(
                    default:rotate( -math.rad(args.rot), shape.right ),
                    default
                )
                effect:setOffsetRotation(shape:transformRotation(rot))
            end
        end

        if not args.spawn then
            local worldPos = shape:transformLocalPoint(pos)
            sm.particle.createParticle("paint_smoke", worldPos, sm.quat.identity(), args.colour)
	        sm.audio.play("PaintTool - Paint", worldPos)
        end
    else
        ---@type Vec3, Vec3
        local startPos, endPos = pos.startPoint, pos.endPoint
        local delta = endPos - startPos
        local length = delta:length()

        local rot = sm.quat.identity()
        if length > 0 then
            local delta2 = shape:transformLocalPoint(endPos) - shape:transformLocalPoint(startPos)
            rot = BetterGetRotation(delta2, shape.at)
        end

        local distance = sm.vec3.new(thickness, thickness * args.size.y, length == 0 and thickness or length)
        effect:setOffsetPosition(startPos + delta * 0.5)
        effect:setScale(distance)
        effect:setOffsetRotation(shape:transformRotation(rot))

        if not args.spawn then
            local worldStart, worldEnd = shape:transformLocalPoint(startPos), shape:transformLocalPoint(endPos)
            local cycles = round(length) * 5
            for i = 1, cycles do
                sm.particle.createParticle( "paint_smoke", sm.vec3.lerp(worldStart, worldEnd, i / cycles), sm.quat.identity(), args.colour)
            end

	        sm.audio.play("PaintTool - Paint", worldStart)
        end
    end

    effect:setParameter("color", args.colour)
    effect:start()


    self.effects[#self.effects+1] = effect
end

function Canvas:cl_onClear()
    for k, v in pairs(self.effects) do
        v:destroy()
    end

    self.effects = {}
end