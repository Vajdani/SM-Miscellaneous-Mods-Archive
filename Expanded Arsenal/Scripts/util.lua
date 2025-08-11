function GetRot( forward, up )
    local vector = sm.vec3.normalize( forward )
    local vector2 = sm.vec3.normalize( sm.vec3.cross( up, vector ) )
    local vector3 = sm.vec3.cross( vector, vector2 )
    local m00 = vector2.x
    local m01 = vector2.y
    local m02 = vector2.z
    local m10 = vector3.x
    local m11 = vector3.y
    local m12 = vector3.z
    local m20 = vector.x
    local m21 = vector.y
    local m22 = vector.z
    local num8 = (m00 + m11) + m22
    local quaternion = sm.quat.identity()
    if num8 > 0 then
        local num = math.sqrt(num8 + 1)
        quaternion.w = num * 0.5
        num = 0.5 / num
        quaternion.x = (m12 - m21) * num
        quaternion.y = (m20 - m02) * num
        quaternion.z = (m01 - m10) * num
        return quaternion
    end
    if (m00 >= m11) and (m00 >= m22) then
        local num7 = math.sqrt(((1 + m00) - m11) - m22)
        local num4 = 0.5 / num7
        quaternion.x = 0.5 * num7
        quaternion.y = (m01 + m10) * num4
        quaternion.z = (m02 + m20) * num4
        quaternion.w = (m12 - m21) * num4
        return quaternion
    end
    if m11 > m22 then
        local num6 = math.sqrt(((1 + m11) - m00) - m22)
        local num3 = 0.5 / num6
        quaternion.x = (m10+ m01) * num3
        quaternion.y = 0.5 * num6
        quaternion.z = (m21 + m12) * num3
        quaternion.w = (m20 - m02) * num3
        return quaternion
    end
    local num5 = math.sqrt(((1 + m22) - m00) - m11)
    local num2 = 0.5 / num5
    quaternion.x = (m20 + m02) * num2
    quaternion.y = (m21 + m12) * num2
    quaternion.z = 0.5 * num5;
    quaternion.w = (m01 - m10) * num2
    return quaternion
end

function _createTpAnimations( tool, animationMap )
	local data = {}
	data.tool = tool
	data.animations = {}

	for name, pair in pairs(animationMap) do

		local animation = {
			info = tool:getAnimationInfo(pair[1]),
			time = 0.0,
			weight = 0.0,
			playRate = pair[2] and pair[2].playRate or 1.0,
			looping =  pair[2] and pair[2].looping or false,
			nextAnimation = pair[2] and pair[2].nextAnimation or nil,
			blendNext = pair[2] and pair[2].blendNext or 0.0
		}

		if pair[2] and pair[2].dirs then
			animation.dirs = {
				up = tool:getAnimationInfo(pair[2].dirs.up),
				fwd = tool:getAnimationInfo(pair[2].dirs.fwd),
				down = tool:getAnimationInfo(pair[2].dirs.down)
			}
		end

		if pair[2] and pair[2].crouch then
			animation.crouch = tool:getAnimationInfo(pair[2].crouch)
		end

		if animation.info == nil then
			print("Error: failed to get third person animation info for: ", pair[1])
			animation.info = {name = name, duration = 1.0, looping = false }
		end

		data.animations[name] = animation;
	end
	data.blendSpeed = 0.0
	data.currentAnimation = ""
	return data
end