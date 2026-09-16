local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local shared = ReplicatedStorage:WaitForChild("Shared")
local config = require(shared:WaitForChild("GameConfig"))
local PlanetMath = require(shared:WaitForChild("PlanetMath"))

local mainStore = DataStoreService:GetDataStore("GrowTinyPlanet_Main_v1")
local backupStore = DataStoreService:GetDataStore("GrowTinyPlanet_Backup_v1")

local DataManager = {}
DataManager.cache = {}

local saveQueues = {}
local saveLocks = {}

local function deepCopy(value)
	if typeof(value) ~= "table" then
		return value
	end
	local copy = {}
	for key, child in pairs(value) do
		copy[deepCopy(key)] = deepCopy(child)
	end
	return copy
end

local function defaultData()
	return {
		Version = 2,
		Revision = 0,
		Energy = config.START_ENERGY,
		Tiles = table.create(PlanetMath.getTileCount(), config.TILE.Land),
		Animals = {},
		Settlements = {},
		Milestones = {},
		RareSeedUnlocked = false,
		StarterPlanetApplied = false,
		PurchaseHistory = {},
		UpdatedAt = os.time(),
		SaveBlocked = false,
	}
end

local function isStudioApiDisabled(errorValue)
	if not RunService:IsStudio() then
		return false
	end
	local message = tostring(errorValue)
	return string.find(message, "StudioAccessToApisNotAllowed", 1, true) ~= nil
		or string.find(message, "Studio access to APIs is not allowed", 1, true) ~= nil
end

local function sanitizeData(raw)
	local clean = defaultData()
	if typeof(raw) ~= "table" then
		return clean
	end

	if typeof(raw.Energy) == "number" and raw.Energy == raw.Energy then
		clean.Energy = math.clamp(math.floor(raw.Energy), 0, config.MAX_ENERGY)
	end
	if typeof(raw.Revision) == "number" then
		clean.Revision = math.max(0, math.floor(raw.Revision))
	end
	if typeof(raw.UpdatedAt) == "number" then
		clean.UpdatedAt = math.floor(raw.UpdatedAt)
	end

	if typeof(raw.Tiles) == "table" then
		for i = 1, PlanetMath.getTileCount() do
			local tileType = raw.Tiles[i]
			if tileType == config.TILE.Land
				or tileType == config.TILE.Water
				or tileType == config.TILE.Plant
				or tileType == config.TILE.GlowPlant then
				clean.Tiles[i] = tileType
			end
		end
	end

	if typeof(raw.Animals) == "table" then
		for _, animal in ipairs(raw.Animals) do
			if typeof(animal) == "table"
				and typeof(animal.tile) == "number"
				and animal.tile >= 0
				and animal.tile < PlanetMath.getTileCount()
				and (animal.type == "Fish" or animal.type == "Land") then
				table.insert(clean.Animals, {
					tile = math.floor(animal.tile),
					type = animal.type,
				})
			end
		end
	end

	if typeof(raw.Settlements) == "table" then
		local seen = {}
		for _, index in ipairs(raw.Settlements) do
			if typeof(index) == "number" then
				index = math.floor(index)
				if index >= 0 and index < PlanetMath.getTileCount() and not seen[index] then
					seen[index] = true
					table.insert(clean.Settlements, index)
				end
			end
		end
	end

	if typeof(raw.Milestones) == "table" then
		for _, milestone in ipairs(config.MILESTONES) do
			local key = tostring(milestone.Tiles)
			if raw.Milestones[key] == true or raw.Milestones[milestone.Tiles] == true then
				clean.Milestones[key] = true
			end
		end
	end

	clean.RareSeedUnlocked = raw.RareSeedUnlocked == true
	clean.StarterPlanetApplied = raw.StarterPlanetApplied == true

	if typeof(raw.PurchaseHistory) == "table" then
		local copied = 0
		for receiptId, granted in pairs(raw.PurchaseHistory) do
			if granted == true and typeof(receiptId) == "string" and copied < 150 then
				clean.PurchaseHistory[receiptId] = true
				copied += 1
			end
		end
	end

	return clean
end

local function getWithRetry(store, key)
	local lastError
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:GetAsync(key)
		end)
		if ok then
			return true, result, false
		end
		lastError = result
		if isStudioApiDisabled(result) then
			return false, result, true
		end
		if attempt < 3 then
			task.wait(0.5 * attempt)
		end
	end
	return false, lastError, false
end

local function updateWithRetry(store, key, snapshot)
	local lastError
	for attempt = 1, 3 do
		local ok, result = pcall(function()
			return store:UpdateAsync(key, function(old)
				if typeof(old) == "table" then
					local oldRevision = tonumber(old.Revision) or 0
					if oldRevision > snapshot.Revision then
						return old
					end
				end
				return snapshot
			end)
		end)
		if ok then
			return true, result
		end
		lastError = result
		if isStudioApiDisabled(result) then
			return false, result
		end
		if attempt < 3 then
			task.wait(0.5 * attempt)
		end
	end
	return false, lastError
end

local function keyForPlayer(player)
	return "Player_" .. player.UserId
end

function DataManager.loadPlayer(player)
	local key = keyForPlayer(player)
	local mainOk, mainResult, studioDisabled = getWithRetry(mainStore, key)
	if studioDisabled then
		local data = defaultData()
		data.SaveBlocked = true
		DataManager.cache[player] = data
		warn("[Grow a Tiny Planet] Studio DataStore access disabled; using unsaved test data")
		return data
	end

	local backupOk, backupResult, backupStudioDisabled = getWithRetry(backupStore, key)
	if backupStudioDisabled then
		local data = defaultData()
		data.SaveBlocked = true
		DataManager.cache[player] = data
		warn("[Grow a Tiny Planet] Studio DataStore access disabled; using unsaved test data")
		return data
	end

	local chosen = nil
	if mainOk and typeof(mainResult) == "table" then
		chosen = mainResult
	end
	if backupOk and typeof(backupResult) == "table" then
		local mainRevision = typeof(chosen) == "table" and (tonumber(chosen.Revision) or 0) or -1
		local backupRevision = tonumber(backupResult.Revision) or 0
		if backupRevision > mainRevision then
			chosen = backupResult
		end
	end

	local data = sanitizeData(chosen)
	if not mainOk and not backupOk then
		data.SaveBlocked = true
		warn(string.format("[Grow a Tiny Planet] DataStores unavailable for %s; session is unsaved", player.Name))
	end
	DataManager.cache[player] = data
	return data
end

function DataManager.getData(player)
	return DataManager.cache[player]
end

function DataManager.savePlayer(player)
	local data = DataManager.cache[player]
	if not data or data.SaveBlocked or saveLocks[player] then
		return false
	end

	saveLocks[player] = true
	data.Revision = (tonumber(data.Revision) or 0) + 1
	data.UpdatedAt = os.time()
	local snapshot = deepCopy(data)
	snapshot.SaveBlocked = nil
	local key = keyForPlayer(player)

	local mainOk, mainError = updateWithRetry(mainStore, key, snapshot)
	local backupOk, backupError = updateWithRetry(backupStore, key, snapshot)
	saveLocks[player] = nil

	if not mainOk then
		warn(string.format("[Grow a Tiny Planet] Main save failed for %s: %s", player.Name, tostring(mainError)))
	end
	if not backupOk then
		warn(string.format("[Grow a Tiny Planet] Backup save failed for %s: %s", player.Name, tostring(backupError)))
	end
	return mainOk or backupOk
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
	saveQueues[player] = nil
	saveLocks[player] = nil
	DataManager.cache[player] = nil
end

function DataManager.hasPurchaseId(player, purchaseId)
	local data = DataManager.cache[player]
	return data ~= nil and typeof(data.PurchaseHistory) == "table" and data.PurchaseHistory[purchaseId] == true
end

function DataManager.recordPurchaseId(player, purchaseId)
	local data = DataManager.cache[player]
	if not data or typeof(purchaseId) ~= "string" then
		return
	end
	data.PurchaseHistory[purchaseId] = true
	DataManager.queueSave(player)
end

return DataManager
