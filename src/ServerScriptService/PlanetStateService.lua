local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local DataService = require(script.Parent.DataService)

local PlanetStateService = {}

local states = {}
local centers = {}
local passFlags = {}
local saveEnabled = {}
local slotsByUserId = {}
local freeSlots = {}
local nextSlot = 0

local function countTiles(state)
	local counts = { Land = 0, Water = 0, Plant = 0, RarePlant = 0 }
	for _, tileType in ipairs(state.Tiles) do
		counts[tileType] = (counts[tileType] or 0) + 1
	end
	return counts
end

local function getDevelopedCount(state)
	local counts = countTiles(state)
	return counts.Water + counts.Plant + counts.RarePlant
end

local function getUnlocks(state)
	local developed = getDevelopedCount(state)
	return {
		AddWater = developed >= Config.ACTION_UNLOCKS.AddWater,
		AddPlants = developed >= Config.ACTION_UNLOCKS.AddPlants,
		AddAnimals = developed >= Config.ACTION_UNLOCKS.AddAnimals,
		BuildSettlement = developed >= Config.ACTION_UNLOCKS.BuildSettlement,
		TerraformBurst = developed >= Config.ACTION_UNLOCKS.TerraformBurst,
	}
end

local function allocateCenter(userId)
	local slot
	if #freeSlots > 0 then
		slot = table.remove(freeSlots)
	else
		slot = nextSlot
		nextSlot += 1
	end
	slotsByUserId[userId] = slot
	local column = slot % 4
	local row = math.floor(slot / 4)
	local center = Vector3.new(column * Config.PLANET_SLOT_SPACING, 0, row * Config.PLANET_SLOT_SPACING)
	centers[userId] = center
	return center
end

function PlanetStateService.LoadPlayer(player)
	if states[player.UserId] then
		return states[player.UserId]
	end
	local state, source, canSave = DataService.Load(player.UserId)
	states[player.UserId] = state
	saveEnabled[player.UserId] = canSave == true
	passFlags[player.UserId] = {}
	allocateCenter(player.UserId)
	player:SetAttribute("PlanetDataSource", source)
	player:SetAttribute("PlanetDataWritable", canSave == true)
	return state
end

function PlanetStateService.IsLoaded(player)
	return states[player.UserId] ~= nil
end

function PlanetStateService.CanSave(player)
	return saveEnabled[player.UserId] == true
end

function PlanetStateService.GetState(player)
	return states[player.UserId]
end

function PlanetStateService.GetCenter(player)
	return centers[player.UserId]
end

function PlanetStateService.MarkChanged(player)
	local state = states[player.UserId]
	if not state then
		return
	end
	state.Revision = (state.Revision or 0) + 1
	state.UpdatedAt = os.time()
end

function PlanetStateService.SetPassFlags(player, flags)
	passFlags[player.UserId] = flags or {}
end

function PlanetStateService.GetPassFlags(player)
	return passFlags[player.UserId] or {}
end

function PlanetStateService.GetCounts(player)
	local state = states[player.UserId]
	return state and countTiles(state) or { Land = 0, Water = 0, Plant = 0, RarePlant = 0 }
end

function PlanetStateService.GetDevelopedCount(player)
	local state = states[player.UserId]
	return state and getDevelopedCount(state) or 0
end

function PlanetStateService.GetUnlocks(player)
	local state = states[player.UserId]
	return state and getUnlocks(state) or {}
end

function PlanetStateService.GetPublicState(player)
	local state = states[player.UserId]
	if not state then
		return nil
	end
	return {
		Energy = state.Energy,
		Tiles = DataService.DeepCopy(state.Tiles),
		Animals = DataService.DeepCopy(state.Animals),
		Settlements = DataService.DeepCopy(state.Settlements),
		Milestones = DataService.DeepCopy(state.Milestones),
		RareSeedCharges = state.RareSeedCharges,
		DevelopedTiles = getDevelopedCount(state),
		Counts = countTiles(state),
		Unlocks = getUnlocks(state),
		Passes = DataService.DeepCopy(passFlags[player.UserId] or {}),
		DataWritable = saveEnabled[player.UserId] == true,
	}
end

function PlanetStateService.GetSummary(player)
	local state = states[player.UserId]
	if not state then
		return nil
	end
	return {
		Energy = state.Energy,
		RareSeedCharges = state.RareSeedCharges,
		DevelopedTiles = getDevelopedCount(state),
		Counts = countTiles(state),
		AnimalCount = #state.Animals,
		SettlementCount = #state.Settlements,
		Unlocks = getUnlocks(state),
		DataWritable = saveEnabled[player.UserId] == true,
	}
end

function PlanetStateService.SavePlayer(player)
	local state = states[player.UserId]
	if not state or not PlanetStateService.CanSave(player) then
		return false
	end
	return DataService.Save(player.UserId, state)
end

function PlanetStateService.QueueSave(player)
	local state = states[player.UserId]
	if not state or not PlanetStateService.CanSave(player) then
		return
	end
	local snapshot = DataService.DeepCopy(state)
	task.spawn(function()
		DataService.Save(player.UserId, snapshot)
	end)
end

function PlanetStateService.UnloadPlayer(player)
	states[player.UserId] = nil
	passFlags[player.UserId] = nil
	saveEnabled[player.UserId] = nil
	centers[player.UserId] = nil
	local slot = slotsByUserId[player.UserId]
	if slot ~= nil then
		table.insert(freeSlots, slot)
		slotsByUserId[player.UserId] = nil
	end
end

function PlanetStateService.GetLoadedPlayers()
	local result = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if states[player.UserId] then
			table.insert(result, player)
		end
	end
	return result
end

return PlanetStateService
