local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Config = require(ReplicatedStorage.Shared.Config)

local TileGeometry = {}
local directions = table.create(Config.TILE_COUNT)
local neighbors = table.create(Config.TILE_COUNT)

local goldenAngle = math.pi * (3 - math.sqrt(5))

for index = 1, Config.TILE_COUNT do
	local y = 1 - (2 * (index - 0.5) / Config.TILE_COUNT)
	local radial = math.sqrt(math.max(0, 1 - y * y))
	local theta = goldenAngle * (index - 1)
	directions[index] = Vector3.new(math.cos(theta) * radial, y, math.sin(theta) * radial).Unit
end

for index = 1, Config.TILE_COUNT do
	local scored = table.create(Config.TILE_COUNT - 1)
	local cursor = 1
	for other = 1, Config.TILE_COUNT do
		if other ~= index then
			scored[cursor] = {
				Index = other,
				Dot = directions[index]:Dot(directions[other]),
			}
			cursor += 1
		end
	end
	table.sort(scored, function(a, b)
		return a.Dot > b.Dot
	end)
	local list = table.create(6)
	for rank = 1, 6 do
		list[rank] = scored[rank].Index
	end
	neighbors[index] = table.freeze(list)
end

function TileGeometry.IsValidIndex(index)
	return type(index) == "number"
		and index == index
		and index ~= math.huge
		and index ~= -math.huge
		and math.floor(index) == index
		and index >= 1
		and index <= Config.TILE_COUNT
end

function TileGeometry.GetDirection(index)
	assert(TileGeometry.IsValidIndex(index), "invalid tile index")
	return directions[index]
end

function TileGeometry.GetNeighbors(index)
	assert(TileGeometry.IsValidIndex(index), "invalid tile index")
	return neighbors[index]
end

function TileGeometry.GetPosition(center, index, radius)
	return center + directions[index] * radius
end

function TileGeometry.GetTileCFrame(center, index, radius)
	local normal = directions[index]
	local position = center + normal * radius
	local reference = math.abs(normal:Dot(Vector3.yAxis)) > 0.95 and Vector3.xAxis or Vector3.yAxis
	local zAxis = normal:Cross(reference).Unit
	local yAxis = zAxis:Cross(normal).Unit
	return CFrame.fromMatrix(position, normal, yAxis, zAxis)
end

function TileGeometry.GetObjectCFrame(center, index, radius)
	local normal = directions[index]
	local position = center + normal * radius
	local reference = math.abs(normal:Dot(Vector3.yAxis)) > 0.95 and Vector3.xAxis or Vector3.yAxis
	local right = reference:Cross(normal).Unit
	local back = right:Cross(normal).Unit
	return CFrame.fromMatrix(position, right, normal, back)
end

return table.freeze(TileGeometry)
