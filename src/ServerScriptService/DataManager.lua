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
local dirty = {}
local lastBackupAt = {}

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

local function callWithTimeout(callback, timeoutSeconds)
	local finished = false
	local acceptingResult = true
	local success = false
	local value = nil

	task.spawn(function()
		local ok, result = pcall(callback)
		if acceptingResult then
			success = ok
			value = result
			finished = true
		end
	end)

	local deadline = os.clock() + timeoutSeconds
	while not finished and os.clock() < deadline do
		task.wait(0.05)
	end

	if not finished then
		acceptingResult = false
		return false, "request timed out", true
	end

	return success, value, false
end

local function readStore(store, key, timeoutSeconds)
	return callWithTimeout(function()
		return store:GetAsync(key)
	end, timeoutSeconds)
end

local function writeStore(store, key, snapshot, timeoutSeconds)
	local ok, result, timedOut = callWithTimeout(function()
		return store:UpdateAsync(key, function(old)
			if typeof(old) == "table" then
				local oldRevision = tonumber(old.Revision) or 0
				if oldRevision > snapshot.Revision then
					return old
				end
			end
			return snapshot
		end)
	end, timeoutSeconds)

	if not ok then
		return false, result, timedOut
	end

	if typeof(result) == "table" and (tonumber(result.Revision) or 0) > snapshot.Revision then
		return false, "newer cloud revision exists", false
	end

	return true, result, false
end

local function keyForPlayer(player)
	return "Player_" .. player.UserId
end

function DataManager.loadPlayer(player)
	-- Studio playtests use isolated in-memory data by default. This prevents a
	-- throttled DataStore queue from blocking the entire game boot and prevents
	-- accidental writes to production data while building the game.
	if RunService:IsStudio() and config.STUDIO_DATASTORE_ENABLED ~= true then
		local data = defaultData()
		data.SaveBlocked = true
		DataManager.cache[player] = data
		dirty[player] = false
		warn("[Grow a Tiny Planet] Studio persistence bypassed; using an unsaved local test planet")
		return data
	end

	local key = keyForPlayer(player)
	local mainOk, mainResult, mainTimedOut = readStore(
		mainStore,
		key,
		config.DATASTORE_LOAD_TIMEOUT or 6
	)

	if mainOk then
		local data = sanitizeData(mainResult)
		data.SaveBlocked = false
		DataManager.cache[player] = data
		dirty[player] = false
		lastBackupAt[player] = os.time()
		return data
	end

	warn(string.format(
		"[Grow a Tiny Planet] Main load failed for %s%s: %s",
		player.Name,
		mainTimedOut and " (timeout)" or "",
		tostring(mainResult)
	))

	-- Backup is recovery-only. We no longer read both stores on every join.
	local backupOk, backupResult, backupTimedOut = readStore(
		backupStore,
		key,
		config.DATASTORE_BACKUP_TIMEOUT or 3
	)

	if backupOk and typeof(backupResult) == "table" then
		local data = sanitizeData(backupResult)
		data.SaveBlocked = false
		DataManager.cache[player] = data
		dirty[player] = true -- restore the primary store on the next successful save
		lastBackupAt[player] = os.time()
		warn(string.format("[Grow a Tiny Planet] Recovered %s from backup data", player.Name))
		return data
	end

	local data = defaultData()
	data.SaveBlocked = true
	DataManager.cache[player] = data
	dirty[player] = false
	warn(string.format(
		"[Grow a Tiny Planet] Cloud data unavailable for %s%s; starting a protected unsaved session",
		player.Name,
		backupTimedOut and " (backup timeout)" or ""
	))
	return data
end

function DataManager.getData(player)
	return DataManager.cache[player]
end

function DataManager.savePlayer(player, forceBackup)
	local data = DataManager.cache[player]
	if not data or data.SaveBlocked then
		return false
	end

	if saveLocks[player] then
		local deadline = os.clock() + 4
		while saveLocks[player] and os.clock() < deadline do
			task.wait(0.05)
		end
		if saveLocks[player] then
			return false
		end
	end

	saveLocks[player] = true
	data.Revision = (tonumber(data.Revision) or 0) + 1
	data.UpdatedAt = os.time()

	local snapshot = deepCopy(data)
	snapshot.SaveBlocked = nil
	local key = keyForPlayer(player)
	local mainOk, mainError = writeStore(
		mainStore,
		key,
		snapshot,
		config.DATASTORE_SAVE_TIMEOUT or 6
	)

	if not mainOk then
		saveLocks[player] = nil
		dirty[player] = true
		if tostring(mainError) == "newer cloud revision exists" then
			data.SaveBlocked = true
			warn(string.format(
				"[Grow a Tiny Planet] Save blocked for %s because a newer cloud revision exists",
				player.Name
			))
		else
			warn(string.format("[Grow a Tiny Planet] Main save failed for %s: %s", player.Name, tostring(mainError)))
		end
		return false
	end

	dirty[player] = false

	local now = os.time()
	local backupDue = forceBackup == true
		or now - (lastBackupAt[player] or 0) >= (config.DATASTORE_BACKUP_INTERVAL or 300)

	if backupDue then
		local backupOk, backupError = writeStore(
			backupStore,
			key,
			snapshot,
			config.DATASTORE_SAVE_TIMEOUT or 6
		)
		if backupOk then
			lastBackupAt[player] = now
		else
			warn(string.format("[Grow a Tiny Planet] Backup save failed for %s: %s", player.Name, tostring(backupError)))
		end
	end

	saveLocks[player] = nil
	return true
end

function DataManager.queueSave(player)
	dirty[player] = true
	if saveQueues[player] then
		return
	end

	saveQueues[player] = true
	task.delay(config.DATASTORE_SAVE_DELAY or 30, function()
		saveQueues[player] = nil
		if player.Parent and dirty[player] then
			DataManager.savePlayer(player, false)
		end
	end)
end

function DataManager.saveAll(force)
	for player in pairs(DataManager.cache) do
		if player.Parent and (force == true or dirty[player]) then
			DataManager.savePlayer(player, force == true)
		end
	end
end

function DataManager.unloadPlayer(player)
	saveQueues[player] = nil
	saveLocks[player] = nil
	dirty[player] = nil
	lastBackupAt[player] = nil
	DataManager.cache[player] = nil
end

function DataManager.hasPurchaseId(player, purchaseId)
	local data = DataManager.cache[player]
	return data ~= nil
		and typeof(data.PurchaseHistory) == "table"
		and data.PurchaseHistory[purchaseId] == true
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
