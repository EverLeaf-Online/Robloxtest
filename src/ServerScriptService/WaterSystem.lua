local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local TileGeometry = require(ReplicatedStorage.Shared.TileGeometry)
local PlanetStateService = require(script.Parent.PlanetStateService)
local PlanetRenderer = require(script.Parent.PlanetRenderer)
local EnergySystem = require(script.Parent.EnergySystem)

local WaterSystem = {}

local function chooseRandomLandTile(state)
	-- Prefer land touching existing water so random growth expands oceans/rivers.
	local frontier = {}
	local seen = {}
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

function WaterSystem.Apply(player, requestedIndex)
	local state = PlanetStateService.GetState(player)
	if not state then
		return false, "Planet data is not ready."
	end

	local cost = Config.ACTION_COSTS.AddWater
	if not EnergySystem.CanAfford(player, cost) then
		return false, string.format("Add Water needs %d Energy.", cost)
	end

	local tileIndex
	if requestedIndex ~= nil then
		if not TileGeometry.IsValidIndex(requestedIndex) then
			return false, "That surface tile is invalid."
		end
		if state.Tiles[requestedIndex] ~= "Land" then
			return false, "Water can only be added to undeveloped land."
		end
		tileIndex = requestedIndex
	else
		tileIndex = chooseRandomLandTile(state)
	end

	if not tileIndex then
		return false, "There are no undeveloped land tiles left."
	end
	if not EnergySystem.TrySpend(player, cost) then
		return false, "Not enough Energy."
	end

	state.Tiles[tileIndex] = "Water"
	PlanetStateService.MarkChanged(player)
	PlanetRenderer.UpdateTile(player, tileIndex)
	return true, string.format("Water added to tile #%d.", tileIndex), { { TileIndex = tileIndex, TileType = "Water" } }
end

return WaterSystem
