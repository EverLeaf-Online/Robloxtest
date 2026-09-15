local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local TileGeometry = require(ReplicatedStorage.Shared.TileGeometry)
local PlanetStateService = require(script.Parent.PlanetStateService)
local PlanetRenderer = require(script.Parent.PlanetRenderer)
local EnergySystem = require(script.Parent.EnergySystem)

local WaterSystem = {}

local function chooseLandTile(state, requestedIndex)
	if TileGeometry.IsValidIndex(requestedIndex) and state.Tiles[requestedIndex] == "Land" then
		return requestedIndex
	end

	-- Prefer land touching existing water so repeated actions grow visible oceans/rivers.
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
	local tileIndex = chooseLandTile(state, requestedIndex)
	if not tileIndex then
		return false, "There are no undeveloped land tiles left."
	end
	if not EnergySystem.TrySpend(player, cost) then
		return false, "Not enough Energy."
	end
	state.Tiles[tileIndex] = "Water"
	PlanetStateService.MarkChanged(player)
	PlanetRenderer.UpdateTile(player, tileIndex)
	return true, "Water added.", { { TileIndex = tileIndex, TileType = "Water" } }
end

return WaterSystem
