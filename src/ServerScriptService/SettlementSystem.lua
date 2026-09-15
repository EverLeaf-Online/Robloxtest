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

local function chooseSettlementTile(state, requestedIndex)
	local components = findValidComponents(state)
	if #components == 0 then
		return nil
	end

	local requestedValid = TileGeometry.IsValidIndex(requestedIndex)
	for _, component in ipairs(components) do
		local inComponent = false
		for _, tileIndex in ipairs(component) do
			if requestedValid and tileIndex == requestedIndex then
				inComponent = true
				break
			end
		end
		if inComponent then
			for _, tileIndex in ipairs(component) do
				local tileType = state.Tiles[tileIndex]
				if (tileType == "Plant" or tileType == "RarePlant") and not settlementOccupied(state, tileIndex) then
					return tileIndex
				end
			end
		end
	end

	for _, component in ipairs(components) do
		for _, tileIndex in ipairs(component) do
			local tileType = state.Tiles[tileIndex]
			if (tileType == "Plant" or tileType == "RarePlant") and not settlementOccupied(state, tileIndex) then
				return tileIndex
			end
		end
	end
	return nil
end

function SettlementSystem.Apply(player, requestedIndex)
	local state = PlanetStateService.GetState(player)
	if not state then
		return false, "Planet data is not ready."
	end
	if PlanetStateService.GetDevelopedCount(player) < Config.ACTION_UNLOCKS.BuildSettlement then
		return false, "Develop 25 tiles to unlock settlements."
	end

	local tileIndex = chooseSettlementTile(state, requestedIndex)
	if not tileIndex then
		return false, "A settlement needs a connected cluster of at least 5 developed tiles with an available plant tile."
	end
	local cost = Config.ACTION_COSTS.BuildSettlement
	if not EnergySystem.TrySpend(player, cost) then
		return false, string.format("Build Settlement needs %d Energy.", cost)
	end

	table.insert(state.Settlements, tileIndex)
	PlanetStateService.MarkChanged(player)
	PlanetRenderer.SpawnSettlement(player, tileIndex)
	return true, "A new settlement has been founded.", {}
end

return SettlementSystem
