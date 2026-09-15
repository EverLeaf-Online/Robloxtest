local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local TileGeometry = require(ReplicatedStorage.Shared.TileGeometry)
local PlanetStateService = require(script.Parent.PlanetStateService)
local PlanetRenderer = require(script.Parent.PlanetRenderer)
local EnergySystem = require(script.Parent.EnergySystem)

local PlantSystem = {}

local function chooseRandomLandTile(state)
	-- Prefer land touching existing vegetation so random growth forms visible biomes.
	local frontier = {}
	local seen = {}
	for index, tileType in ipairs(state.Tiles) do
		if tileType == "Plant" or tileType == "RarePlant" then
			for _, neighbor in ipairs(TileGeometry.GetNeighbors(index)) do
				if state.Tiles[neighbor] == "Land" and not seen[neighbor] then
					seen[neighbor] = true
					table.insert(frontier, neighbor)
				end
			end
		end
	end
	if #frontier > 0 then
		return frontier[math.random(1, #frontier)]
	end

	-- First vegetation prefers coastline tiles before fully random land.
	for index, tileType in ipairs(state.Tiles) do
		if tileType == "Water" then
			for _, neighbor in ipairs(TileGeometry.GetNeighbors(index)) do
				if state.Tiles[neighbor] == "Land" and not seen[neighbor] then
					seen[neighbor] = true
					table.insert(frontier, neighbor)
				end
			end
		end
	end
	if #frontier > 0 then
		return frontier[math.random(1, #frontier)]
	end

	local candidates = {}
	for index, tileType in ipairs(state.Tiles) do
		if tileType == "Land" then
			table.insert(candidates, index)
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[math.random(1, #candidates)]
end

function PlantSystem.Apply(player, requestedIndex)
	local state = PlanetStateService.GetState(player)
	if not state then
		return false, "Planet data is not ready."
	end

	local cost = Config.ACTION_COSTS.AddPlants
	if not EnergySystem.CanAfford(player, cost) then
		return false, string.format("Add Plants needs %d Energy.", cost)
	end

	local tileIndex
	if requestedIndex ~= nil then
		if not TileGeometry.IsValidIndex(requestedIndex) then
			return false, "That surface tile is invalid."
		end
		if state.Tiles[requestedIndex] ~= "Land" then
			return false, "Plants can only be added to undeveloped land."
		end
		tileIndex = requestedIndex
	else
		tileIndex = chooseRandomLandTile(state)
	end

	if not tileIndex then
		return false, "There are no undeveloped land tiles left for plants."
	end
	if not EnergySystem.TrySpend(player, cost) then
		return false, "Not enough Energy."
	end

	local tileType = "Plant"
	if state.RareSeedCharges > 0 then
		state.RareSeedCharges -= 1
		tileType = "RarePlant"
	end
	state.Tiles[tileIndex] = tileType
	PlanetStateService.MarkChanged(player)
	PlanetRenderer.UpdateTile(player, tileIndex)

	local message
	if tileType == "RarePlant" then
		message = string.format("A rare glowing plant took root on tile #%d!", tileIndex)
	else
		message = string.format("Plants added to tile #%d.", tileIndex)
	end
	return true, message, { { TileIndex = tileIndex, TileType = tileType } }
end

return PlantSystem
