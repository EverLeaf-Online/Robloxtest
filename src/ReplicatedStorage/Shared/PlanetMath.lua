-- ReplicatedStorage/Shared/PlanetMath.module.lua
-- Shared math helpers for the spherical tile grid.

local config = require(script.Parent:WaitForChild("GameConfig"))

local PlanetMath = {}

function PlanetMath.getTileCount()
	return config.TILE_ROWS * config.TILE_COLS
end

function PlanetMath.indexToRowCol(index)
	-- index is 0-based
	local row = math.floor(index / config.TILE_COLS)
	local col = index % config.TILE_COLS
	return row, col
end

function PlanetMath.rowColToIndex(row, col)
	return row * config.TILE_COLS + col
end

function PlanetMath.getDirection(index)
	local row, col = PlanetMath.indexToRowCol(index)

	-- Latitude goes from south pole to north pole.
	-- Longitude wraps around the planet.
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

	-- Longitude wraps around the planet.
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
		return config.COLORS.Water, Enum.Material.Glass, 0.18
	end

	if tileType == config.TILE.Plant then
		return config.COLORS.Plant, Enum.Material.Grass, 0
	end

	if tileType == config.TILE.GlowPlant then
		return config.COLORS.GlowPlant, Enum.Material.Neon, 0
	end

	-- Default land tile.
	if cosmicSkin then
		local row, col = PlanetMath.indexToRowCol(index)
		if (row + col) % 2 == 0 then
			return config.COLORS.CosmicLandA, Enum.Material.SmoothPlastic, 0
		else
			return config.COLORS.CosmicLandB, Enum.Material.SmoothPlastic, 0
		end
	end

	return config.COLORS.Land, Enum.Material.Slate, 0
end

return PlanetMath
