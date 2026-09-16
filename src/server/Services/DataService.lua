--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")

local ProfileTemplate = require(script.Parent.Parent.Data.ProfileTemplate)
local ProfileSanitizer = require(script.Parent.Parent.Data.ProfileSanitizer)

local ServerPackages = ServerScriptService:WaitForChild("ServerPackages")
local ProfileStore = require(ServerPackages:WaitForChild("ProfileStore"))

local STORE_NAME = "ScrapToBot_Player_v1"
local PlayerStore = ProfileStore.New(STORE_NAME, ProfileTemplate)

if RunService:IsStudio() then
	PlayerStore = PlayerStore.Mock
end

local DataService = {}
local profiles: { [Player]: any } = {}
local initialized = false

local profileLoadedEvent = Instance.new("BindableEvent")
local profileReleasedEvent = Instance.new("BindableEvent")

DataService.ProfileLoaded = profileLoadedEvent.Event
DataService.ProfileReleased = profileReleasedEvent.Event

local function profileKey(player: Player): string
	return ("Player_%d"):format(player.UserId)
end

local function releaseProfile(player: Player)
	local profile = profiles[player]
	if profile == nil then
		return
	end

	profiles[player] = nil
	profile:EndSession()
end

function DataService.LoadPlayer(player: Player): boolean
	if profiles[player] ~= nil then
		return true
	end

	local profile = PlayerStore:StartSessionAsync(profileKey(player), {
		Cancel = function()
			return player.Parent ~= Players
		end,
	})

	if profile == nil then
		if player.Parent == Players then
			player:Kick("Your data could not be loaded safely. Please rejoin.")
		end
		return false
	end

	profile:AddUserId(player.UserId)
	profile:Reconcile()
	ProfileSanitizer.Sanitize(profile.Data)

	profile.OnSessionEnd:Connect(function()
		if profiles[player] == profile then
			profiles[player] = nil
			profileReleasedEvent:Fire(player)
		end

		if player.Parent == Players then
			player:Kick("Your data session moved to another server. Please rejoin.")
		end
	end)

	if player.Parent ~= Players then
		profile:EndSession()
		return false
	end

	local now = os.time()
	profile.Data.Timestamps.LastJoin = now
	if profile.Data.Timestamps.LastProductionTick == 0 then
		profile.Data.Timestamps.LastProductionTick = now
	end

	profiles[player] = profile
	profileLoadedEvent:Fire(player, profile.Data)
	return true
end

function DataService.IsReady(player: Player): boolean
	return profiles[player] ~= nil
end

function DataService.GetData(player: Player): any?
	local profile = profiles[player]
	if profile == nil then
		return nil
	end
	return profile.Data
end

function DataService.Mutate(player: Player, mutator: (any) -> ...any): (boolean, ...any)
	local profile = profiles[player]
	if profile == nil then
		return false, "PROFILE_NOT_READY"
	end

	local results = table.pack(pcall(mutator, profile.Data))
	local ok = results[1]
	if not ok then
		warn(("[DataService] Mutation failed for %d: %s"):format(player.UserId, tostring(results[2])))
		return false, "MUTATION_FAILED"
	end

	profile.Data.Revision += 1
	ProfileSanitizer.Sanitize(profile.Data)
	return true, table.unpack(results, 2, results.n)
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
