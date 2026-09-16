-- ServerScriptService/PlayerManager.server.lua
-- Handles player join/leave, remote connections, autosave, and shutdown saving.

local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local DataManager = require(script.Parent:WaitForChild("DataManager"))
local GameService = require(script.Parent:WaitForChild("GameService"))

local remotes = ReplicatedFirst:WaitForChild("Remotes", 30)
assert(remotes, "Remotes folder was not created.")

local applyAction = remotes:WaitForChild("ApplyAction")
local getPlanetState = remotes:WaitForChild("GetPlanetState")

local function onPlayerAdded(player)
	task.spawn(function()
		local data = DataManager.loadPlayer(player)
		local ownership = GameService.getGamePassOwnership(player)

		GameService.initPlayer(player, data, ownership)
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)

for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	DataManager.savePlayer(player)
	GameService.cleanup(player)
	DataManager.unloadPlayer(player)
end)

applyAction.OnServerEvent:Connect(function(player, actionType, tileIndex)
	GameService.tryAction(player, actionType, tileIndex)
end)

getPlanetState.OnServerInvoke = function(player)
	return GameService.getPlanetStateForClient(player)
end

-- Autosave every 60 seconds.
task.spawn(function()
	while true do
		task.wait(60)
		DataManager.saveAll()
	end
end)

game:BindToClose(function()
	DataManager.saveAll()
	task.wait(3)
end)