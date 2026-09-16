local config = require(script.Parent:WaitForChild("GameConfig"))

local PlanetMath = {}

function PlanetMath.getTileCount()
	return config.TILE_ROWS * config.TILE_COLS
end

function PlanetMath.indexToRowCol(index)
	local row = math.floor(index / config.TILE_COLS)
	local col = index % config.TILE_COLS
	return row, col
end

function PlanetMath.rowColToIndex(row, col)
	return row * config.TILE_COLS + col
end

function PlanetMath.getDirection(index)
	local row, col = PlanetMath.indexToRowCol(index)
	local lat = math.rad(-90 + (row + 0.5) * (180 / config.TILE_ROWS))
	local lon = math.rad((col + 0.5) * (360 / config.TILE_COLS))
	local cosLat = math.cos(lat)
	return Vector3.new(
		cosLat * math.cos(lon),
		math.sin(lat),
		cosLat * math.sin(lon)
	).Unit
end

function PlanetMath.getCFrameFromNormal(pos, normal)
	local up = normal.Unit
	local right = Vector3.new(0, 1, 0):Cross(up)
	if right.Magnitude < 0.001 then
		right = Vector3.new(1, 0, 0):Cross(up)
	end
	right = right.Unit
	local forward = up:Cross(right)
	return CFrame.fromMatrix(pos, right, up, forward)
end

function PlanetMath.getTileCFrame(planetPosition, index, radius)
	local normal = PlanetMath.getDirection(index)
	local pos = planetPosition + normal * radius
	return PlanetMath.getCFrameFromNormal(pos, normal)
end

function PlanetMath.indexWithinRadius(indexA, indexB, radius)
	local rowA, colA = PlanetMath.indexToRowCol(indexA)
	local rowB, colB = PlanetMath.indexToRowCol(indexB)
	local rowDist = math.abs(rowA - rowB)
	local colDist = math.abs(colA - colB)
	colDist = math.min(colDist, config.TILE_COLS - colDist)
	return rowDist <= radius and colDist <= radius
end

function PlanetMath.isDeveloped(tileType)
	return tileType == config.TILE.Water
		or tileType == config.TILE.Plant
		or tileType == config.TILE.GlowPlant
end

function PlanetMath.getTileVisual(tileType, index, cosmicSkin)
	index = index or 0

	if tileType == config.TILE.Water then
		return config.COLORS.Water, Enum.Material.SmoothPlastic, 0.06
	end

	if tileType == config.TILE.Plant then
		return config.COLORS.Plant, Enum.Material.Grass, 0.02
	end

	if tileType == config.TILE.GlowPlant then
		return config.COLORS.GlowPlant, Enum.Material.Neon, 0
	end

	-- Bare land is represented by the smooth BaseSphere. Logical land cells stay
	-- invisible until developed; this avoids the overlapping-block shell that made
	-- the planet look jagged while keeping all 192 cells available for gameplay.
	if cosmicSkin then
		local row, col = PlanetMath.indexToRowCol(index)
		local color = ((row + col) % 2 == 0) and config.COLORS.CosmicLandA or config.COLORS.CosmicLandB
		return color, Enum.Material.SmoothPlastic, 1
	end

	return config.COLORS.Land, Enum.Material.Ground, 1
end

return PlanetMath
