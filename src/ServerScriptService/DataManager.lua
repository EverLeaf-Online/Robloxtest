-- ServerScriptService/DataManager.module.lua
-- Handles per-player data loading/saving with retries and backup DataStore.

local DataStoreService = game:GetService("DataStoreService")

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local shared = ReplicatedStorage:WaitForChild("Shared")
local config = require(shared:WaitForChild("GameConfig"))
local PlanetMath = require(shared:WaitForChild("PlanetMath"))

local mainStore = DataStoreService:GetDataStore("GrowTinyPlanet_Main_v1")
local backupStore = DataStoreService:GetDataStore("GrowTinyPlanet_Backup_v1")

local DataManager = {}
DataManager.cache = {}

local saveQueues = {}

local function defaultData()
	return {
		Version = 1,
		Energy = config.START_ENERGY,
		Tiles = table.create(PlanetMath.getTileCount(), config.TILE.Land),
		Animals = {},
		Settlements = {},
		Milestones = {},
		RareSeedUnlocked = false,
		StarterPlanetApplied = false,
		PurchaseHistory = {},
		LastBackup = 0,
		SaveBlocked = false,
	}
end

local function attempt(fn, attempts, delayTime)
	local lastError

	for i = 1, attempts do
		local ok, result = pcall(fn)
		if ok then
			return true, result
		end

		lastError = result
		if i < attempts then
			task.wait(delayTime * i)
		end
	end

	return false, lastError
end

local function sanitizeData(data)
	local clean = defaultData()

	if typeof(data) ~= "table" then
		return clean
	end

	for key, value in pairs(clean) do
		if data[key] == nil then
			data[key] = value
		end
	end

	if typeof(data.Tiles) ~= "table" or #data.Tiles ~= PlanetMath.getTileCount() then
		data.Tiles = clean.Tiles
	end

	for i = 1, #data.Tiles do
		if typeof(data.Tiles[i]) ~= "number" then
			data.Tiles[i] = config.TILE.Land
		end
	end

	if typeof(data.Animals) ~= "table" then
		data.Animals = {}
	end

	if typeof(data.Settlements) ~= "table" then
		data.Settlements = {}
	end

	if typeof(data.Milestones) ~= "table" then
		data.Milestones = {}
	end

	if typeof(data.PurchaseHistory) ~= "table" then
		data.PurchaseHistory = {}
	end

	data.Energy = math.floor(tonumber(data.Energy) or clean.Energy)
	data.LastBackup = math.floor(tonumber(data.LastBackup) or 0)
	data.SaveBlocked = data.SaveBlocked == true
	data.RareSeedUnlocked = data.RareSeedUnlocked == true
	data.StarterPlanetApplied = data.StarterPlanetApplied == true

	return data
end

function DataManager.loadPlayer(player)
	local key = "Player_" .. player.UserId
	local data = nil

	local okMain, resultMain = attempt(function()
		return mainStore:GetAsync(key)
	end, 3, 1)

	if okMain then
		data = resultMain
	else
		-- Main DataStore failed. Try backup.
		local okBackup, resultBackup = attempt(function()
			return backupStore:GetAsync(key)
		end, 3, 1)

		if okBackup and typeof(resultBackup) == "table" then
			data = resultBackup
			data.SaveBlocked = false
		else
			-- Could not load cloud data. Let the player play, but do not overwrite existing data.
			data = defaultData()
			data.SaveBlocked = true
		end
	end

	data = sanitizeData(data)
	DataManager.cache[player] = data
	return data
end

function DataManager.getData(player)
	return DataManager.cache[player]
end

function DataManager.savePlayer(player)
	local data = DataManager.cache[player]
	if not data then
		return false
	end

	if data.SaveBlocked then
		return false
	end

	local key = "Player_" .. player.UserId

	local ok = attempt(function()
		mainStore:SetAsync(key, data)
	end, 3, 1)

	if ok then
		-- Periodically write a backup copy.
		if os.time() - (data.LastBackup or 0) > 300 then
			pcall(function()
				backupStore:SetAsync(key, data)
			end)
			data.LastBackup = os.time()
		end
	end

	return ok
end

function DataManager.queueSave(player)
	if saveQueues[player] then
		return
	end

	saveQueues[player] = true

	task.delay(1, function()
		saveQueues[player] = nil
		if player.Parent then
			DataManager.savePlayer(player)
		end
	end)
end

function DataManager.saveAll()
	for player in pairs(DataManager.cache) do
		if player.Parent then
			DataManager.savePlayer(player)
		end
	end
end

function DataManager.unloadPlayer(player)
	DataManager.cache[player] = nil
end

function DataManager.hasPurchaseId(player, purchaseId)
	local data = DataManager.cache[player]
	if not data or typeof(data.PurchaseHistory) ~= "table" then
		return false
	end

	return data.PurchaseHistory[purchaseId] == true
end

function DataManager.recordPurchaseId(player, purchaseId)
	local data = DataManager.cache[player]
	if not data then
		return
	end

	if typeof(data.PurchaseHistory) ~= "table" then
		data.PurchaseHistory = {}
	end

	data.PurchaseHistory[purchaseId] = true
	DataManager.queueSave(player)
end

return DataManager
