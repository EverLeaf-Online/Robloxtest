--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local Salvage = require(ReplicatedStorage.Shared.Config.Salvage)
local Validation = require(ReplicatedStorage.Shared.Util.Validation)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local RateLimiter = require(script.Parent.RateLimiter)
local RemoteService = require(script.Parent.RemoteService)
local StateService = require(script.Parent.StateService)
local WorldService = require(script.Parent.WorldService)

local SalvageService = {}
local initialized = false
local random = Random.new()
local nodeActive: { [string]: boolean } = {}

local function result(success: boolean, code: string, payload: any?): any
	return {
		Success = success,
		Code = code,
		Payload = payload,
	}
end

local function playerPosition(player: Player): Vector3?
	local character = player.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root.Position
end

local function setNodeActive(nodeId: string, active: boolean)
	local node = WorldService.GetSalvageNode(nodeId)
	if node == nil then
		return
	end

	nodeActive[nodeId] = active
	node.Transparency = if active then 0 else 0.75
	node.CanCollide = active
	local prompt = node:FindFirstChildOfClass("ProximityPrompt")
	if prompt then
		prompt.Enabled = active
	end
end

local function makeRewards(zoneId: number, firstCollect: boolean): { [string]: number }
	local zone = Zones[zoneId]
	assert(zone ~= nil, "salvage node must reference a configured zone")
	local tuning = zone.Salvage
	local rewards: { [string]: number } = {
		ScrapMetal = random:NextInteger(tuning.ScrapMin, tuning.ScrapMax),
	}

	if random:NextNumber() < tuning.WiringChance then
		rewards.Wiring = 1
	end
	if random:NextNumber() < tuning.CoreChance then
		rewards.PowerCoreFragments = 1
	end

	if firstCollect then
		for materialId, amount in Salvage.FirstCollectBonus do
			rewards[materialId] = (rewards[materialId] or 0) + amount
		end
	end

	return rewards
end

function SalvageService.Collect(player: Player, nodeId: any)
	if not Validation.isBoundedString(nodeId, GameConfig.Networking.MaxStringLength) then
		StateService.ActionResult(player, RemoteNames.RequestCollect, false, "INVALID_NODE_ID", nil)
		return
	end

	local node = WorldService.GetSalvageNode(nodeId)
	if node == nil then
		StateService.ActionResult(player, RemoteNames.RequestCollect, false, "UNKNOWN_NODE", nil)
		return
	end
	if nodeActive[nodeId] ~= true then
		StateService.ActionResult(player, RemoteNames.RequestCollect, false, "NODE_RESPAWNING", nil)
		return
	end

	local zoneId = node:GetAttribute("ZoneId")
	if not Validation.isSafeInteger(zoneId, 1, 100) or Zones[zoneId :: number] == nil then
		StateService.ActionResult(player, RemoteNames.RequestCollect, false, "INVALID_NODE_ZONE", nil)
		return
	end
	local authoritativeZoneId = zoneId :: number

	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	if data.Progression.Zone < authoritativeZoneId then
		StateService.ActionResult(player, RemoteNames.RequestCollect, false, "ZONE_LOCKED", {
			RequiredZone = authoritativeZoneId,
		})
		return
	end

	local position = playerPosition(player)
	if
		position == nil
		or (position - node.Position).Magnitude > GameConfig.World.SalvageCollectDistance
	then
		StateService.ActionResult(player, RemoteNames.RequestCollect, false, "TOO_FAR_AWAY", nil)
		return
	end

	local firstCollect = data.Tutorial.Milestones.FirstScrap ~= true
	local rewards = makeRewards(authoritativeZoneId, firstCollect)

	local executed, transactionResult = DataService.Transaction(player, function(profileData)
		if profileData.Progression.Zone < authoritativeZoneId then
			return false, result(false, "ZONE_LOCKED", { RequiredZone = authoritativeZoneId })
		end
		if not EconomyService.GrantMaterials(profileData, rewards) then
			return false, result(false, "STORAGE_FULL", nil)
		end
		profileData.Tutorial.Milestones.FirstScrap = true
		return true,
			result(true, "SALVAGE_COLLECTED", {
				NodeId = nodeId,
				ZoneId = authoritativeZoneId,
				Rewards = rewards,
			})
	end)

	if not executed then
		StateService.ActionResult(
			player,
			RemoteNames.RequestCollect,
			false,
			tostring(transactionResult),
			nil
		)
		return
	end
	if typeof(transactionResult) ~= "table" then
		StateService.ActionResult(
			player,
			RemoteNames.RequestCollect,
			false,
			"INVALID_TRANSACTION_RESULT",
			nil
		)
		return
	end

	StateService.ActionResult(
		player,
		RemoteNames.RequestCollect,
		transactionResult.Success == true,
		tostring(transactionResult.Code),
		transactionResult.Payload
	)
	if transactionResult.Success ~= true then
		return
	end

	setNodeActive(nodeId, false)
	StateService.PushSnapshot(player)
	task.delay(GameConfig.World.NodeRespawnSeconds, function()
		setNodeActive(nodeId, true)
	end)
end

function SalvageService.Init()
	if initialized then
		return
	end
	initialized = true

	for nodeId, node in WorldService.GetSalvageNodes() do
		nodeActive[nodeId] = true
		local prompt = node:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				if RateLimiter.Consume(player, RemoteNames.RequestCollect) then
					SalvageService.Collect(player, nodeId)
				end
			end)
		end
	end

	RemoteService.BindRequest(RemoteNames.RequestCollect, function(player, nodeId)
		SalvageService.Collect(player, nodeId)
	end)
end

return SalvageService
