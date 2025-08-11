function Init()
	print( "Init terrain" )
end

function Create( xMin, xMax, yMin, yMax, seed, data )
	-- g_cellData = {
	-- 	bounds = { xMin = xMin, xMax = xMax, yMin = yMin, yMax = yMax },
	-- 	seed = seed,
	-- }
end

function Load()
	return false
end

function GetHeightAt( x, y, lod )
	return 0
end

function GetColorAt( x, y, lod )
	local cell_x, cell_y = math.floor(x / 64), math.floor(y / 64)
	local colour = (cell_x ~= 0 or cell_y ~= 0) and 0.5 or 1
	return colour, colour, colour
end

function GetMaterialAt( x, y, lod )
	return 1, 0, 0, 0, 0, 0, 0, 0
end