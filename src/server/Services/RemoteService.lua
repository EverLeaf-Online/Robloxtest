--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local RateLimiter = require(script.Parent.RateLimiter)

local REMOTE_FOLDER_NAME = "Remotes"

local requestNames = {
	RemoteNames.RequestCollect,
	RemoteNames.RequestProcess,
	RemoteNames.RequestAssemble,
	RemoteNames.RequestAssignRobot,
	RemoteNames.RequestSellRobot,
	RemoteNames.RequestUpgrade,
	RemoteNames.RequestUnlockZone,
	RemoteNames.RequestPrestige,
}

local outboundNames = {
	RemoteNames.StateSnapshot,
	RemoteNames.StateDelta,
	RemoteNames.ActionResult,
}

local RemoteService = {}
local remotes: { [string]: RemoteEvent } = {}
local initialized = false

local function getOrCreateFolder(): Folder
	local existing = ReplicatedStorage:FindFirstChild(REMOTE_FOLDER_NAME)
	if existing then
		assert(existing:IsA("Folder"), ("ReplicatedStorage.%s must be a Folder"):format(REMOTE_FOLDER_NAME))
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = REMOTE_FOLDER_NAME
	folder.Parent = ReplicatedStorage
	return folder
end

local function getOrCreateRemote(folder: Folder, name: string): RemoteEvent
	local existing = folder:FindFirstChild(name)
	if existing then
		assert(existing:IsA("RemoteEvent"), ("Remote %s must be a RemoteEvent"):format(name))
		return existing
	end

	local remote = Instance.new("RemoteEvent")
	remote.Name = name
	remote.Parent = folder
	return remote
end

function RemoteService.Init()
	if initialized then
		return
	end
	initialized = true

	local folder = getOrCreateFolder()
	for _, name in requestNames do
		remotes[name] = getOrCreateRemote(folder, name)
	end
	for _, name in outboundNames do
		remotes[name] = getOrCreateRemote(folder, name)
	end

	Players.PlayerRemoving:Connect(function(player)
		RateLimiter.Forget(player)
	end)
end

function RemoteService.Get(name: string): RemoteEvent
	assert(initialized, "RemoteService.Init() must run before RemoteService.Get()")
	local remote = remotes[name]
	assert(remote ~= nil, ("Unknown remote: %s"):format(name))
	return remote
end

function RemoteService.BindRequest(name: string, handler: (Player, ...any) -> ())
	assert(table.find(requestNames, name) ~= nil, ("%s is not a request remote"):format(name))
	local remote = RemoteService.Get(name)

	remote.OnServerEvent:Connect(function(player, ...)
		if not RateLimiter.Consume(player, name) then
			return
		end

		local ok, err = pcall(handler, player, ...)
		if not ok then
			warn(("[RemoteService] %s failed for %d: %s"):format(name, player.UserId, tostring(err)))
		end
	end)
end

return RemoteService
