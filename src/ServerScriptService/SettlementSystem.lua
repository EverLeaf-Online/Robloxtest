local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local TileGeometry = require(ReplicatedStorage.Shared.TileGeometry)
local PlanetStateService = require(script.Parent.PlanetStateService)
local PlanetRenderer = require(script.Parent.PlanetRenderer)
local EnergySystem = require(script.Parent.EnergySystem)

local SettlementSystem = {}

local function isDeveloped(tileType)
	return tileType == "Water" or tileType == "Plant" or tileType == "RarePlant"
end

local function settlementOccupied(state, tileIndex)
	for _, existing in ipairs(state.Settlements) do
		if existing == tileIndex then
			return true
		end
	end
	return false
end

local function findValidComponents(state)
	local visited = {}
	local components = {}
	for index = 1, Config.TILE_COUNT do
		if not visited[index] and isDeveloped(state.Tiles[index]) then
			local queue = { index }
			local head = 1
			visited[index] = true
			local component = {}
			while head <= #queue do
				local current = queue[head]
				head += 1
				table.insert(component, current)
				for _, neighbor in ipairs(TileGeometry.GetNeighbors(current)) do
					if not visited[neighbor] and isDeveloped(state.Tiles[neighbor]) then
						visited[neighbor] = true
						table.insert(queue, neighbor)
					end
				end
			end
			if #component >= 5 then
				table.insert(components, component)
			end
		end
	end
	return components
end

local function componentContains(component, tileIndex)
	for _, index in ipairs(component) do
		if index == tileIndex then
			return true
		end
	end
	return false
end

local function chooseRandomSettlementTile(state, components)
	local candidates = {}
	for _, component in ipairs(components) do
		for _, tileIndex in ipairs(component) do
			local tileType = state.Tiles[tileIndex]
			if (tileType == "Plant" or tileType == "RarePlant") and not settlementOccupied(state, tileIndex) then
				table.insert(candidates, tileIndex)
			end
		end
	end
	if #candidates == 0 then
		return nil
	end
	return candidates[math.random(1, #candidates)]
end

function SettlementSystem.Apply(player, requestedIndex)
	local state = PlanetStateService.GetState(player)
	if not state then
		return false, "Planet data is not ready."
	end
	if PlanetStateService.GetDevelopedCount(player) < Config.ACTION_UNLOCKS.BuildSettlement then
		return false, "Develop 25 tiles to unlock settlements."
	end

	local components = findValidComponents(state)
	if #components == 0 then
		return false, "A settlement needs a connected cluster of at least 5 developed tiles."
	end

	local tileIndex
	if requestedIndex ~= nil then
		if not TileGeometry.IsValidIndex(requestedIndex) then
			return false, "That surface tile is invalid."
		end
		local tileType = state.Tiles[requestedIndex]
		if tileType ~= "Plant" and tileType ~= "RarePlant" then
			return false, "Settlements must be placed on a planted tile."
		end
		if settlementOccupied(state, requestedIndex) then
			return false, "That tile already contains a settlement."
		end

		local inLargeCluster = false
		for _, component in ipairs(components) do
			if componentContains(component, requestedIndex) then
				inLargeCluster = true
				break
			end
		end
		if not inLargeCluster then
			return false, "That tile is not part of a connected 5-tile developed cluster."
		end
		tileIndex = requestedIndex
	else
		tileIndex = chooseRandomSettlementTile(state, components)
	end

	if not tileIndex then
		return false, "No available planted tile can support another settlement."
	end

	local cost = Config.ACTION_COSTS.BuildSettlement
	if not EnergySystem.TrySpend(player, cost) then
		return false, string.format("Build Settlement needs %d Energy.", cost)
	end

	table.insert(state.Settlements, tileIndex)
	PlanetStateService.MarkChanged(player)
	PlanetRenderer.SpawnSettlement(player, tileIndex)
	return true, string.format("A new settlement was founded on tile #%d.", tileIndex), {}
end

return SettlementSystem
