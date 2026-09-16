local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")

local DataManager = require(script.Parent:WaitForChild("DataManager"))
local GameService = require(script.Parent:WaitForChild("GameService"))

local remotes = ReplicatedFirst:WaitForChild("Remotes")
local applyAction = remotes:WaitForChild("ApplyAction")
local getPlanetState = remotes:WaitForChild("GetPlanetState")

local initializing = {}

local function onPlayerAdded(player)
	if initializing[player] then
		return
	end
	initializing[player] = true
	player:SetAttribute("PlanetReady", false)
	player:SetAttribute("PlanetInitError", "")

	task.spawn(function()
		local ok, err = pcall(function()
			local data = DataManager.loadPlayer(player)
			if not player.Parent then
				return
			end
			local ownership = GameService.getGamePassOwnership(player)
			GameService.initPlayer(player, data, ownership)
		end)

		initializing[player] = nil
		if not ok then
			warn(string.format("[Grow a Tiny Planet] Failed to initialize %s: %s", player.Name, tostring(err)))
			player:SetAttribute("PlanetInitError", tostring(err))
			player:SetAttribute("PlanetReady", false)
		end
	end)
end

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	initializing[player] = nil
	DataManager.savePlayer(player, true)
	GameService.cleanup(player)
	DataManager.unloadPlayer(player)
end)

applyAction.OnServerEvent:Connect(function(player, actionType, tileIndex)
	if player:GetAttribute("PlanetReady") ~= true then
		return
	end
	GameService.tryAction(player, actionType, tileIndex)
end)

getPlanetState.OnServerInvoke = function(player)
	if player:GetAttribute("PlanetReady") ~= true then
		return nil
	end
	return GameService.getPlanetStateForClient(player)
end

-- Periodic safety flush. DataManager writes only players that are actually dirty.
task.spawn(function()
	while true do
		task.wait(60)
		DataManager.saveAll(false)
	end
end)

game:BindToClose(function()
	DataManager.saveAll(true)
	task.wait(2)
end)
