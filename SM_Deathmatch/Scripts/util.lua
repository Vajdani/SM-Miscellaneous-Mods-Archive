dofile "$SURVIVAL_DATA/Scripts/game/survival_items.lua"

vector_up = sm.vec3.new(0,0,1)
axis_y = sm.vec3.new(0,1,0)

--GUI
function interactionWrap( text, colourStr )
    return string.format("<p textShadow='false' bg='gui_keybinds_bg_orange' color='%s' spacing='9'>%s</p>", colourStr or "#4f4f4f", text )
end

--General Util
function tableToVec3( table )
    return sm.vec3.new(table.x or 0, table.y or 0, table.z or 0)
end

g_toolItems = {
	[tostring( tool_spudgun )] = obj_tool_spudgun,
	[tostring( tool_shotgun )] = obj_tool_frier,
	[tostring( tool_gatling )] = obj_tool_spudling,

	[tostring(g_weaponUUIDs.grenadelauncher)] = obj_tool_spudgun
}
function GetToolItemUUID( toolUuid )
	return g_toolItems[tostring( toolUuid )]
end

function randomInvert( val, chance )
	if math.random() <= chance then
		return -val
	end

	return val
end

--Thanks Nick
function getYawPitch( direction )
    return math.atan2(direction.y, direction.x) - math.pi/2, math.asin(direction.z)
end