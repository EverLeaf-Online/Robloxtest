--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local serverRoot = script.Parent.Parent
local ProfileTemplate = require(serverRoot.Data.ProfileTemplate)
local DataService = require(serverRoot.Services.DataService)
local MonetizationService = require(serverRoot.Services.MonetizationService)
local PlotService = require(serverRoot.Services.PlotService)
local SalvageService = require(serverRoot.Services.SalvageServiceUnderTest)
local StateService = require(serverRoot.Services.StateService)
local WorldService = require(serverRoot.Services.WorldService)
local PlayerCharacter = require(serverRoot.Util.PlayerCharacter)

local function deepCopy(value: any): any
	if typeof(value) ~= "table" then
		return value
	end
	local result = {}
	for key, child in value do
		result[deepCopy(key)] = deepCopy(child)
	end
	return result
end

local function makeFakePlayer(): Player
	return Instance.new("Folder") :: any
end

local function makeNode(
	nodeId: string,
	zoneId: number,
	plotId: number?,
	position: Vector3
): BasePart
	local node = Instance.new("Part")
	node.Name = nodeId
	node.Anchored = true
	node.CanCollide = true
	node.Position = position
	node:SetAttribute("SalvageNodeId", nodeId)
	node:SetAttribute("ZoneId", zoneId)
	if plotId ~= nil then
		node:SetAttribute("PlotId", plotId)
	end

	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "CollectPrompt"
	prompt.Enabled = true
	prompt.Parent = node

	local presentation = Instance.new("Part")
	presentation.Name = "Presentation"
	presentation.Anchored = true
	presentation.CanCollide = false
	presentation:SetAttribute("PresentationPart", true)
	presentation.Parent = node

	WorldService.SetSalvageNode(nodeId, node)
	return node
end

local function resetFakes()
	DataService.Reset()
	MonetizationService.Reset()
	PlotService.Reset()
	StateService.Reset()
	WorldService.Reset()
	PlayerCharacter.Reset()
end

local function configurePlayer(player: Player, data: any, plotId: number?, position: Vector3)
	PlotService.SetStations(player, {
		PlotId = plotId,
	})
	PlayerCharacter.SetPosition(player, position)
	DataService.SetData(player, data)
end

describe("SalvageService integration", function()
	it("collects an owned nearby node once and disables it until respawn", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		local node = makeNode("salvage-owned-1", 1, 1, Vector3.new(4, 0, 0))
		configurePlayer(player, data, 1, Vector3.zero)

		SalvageService.Collect(player, "salvage-owned-1")

		expect(data.Materials.ScrapMetal >= 4).toBe(true)
		expect(data.Materials.ScrapMetal <= 6).toBe(true)
		expect(data.Materials.Wiring >= 1).toBe(true)
		expect(data.Tutorial.Milestones.FirstScrap).toBe(true)
		expect(data.Revision).toBe(1)
		expect(StateService.GetLastResult(player).Code).toBe("SALVAGE_COLLECTED")
		expect(StateService.GetSnapshotPushCount(player)).toBe(1)
		expect(node.CanCollide).toBe(false)
		expect((node:FindFirstChildOfClass("ProximityPrompt") :: ProximityPrompt).Enabled).toBe(
			false
		)

		player:Destroy()
		node:Destroy()
	end)

	it("allows only the first collector to win a shared-node race", function()
		resetFakes()
		local first = makeFakePlayer()
		local second = makeFakePlayer()
		local firstData = deepCopy(ProfileTemplate)
		local secondData = deepCopy(ProfileTemplate)
		local node = makeNode("salvage-race-1", 1, nil, Vector3.zero)
		configurePlayer(first, firstData, nil, Vector3.zero)
		configurePlayer(second, secondData, nil, Vector3.zero)

		SalvageService.Collect(first, "salvage-race-1")
		SalvageService.Collect(second, "salvage-race-1")

		expect(firstData.Revision).toBe(1)
		expect(firstData.Materials.ScrapMetal > 0).toBe(true)
		expect(StateService.GetLastResult(first).Code).toBe("SALVAGE_COLLECTED")

		expect(secondData.Revision).toBe(0)
		expect(secondData.Materials.ScrapMetal).toBe(0)
		expect(secondData.Materials.Wiring).toBe(0)
		expect(StateService.GetLastResult(second).Code).toBe("NODE_RESPAWNING")
		expect(StateService.GetSnapshotPushCount(second)).toBe(0)

		first:Destroy()
		second:Destroy()
		node:Destroy()
	end)

	it("rejects collection from another player's plot before mutation", function()
		resetFakes()
		local visitor = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		local node = makeNode("salvage-owner-isolation-1", 1, 1, Vector3.zero)
		configurePlayer(visitor, data, nil, Vector3.zero)

		SalvageService.Collect(visitor, "salvage-owner-isolation-1")

		expect(data.Revision).toBe(0)
		expect(data.Materials.ScrapMetal).toBe(0)
		expect(StateService.GetLastResult(visitor).Code).toBe("NOT_YOUR_PLOT")
		expect(StateService.GetSnapshotPushCount(visitor)).toBe(0)
		expect(node.CanCollide).toBe(true)

		visitor:Destroy()
		node:Destroy()
	end)

	it("rejects locked-zone salvage before claiming the node", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		local node = makeNode("salvage-locked-zone-1", 2, 1, Vector3.zero)
		configurePlayer(player, data, 1, Vector3.zero)

		SalvageService.Collect(player, "salvage-locked-zone-1")

		expect(data.Progression.Zone).toBe(1)
		expect(data.Revision).toBe(0)
		expect(data.Materials.ScrapMetal).toBe(0)
		expect(StateService.GetLastResult(player).Code).toBe("ZONE_LOCKED")
		expect(StateService.GetLastResult(player).Payload.RequiredZone).toBe(2)
		expect(node.CanCollide).toBe(true)

		player:Destroy()
		node:Destroy()
	end)

	it("rejects distant collection without consuming the node", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		local node = makeNode("salvage-distant-1", 1, 1, Vector3.zero)
		configurePlayer(
			player,
			data,
			1,
			Vector3.new(GameConfig.World.SalvageCollectDistance + 10, 0, 0)
		)

		SalvageService.Collect(player, "salvage-distant-1")

		expect(data.Revision).toBe(0)
		expect(data.Materials.ScrapMetal).toBe(0)
		expect(StateService.GetLastResult(player).Code).toBe("TOO_FAR_AWAY")
		expect(node.CanCollide).toBe(true)

		player:Destroy()
		node:Destroy()
	end)

	it("releases a failed storage-full claim so the same node can be retried", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		data.Materials.ScrapMetal = 50
		local node = makeNode("salvage-storage-retry-1", 1, 1, Vector3.zero)
		configurePlayer(player, data, 1, Vector3.zero)

		SalvageService.Collect(player, "salvage-storage-retry-1")

		expect(data.Revision).toBe(0)
		expect(data.Materials.ScrapMetal).toBe(50)
		expect(StateService.GetLastResult(player).Code).toBe("STORAGE_FULL")
		expect(node.CanCollide).toBe(true)

		data.Materials.ScrapMetal = 0
		SalvageService.Collect(player, "salvage-storage-retry-1")

		expect(data.Revision).toBe(1)
		expect(data.Materials.ScrapMetal > 0).toBe(true)
		expect(StateService.GetLastResult(player).Code).toBe("SALVAGE_COLLECTED")
		expect(node.CanCollide).toBe(false)

		player:Destroy()
		node:Destroy()
	end)

	it("releases a transaction-contention claim without awarding materials", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		local node = makeNode("salvage-contention-1", 1, 1, Vector3.zero)
		configurePlayer(player, data, 1, Vector3.zero)
		DataService.SetBusy(player, true)

		SalvageService.Collect(player, "salvage-contention-1")

		expect(data.Revision).toBe(0)
		expect(data.Materials.ScrapMetal).toBe(0)
		expect(StateService.GetLastResult(player).Code).toBe("TRANSACTION_BUSY")
		expect(node.CanCollide).toBe(true)

		DataService.SetBusy(player, false)
		SalvageService.Collect(player, "salvage-contention-1")

		expect(data.Revision).toBe(1)
		expect(data.Materials.ScrapMetal > 0).toBe(true)
		expect(StateService.GetLastResult(player).Code).toBe("SALVAGE_COLLECTED")

		player:Destroy()
		node:Destroy()
	end)

	it("auto-collect chooses the nearest accessible node and ignores locked zones", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		local locked = makeNode("salvage-auto-locked-1", 2, 1, Vector3.new(1, 0, 0))
		local allowed = makeNode("salvage-auto-allowed-1", 1, 1, Vector3.new(5, 0, 0))
		configurePlayer(player, data, 1, Vector3.zero)
		MonetizationService.SetAutoCollect(player, true)

		SalvageService.TryAutoCollect(player)

		expect(data.Revision).toBe(1)
		expect(data.Materials.ScrapMetal > 0).toBe(true)
		expect(StateService.GetLastResult(player).Code).toBe("SALVAGE_COLLECTED")
		expect(StateService.GetLastResult(player).Payload.NodeId).toBe("salvage-auto-allowed-1")
		expect(locked.CanCollide).toBe(true)
		expect(allowed.CanCollide).toBe(false)

		player:Destroy()
		locked:Destroy()
		allowed:Destroy()
	end)

	it("does nothing when auto-collect is not entitled", function()
		resetFakes()
		local player = makeFakePlayer()
		local data = deepCopy(ProfileTemplate)
		local node = makeNode("salvage-auto-disabled-1", 1, 1, Vector3.zero)
		configurePlayer(player, data, 1, Vector3.zero)

		SalvageService.TryAutoCollect(player)

		expect(data.Revision).toBe(0)
		expect(data.Materials.ScrapMetal).toBe(0)
		expect(StateService.GetLastResult(player)).toBe(nil)
		expect(node.CanCollide).toBe(true)

		player:Destroy()
		node:Destroy()
	end)
end)
