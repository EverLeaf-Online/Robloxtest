--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local HubSessionService = {}
local initialized = false

local function enforceCapacity(player: Player)
	if #Players:GetPlayers() <= GameConfig.Session.HubTargetPlayers then
		return
	end

	task.defer(function()
		if player.Parent == Players then
			player:Kick("This hub is full. Please reconnect to join another hub server.")
		end
	end)
end

function HubSessionService.Init()
	if initialized then
		return
	end
	initialized = true

	Players.PlayerAdded:Connect(enforceCapacity)
	for _, player in Players:GetPlayers() do
		enforceCapacity(player)
	end
end

return HubSessionService
