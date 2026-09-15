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

local function chooseRandomHabitat(state, canFish, canLand)
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
		return false, "Animals need 3 water tiles for fish or 5 plant tiles for land animals."
	end

	local tileIndex
	local kind
	if requestedIndex ~= nil then
		if not TileGeometry.IsValidIndex(requestedIndex) then
			return false, "That surface tile is invalid."
		end
		if tileOccupied(state, requestedIndex) then
			return false, "That tile already has an animal."
		end

		local tileType = state.Tiles[requestedIndex]
		if tileType == "Water" then
			if not canFish then
				return false, "Create at least 3 water tiles before adding fish."
			end
			tileIndex = requestedIndex
			kind = "Fish"
		elseif tileType == "Plant" or tileType == "RarePlant" then
			if not canLand then
				return false, "Create at least 5 plant tiles before adding land animals."
			end
			tileIndex = requestedIndex
			kind = "Land"
		else
			return false, "Animals need water or planted habitat; bare land cannot support them."
		end
	else
		tileIndex, kind = chooseRandomHabitat(state, canFish, canLand)
	end

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

	if kind == "Fish" then
		return true, string.format("Fish added to tile #%d.", tileIndex), {}
	end
	return true, string.format("A land animal settled on tile #%d.", tileIndex), {}
end

return AnimalSystem
