local DataStoreService = game:GetService("DataStoreService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)

local DataService = {}

local primaryStore = DataStoreService:GetDataStore(Config.DATASTORE_PRIMARY)
local backupStore = DataStoreService:GetDataStore(Config.DATASTORE_BACKUP)

local function deepCopy(value)
	if type(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in pairs(value) do
		result[deepCopy(key)] = deepCopy(child)
	end
	return result
end

local function makeDefaultState()
	local tiles = table.create(Config.TILE_COUNT)
	for index = 1, Config.TILE_COUNT do
		tiles[index] = "Land"
	end
	return {
		Version = 1,
		Energy = Config.ENERGY_START,
		Tiles = tiles,
		Animals = {},
		Settlements = {},
		Milestones = {},
		RareSeedCharges = 0,
		StarterPassApplied = false,
		ProcessedReceipts = {},
		NextEntityId = 1,
		Revision = 0,
		UpdatedAt = os.time(),
	}
end

local function sanitizeState(raw)
	local state = makeDefaultState()
	if type(raw) ~= "table" then
		return state
	end

	if type(raw.Energy) == "number" and raw.Energy == raw.Energy then
		state.Energy = math.clamp(math.floor(raw.Energy), 0, Config.ENERGY_MAX)
	end

	if type(raw.Tiles) == "table" then
		for index = 1, Config.TILE_COUNT do
			local tileType = raw.Tiles[index]
			if Config.VALID_TILE_TYPES[tileType] then
				state.Tiles[index] = tileType
			end
		end
	end

	if type(raw.Animals) == "table" then
		for _, animal in ipairs(raw.Animals) do
			if type(animal) == "table"
				and type(animal.TileIndex) == "number"
				and animal.TileIndex >= 1
				and animal.TileIndex <= Config.TILE_COUNT
				and (animal.Kind == "Fish" or animal.Kind == "Land") then
				table.insert(state.Animals, {
					Id = tostring(animal.Id or #state.Animals + 1),
					TileIndex = math.floor(animal.TileIndex),
					Kind = animal.Kind,
				})
			end
		end
	end

	if type(raw.Settlements) == "table" then
		local seen = {}
		for _, tileIndex in ipairs(raw.Settlements) do
			if type(tileIndex) == "number" then
				tileIndex = math.floor(tileIndex)
				if tileIndex >= 1 and tileIndex <= Config.TILE_COUNT and not seen[tileIndex] then
					seen[tileIndex] = true
					table.insert(state.Settlements, tileIndex)
				end
			end
		end
	end

	if type(raw.Milestones) == "table" then
		for _, milestone in ipairs(Config.MILESTONES) do
			if raw.Milestones[tostring(milestone)] == true or raw.Milestones[milestone] == true then
				state.Milestones[tostring(milestone)] = true
			end
		end
	end

	if type(raw.RareSeedCharges) == "number" then
		state.RareSeedCharges = math.clamp(math.floor(raw.RareSeedCharges), 0, 10_000)
	end
	state.StarterPassApplied = raw.StarterPassApplied == true

	if type(raw.ProcessedReceipts) == "table" then
		local copied = 0
		for receiptId, granted in pairs(raw.ProcessedReceipts) do
			if granted == true and type(receiptId) == "string" and copied < 100 then
				state.ProcessedReceipts[receiptId] = true
				copied += 1
			end
		end

	if type(raw.NextEntityId) == "number" then
		state.NextEntityId = math.max(1, math.floor(raw.NextEntityId))
	end
	if type(raw.Revision) == "number" then
		state.Revision = math.max(0, math.floor(raw.Revision))
	end
	if type(raw.UpdatedAt) == "number" then
		state.UpdatedAt = math.floor(raw.UpdatedAt)
	end
	return state
end

local function keyForUserId(userId)
	return string.format("player_%d", userId)
end

local function getWithRetries(store, key)
	local lastError
	for attempt = 1, Config.DATASTORE_RETRIES do
		local success, result = pcall(function()
			return store:GetAsync(key)
		end)
		if success then
			return true, result
		end
		lastError = result
		task.wait(2 ^ (attempt - 1))
	end
	return false, lastError
end

local function updateWithRetries(store, key, snapshot)
	local lastError
	for attempt = 1, Config.DATASTORE_RETRIES do
		local success, result = pcall(function()
			return store:UpdateAsync(key, function(oldValue)
				if type(oldValue) == "table" then
					local oldRevision = tonumber(oldValue.Revision) or 0
					local newRevision = tonumber(snapshot.Revision) or 0
					if oldRevision > newRevision then
						return oldValue
					end
				end
				return snapshot
			end)
		end)
		if success then
			return true, result
		end
		lastError = result
		task.wait(2 ^ (attempt - 1))
	end
	return false, lastError
end

-- Returns state, source, canSave. If every read fails, gameplay may continue using
-- an in-memory default state, but canSave=false prevents that temporary state from
-- overwriting an older persistent planet when Roblox DataStores recover.
function DataService.Load(userId)
	local key = keyForUserId(userId)
	local primaryOk, primaryResult = getWithRetries(primaryStore, key)
	local backupOk, backupResult = getWithRetries(backupStore, key)
	local primaryData = primaryOk and primaryResult or nil
	local backupData = backupOk and backupResult or nil

	if primaryData ~= nil or backupData ~= nil then
		local primaryRevision = type(primaryData) == "table" and (tonumber(primaryData.Revision) or 0) or -1
		local backupRevision = type(backupData) == "table" and (tonumber(backupData.Revision) or 0) or -1
		if backupRevision > primaryRevision then
			warn(string.format("[DataService] Backup is newer for user %d; loading backup revision %d", userId, backupRevision))
			return sanitizeState(backupData), "backup", true
		end
		if primaryData ~= nil then
			return sanitizeState(primaryData), "primary", true
		end
		return sanitizeState(backupData), "backup", true
	end

	if primaryOk or backupOk then
		return makeDefaultState(), "default", true
	end

	warn(string.format(
		"[DataService] Both DataStores are unavailable for user %d; starting an unsaved session to avoid overwriting existing data",
		userId
	))
	return makeDefaultState(), "unavailable", false
end

function DataService.Save(userId, state)
	local key = keyForUserId(userId)
	local snapshot = deepCopy(state)
	snapshot.UpdatedAt = os.time()

	local primaryOk, primaryError = updateWithRetries(primaryStore, key, snapshot)
	local backupOk, backupError = updateWithRetries(backupStore, key, snapshot)

	if not primaryOk then
		warn(string.format("[DataService] Primary save failed for %d: %s", userId, tostring(primaryError)))
	end
	if not backupOk then
		warn(string.format("[DataService] Backup save failed for %d: %s", userId, tostring(backupError)))
	end
	return primaryOk or backupOk
end

function DataService.DeepCopy(value)
	return deepCopy(value)
end

return DataService
