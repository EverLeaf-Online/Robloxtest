local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local TileGeometry = require(ReplicatedStorage.Shared.TileGeometry)
local PlanetStateService = require(script.Parent.PlanetStateService)
local PlanetRenderer = require(script.Parent.PlanetRenderer)
local EnergySystem = require(script.Parent.EnergySystem)

local AnimalSystem = {}

local function tileOccupied(state, tileIndex)
	for _, animal in ipairs(state.Animals) do
		if animal.TileIndex == tileIndex then
			return true
		end
	end
	return false
end

local function chooseHabitat(state, requestedIndex, canFish, canLand)
	if TileGeometry.IsValidIndex(requestedIndex) and not tileOccupied(state, requestedIndex) then
		local tileType = state.Tiles[requestedIndex]
		if tileType == "Water" and canFish then
			return requestedIndex, "Fish"
		elseif (tileType == "Plant" or tileType == "RarePlant") and canLand then
			return requestedIndex, "Land"
		end
	end

	local fishTiles = {}
	local landTiles = {}
	for index, tileType in ipairs(state.Tiles) do
		if not tileOccupied(state, index) then
			if tileType == "Water" and canFish then
				table.insert(fishTiles, index)
			elseif (tileType == "Plant" or tileType == "RarePlant") and canLand then
				table.insert(landTiles, index)
			end
		end
	end

	if canLand and #landTiles > 0 then
		return landTiles[math.random(1, #landTiles)], "Land"
	end
	if canFish and #fishTiles > 0 then
		return fishTiles[math.random(1, #fishTiles)], "Fish"
	end
	return nil, nil
end

function AnimalSystem.Apply(player, requestedIndex)
	local state = PlanetStateService.GetState(player)
	if not state then
		return false, "Planet data is not ready."
	end
	if PlanetStateService.GetDevelopedCount(player) < Config.ACTION_UNLOCKS.AddAnimals then
		return false, "Develop 10 tiles to unlock animals."
	end

	local counts = PlanetStateService.GetCounts(player)
	local canFish = counts.Water >= 3
	local canLand = (counts.Plant + counts.RarePlant) >= 5
	if not canFish and not canLand then
		return false, "Animals need either 3 water tiles for fish or 5 plant tiles for land animals."
	end

	local tileIndex, kind = chooseHabitat(state, requestedIndex, canFish, canLand)
	if not tileIndex then
		return false, "No free habitat tile is available for another animal."
	end

	local cost = Config.ACTION_COSTS.AddAnimals
	if not EnergySystem.TrySpend(player, cost) then
		return false, string.format("Add Animals needs %d Energy.", cost)
	end

	local animal = {
		Id = tostring(state.NextEntityId),
		TileIndex = tileIndex,
		Kind = kind,
	}
	state.NextEntityId += 1
	table.insert(state.Animals, animal)
	PlanetStateService.MarkChanged(player)
	PlanetRenderer.SpawnAnimal(player, animal)
	return true, kind == "Fish" and "Fish added to the ocean." or "A land animal joined your ecosystem.", {}
end

return AnimalSystem
