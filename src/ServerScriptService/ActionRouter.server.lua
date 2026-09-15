local Players = game:GetService("Players")
local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local TileGeometry = require(ReplicatedStorage.Shared.TileGeometry)
local PlanetStateService = require(script.Parent.PlanetStateService)
local MilestoneSystem = require(script.Parent.MilestoneSystem)
local WaterSystem = require(script.Parent.WaterSystem)
local PlantSystem = require(script.Parent.PlantSystem)
local AnimalSystem = require(script.Parent.AnimalSystem)
local SettlementSystem = require(script.Parent.SettlementSystem)
local TerraformSystem = require(script.Parent.TerraformSystem)

local remotes = ReplicatedFirst:WaitForChild("Remotes")
local applyAction = remotes:WaitForChild("ApplyAction")
local updateEnergy = remotes:WaitForChild("UpdateEnergy")
local updateTile = remotes:WaitForChild("UpdateTile")
local stateUpdated = remotes:WaitForChild("StateUpdated")
local notify = remotes:WaitForChild("Notify")
local getPlanetState = remotes:WaitForChild("GetPlanetState")

local handlers = {
	AddWater = WaterSystem,
	AddPlants = PlantSystem,
	AddAnimals = AnimalSystem,
	BuildSettlement = SettlementSystem,
	TerraformBurst = TerraformSystem,
}

local lastGlobalAction = {}
local lastActionByType = {}
local busy = {}

local function validatePayload(payload)
	if type(payload) ~= "table" then
		return nil, nil, "Invalid request."
	end
	local actionType = payload.actionType
	if type(actionType) ~= "string" or not handlers[actionType] then
		return nil, nil, "Unknown action."
	end
	local tileIndex = payload.tileIndex
	if tileIndex ~= nil and not TileGeometry.IsValidIndex(tileIndex) then
		return nil, nil, "Invalid tile selection."
	end
	return actionType, tileIndex, nil
end

local function isRateLimited(player, actionType)
	local now = os.clock()
	local userId = player.UserId
	if now - (lastGlobalAction[userId] or -math.huge) < Config.ACTION_COOLDOWN then
		return true
	end
	lastActionByType[userId] = lastActionByType[userId] or {}
	local actionCooldown = Config.ACTION_COOLDOWNS[actionType] or Config.ACTION_COOLDOWN
	if now - (lastActionByType[userId][actionType] or -math.huge) < actionCooldown then
		return true
	end
	lastGlobalAction[userId] = now
	lastActionByType[userId][actionType] = now
	return false
end

applyAction.OnServerEvent:Connect(function(player, payload)
	if not PlanetStateService.IsLoaded(player) then
		notify:FireClient(player, "Planet data is still loading.", "error")
		return
	end
	if busy[player.UserId] then
		return
	end

	local actionType, tileIndex, validationError = validatePayload(payload)
	if validationError then
		notify:FireClient(player, validationError, "error")
		return
	end
	if isRateLimited(player, actionType) then
		notify:FireClient(player, "Please wait before using another action.", "warning")
		return
	end

	busy[player.UserId] = true
	local ok, success, message, tileUpdates = pcall(function()
		return handlers[actionType].Apply(player, tileIndex)
	end)
	busy[player.UserId] = nil

	if not ok then
		warn(string.format("[ActionRouter] %s failed for %s: %s", actionType, player.Name, tostring(success)))
		notify:FireClient(player, "That action could not be completed.", "error")
		return
	end
	if not success then
		notify:FireClient(player, message or "Action rejected.", "warning")
		return
	end

	MilestoneSystem.Check(player)
	PlanetStateService.QueueSave(player)

	local state = PlanetStateService.GetState(player)
	updateEnergy:FireClient(player, state.Energy)
	if type(tileUpdates) == "table" then
		for _, update in ipairs(tileUpdates) do
			updateTile:FireClient(player, update)
		end
	end
	stateUpdated:FireClient(player, PlanetStateService.GetSummary(player))
	notify:FireClient(player, message or "Action complete.", "success")
end)

getPlanetState.OnServerInvoke = function(player)
	return PlanetStateService.GetPublicState(player)
end

Players.PlayerRemoving:Connect(function(player)
	lastGlobalAction[player.UserId] = nil
	lastActionByType[player.UserId] = nil
	busy[player.UserId] = nil
end)
