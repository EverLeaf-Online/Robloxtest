--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local TransactionRules = require(ReplicatedStorage.Shared.Domain.TransactionRules)

local ProfileMigrations = require(script.Parent.Parent.Data.ProfileMigrations)
local ProfileSanitizer = require(script.Parent.Parent.Data.ProfileSanitizer)
local ProfileTemplate = require(script.Parent.Parent.Data.ProfileTemplate)
local ProfileTypes = require(script.Parent.Parent.Data.ProfileTypes)
local FactorySessionService = require(script.Parent.FactorySessionService)

type ProfileData = ProfileTypes.ProfileData

local ServerPackages = ServerScriptService:WaitForChild("ServerPackages")
local ProfileStore = require(ServerPackages:WaitForChild("ProfileStore"))

local STORE_NAME = "ScrapToBot_Player_v1"
local PlayerStore = ProfileStore.New(STORE_NAME, ProfileTemplate)

if RunService:IsStudio() then
	PlayerStore = PlayerStore.Mock
end

local DataService = {}
local profiles: { [Player]: any } = {}
local transactionActive: { [Player]: boolean } = {}
local initialized = false

local profileLoadedEvent = Instance.new("BindableEvent")
local profileReleasedEvent = Instance.new("BindableEvent")

DataService.ProfileLoaded = profileLoadedEvent.Event
DataService.ProfileReleased = profileReleasedEvent.Event

local function profileKey(player: Player): string
	return ("Player_%d"):format(player.UserId)
end

local function kickDataFailure(player: Player)
	if player.Parent == Players then
		player:Kick("Your data could not be loaded safely. Please rejoin.")
	end
end

local function endSessionSafely(player: Player, profile: any)
	local ok, err = pcall(function()
		if profile:IsActive() == true then
			profile:EndSession()
		end
	end)
	if not ok then
		warn(
			("[DataService] Failed to end profile session for %d: %s"):format(
				player.UserId,
				tostring(err)
			)
		)
	end
end

local function releaseProfile(player: Player)
	local profile = profiles[player]
	if profile == nil then
		transactionActive[player] = nil
		return
	end

	if profile:IsActive() == true then
		local data = profile.Data :: ProfileData
		local now = os.time()
		data.Timestamps.LastLeave = now
		data.Timestamps.LastProductionTick = now
	end

	endSessionSafely(player, profile)
	transactionActive[player] = nil
	if profiles[player] == profile then
		profiles[player] = nil
		profileReleasedEvent:Fire(player)
	end
end

function DataService.LoadPlayer(player: Player): boolean
	if not FactorySessionService.WaitForVerification(player, 10) then
		warn(("[DataService] Factory route was not verified for %d"):format(player.UserId))
		return false
	end
	if not FactorySessionService.IsOwner(player) then
		-- Visitors are read-only observers. Do not open their persistent profile or
		-- run their personal economy while they are inside another player's factory.
		return false
	end

	local existing = profiles[player]
	if existing ~= nil and existing:IsActive() == true then
		return true
	end
	profiles[player] = nil

	local started, profileOrError = pcall(function()
		return PlayerStore:StartSessionAsync(profileKey(player), {
			Cancel = function()
				return player.Parent ~= Players
			end,
		})
	end)
	if not started then
		warn(
			("[DataService] Profile session start failed for %d: %s"):format(
				player.UserId,
				tostring(profileOrError)
			)
		)
		kickDataFailure(player)
		return false
	end

	local profile = profileOrError
	if profile == nil then
		kickDataFailure(player)
		return false
	end

	local snapshotOk, originalDataOrError = pcall(TransactionRules.Snapshot, profile.Data)
	if not snapshotOk then
		warn(
			("[DataService] Profile snapshot failed for %d: %s"):format(
				player.UserId,
				tostring(originalDataOrError)
			)
		)
		endSessionSafely(player, profile)
		kickDataFailure(player)
		return false
	end
	local originalData = originalDataOrError

	local prepared, prepareError = pcall(function()
		profile:AddUserId(player.UserId)
		ProfileMigrations.Apply(profile.Data)
		profile:Reconcile()
		ProfileSanitizer.Sanitize(profile.Data)
	end)
	if not prepared then
		local restored, restoreError = pcall(TransactionRules.Restore, profile.Data, originalData)
		if not restored then
			warn(
				("[DataService] Profile restore failed for %d: %s"):format(
					player.UserId,
					tostring(restoreError)
				)
			)
		end
		warn(
			("[DataService] Profile preparation failed for %d: %s"):format(
				player.UserId,
				tostring(prepareError)
			)
		)
		endSessionSafely(player, profile)
		kickDataFailure(player)
		return false
	end

	profile.OnSessionEnd:Connect(function()
		transactionActive[player] = nil
		if profiles[player] == profile then
			profiles[player] = nil
			profileReleasedEvent:Fire(player)
		end

		if player.Parent == Players then
			player:Kick("Your data session moved to another server. Please rejoin.")
		end
	end)

	if player.Parent ~= Players or profile:IsActive() ~= true then
		endSessionSafely(player, profile)
		return false
	end

	local data = profile.Data :: ProfileData
	local now = os.time()
	data.Timestamps.LastJoin = now
	if data.Timestamps.LastProductionTick == 0 then
		data.Timestamps.LastProductionTick = now
	end

	profiles[player] = profile
	profileLoadedEvent:Fire(player, data)
	return true
end

function DataService.IsReady(player: Player): boolean
	local profile = profiles[player]
	return profile ~= nil and profile:IsActive() == true
end

function DataService.GetData(player: Player): ProfileData?
	local profile = profiles[player]
	if profile == nil or profile:IsActive() ~= true then
		return nil
	end
	return profile.Data :: ProfileData
end

function DataService.SaveNow(player: Player): boolean
	local profile = profiles[player]
	if profile == nil or profile:IsActive() ~= true then
		return false
	end

	local ok, err = pcall(function()
		local data = profile.Data :: ProfileData
		data.Timestamps.LastSave = os.time()
		profile:Save()
	end)
	if not ok then
		warn(
			("[DataService] Immediate save failed for %d: %s"):format(player.UserId, tostring(err))
		)
		return false
	end
	return profile:IsActive() == true
end

function DataService.Transaction(
	player: Player,
	transaction: (ProfileData) -> (boolean, any?)
): (boolean, any?)
	local profile = profiles[player]
	if profile == nil or profile:IsActive() ~= true then
		return false, "PROFILE_NOT_READY"
	end
	if transactionActive[player] == true then
		return false, "TRANSACTION_BUSY"
	end

	transactionActive[player] = true
	local callOk, executed, result, transactionError = pcall(
		TransactionRules.Execute,
		profile.Data,
		transaction,
		function(draft: ProfileData)
			if profiles[player] ~= profile or profile:IsActive() ~= true then
				error("profile session ended during transaction")
			end
			draft.Revision += 1
			ProfileSanitizer.Sanitize(draft)
		end
	)
	transactionActive[player] = nil

	if not callOk then
		warn(
			("[DataService] Transaction boundary failed for %d: %s"):format(
				player.UserId,
				tostring(executed)
			)
		)
		return false, "TRANSACTION_FAILED"
	end
	if executed ~= true then
		warn(
			("[DataService] Transaction failed for %d: %s"):format(
				player.UserId,
				transactionError or tostring(result)
			)
		)
		return false, result
	end

	return true, result
end

function DataService.Mutate(player: Player, mutator: (ProfileData) -> any?): (boolean, any?)
	return DataService.Transaction(player, function(data)
		return true, mutator(data)
	end)
end

function DataService.ReleasePlayer(player: Player)
	releaseProfile(player)
end

function DataService.Init()
	if initialized then
		return
	end
	initialized = true

	for _, player in Players:GetPlayers() do
		task.spawn(DataService.LoadPlayer, player)
	end

	Players.PlayerAdded:Connect(function(player)
		task.spawn(DataService.LoadPlayer, player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		releaseProfile(player)
	end)
end

return DataService
