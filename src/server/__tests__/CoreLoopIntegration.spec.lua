--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)

local serverRoot = script.Parent.Parent
local ProfileTemplate = require(serverRoot.Data.ProfileTemplate)
local AnalyticsService = require(serverRoot.Services.AnalyticsService)
local DataService = require(serverRoot.Services.DataService)
local MachineService = require(serverRoot.Services.MachineService)
local MonetizationService = require(serverRoot.Services.MonetizationService)
local PlotService = require(serverRoot.Services.PlotService)
local ProductionService = require(serverRoot.Services.ProductionServiceUnderTest)
local RobotService = require(serverRoot.Services.RobotService)
local SalvageService = require(serverRoot.Services.SalvageServiceUnderTest)
local StateService = require(serverRoot.Services.StateService)
local UpgradeService = require(serverRoot.Services.UpgradeServiceUnderTest)
local WorldService = require(serverRoot.Services.WorldService)
local PlayerCharacter = require(serverRoot.Util.PlayerCharacter)

local nextUserId = 98000

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

local function fakePlayer(): Player
	nextUserId += 1
	local attributes: { [string]: any } = {}
	local player: any = {
		UserId = nextUserId,
		Parent = nil,
	}
	function player:SetAttribute(name: string, value: any)
		attributes[name] = value
	end
	function player:GetAttribute(name: string): any
		return attributes[name]
	end
	return player :: Player
end

local function station(name: string): BasePart
	local part = Instance.new("Part")
	part.Name = name
	part.Anchored = true
	part:SetAttribute("PlotId", 1)
	return part
end

local function salvageNode(nodeId: string, x: number): BasePart
	local node = station(nodeId)
	node.Position = Vector3.new(x, 0, 0)
	node:SetAttribute("SalvageNodeId", nodeId)
	node:SetAttribute("ZoneId", 1)

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
	AnalyticsService.Reset()
	DataService.Reset()
	MonetizationService.Reset()
	PlotService.Reset()
	StateService.Reset()
	WorldService.Reset()
	PlayerCharacter.Reset()
end

describe("First-session core loop integration", function()
	it(
		"runs salvage -> process -> assemble -> assign -> produce -> upgrade through real services",
		function()
			resetFakes()

			local player = fakePlayer()
			local data = deepCopy(ProfileTemplate)
			data.Consumables.InstantProcessTokens = 3
			DataService.SetData(player, data)
			PlayerCharacter.SetNear(player, true)
			PlayerCharacter.SetPosition(player, Vector3.zero)

			local processor = station("ProcessorControl")
			processor:SetAttribute("ProcessorRecipeId", "MakeWiring")
			local assembler = station("Assembler")
			local botConsole = station("BotConsole")
			local recycleStation = station("RecycleStation")
			local upgradeConsole = station("UpgradeConsole")
			local storageStation = station("StorageBin2")

			PlotService.SetStations(player, {
				PlotId = 1,
				ProcessorControls = {
					MakeWiring = processor,
					RecoverCore = processor,
				},
				Assembler = assembler,
				BotConsole = botConsole,
				RecycleStation = recycleStation,
				UpgradeConsole = upgradeConsole,
				StorageStation = storageStation,
			})

			local nodes = {
				salvageNode("core-loop-salvage-1", 2),
				salvageNode("core-loop-salvage-2", 4),
				salvageNode("core-loop-salvage-3", 6),
				salvageNode("core-loop-salvage-4", 8),
				salvageNode("core-loop-salvage-5", 10),
				salvageNode("core-loop-salvage-6", 12),
			}

			for _, node in nodes do
				SalvageService.Collect(player, node.Name)
				expect(StateService.GetLastResult(player).Code).toBe("SALVAGE_COLLECTED")
			end

			-- Six Starter Yard nodes guarantee at least 14 scrap total because the
			-- first collection includes the 2-scrap tutorial bonus. The first collect
			-- also guarantees one wiring, so the wiring -> core -> first robot sequence
			-- remains deterministic despite the ordinary salvage RNG.
			expect(data.Materials.ScrapMetal >= 14).toBe(true)
			expect(data.Materials.Wiring >= 1).toBe(true)
			expect(data.Tutorial.Milestones.FirstScrap).toBe(true)

			MachineService.StartProcessor(player, "MakeWiring")
			expect(StateService.GetLastResult(player).Code).toBe("PROCESS_STARTED")
			expect(data.Machines.ProcessorJob.Active).toBe(true)

			MachineService.UseInstantProcessToken(player)
			expect(StateService.GetLastResult(player).Code).toBe("PROCESS_COMPLETE")
			expect(data.Machines.ProcessorJob.Active).toBe(false)
			expect(data.Materials.ScrapMetal >= 10).toBe(true)
			expect(data.Materials.Wiring >= 2).toBe(true)
			expect(data.Consumables.InstantProcessTokens).toBe(2)
			expect(data.Tutorial.Milestones.FirstProcess).toBe(true)
			expect(data.Tutorial.Milestones.FirstWiring).toBe(true)

			MachineService.StartProcessor(player, "RecoverCore")
			expect(StateService.GetLastResult(player).Code).toBe("PROCESS_STARTED")
			expect(data.Machines.ProcessorJob.Active).toBe(true)

			MachineService.UseInstantProcessToken(player)
			expect(StateService.GetLastResult(player).Code).toBe("PROCESS_COMPLETE")
			expect(data.Machines.ProcessorJob.Active).toBe(false)
			expect(data.Materials.PowerCoreFragments >= 1).toBe(true)
			expect(data.Materials.Wiring >= 1).toBe(true)
			expect(data.Consumables.InstantProcessTokens).toBe(1)
			expect(data.Tutorial.Milestones.FirstCore).toBe(true)

			MachineService.StartAssembler(player)
			expect(StateService.GetLastResult(player).Code).toBe("ASSEMBLY_STARTED")
			expect(data.Machines.AssemblerJob.Active).toBe(true)

			MachineService.UseInstantProcessToken(player)
			expect(StateService.GetLastResult(player).Code).toBe("ASSEMBLY_COMPLETE")
			expect(data.Machines.AssemblerJob.Active).toBe(false)
			expect(data.Consumables.InstantProcessTokens).toBe(0)
			expect(data.Stats.LifetimeRobotsBuilt).toBe(1)
			expect(data.Tutorial.Milestones.FirstBotReveal).toBe(true)

			local robotUid: string? = nil
			for uid in data.Robots.OwnedByUid do
				robotUid = uid
				break
			end
			expect(robotUid ~= nil).toBe(true)

			RobotService.Assign(player, robotUid :: string, "Pad1")
			expect(StateService.GetLastResult(player).Code).toBe("ROBOT_ASSIGNED")
			expect(data.Assignments.WorkPads.Pad1).toBe(robotUid)
			expect(data.Tutorial.Milestones.FirstBotAssigned).toBe(true)

			local now = os.time()
			data.Timestamps.LastProductionTick = now - 600
			data.Timestamps.LastLeave = now - 600
			local producedCredits = ProductionService.ApplyOfflineProduction(player)

			expect(producedCredits >= 300).toBe(true)
			expect(data.Currencies.Credits).toBe(producedCredits)
			expect(data.Tutorial.Milestones.FirstIncomeEarned).toBe(true)
			expect(StateService.GetProductionDeltaCount(player)).toBe(1)

			local upgradeCost = Upgrades.ProcessorSpeed.Levels[2].CostCredits
			expect(data.Currencies.Credits >= upgradeCost).toBe(true)
			UpgradeService.Purchase(player, "ProcessorSpeed")

			expect(StateService.GetLastResult(player).Code).toBe("UPGRADE_PURCHASED")
			expect(data.Machines.ProcessorLevel).toBe(2)
			expect(data.Currencies.Credits).toBe(producedCredits - upgradeCost)
			expect(data.Tutorial.Milestones.FirstUpgrade).toBe(true)

			local sources = AnalyticsService.GetCreditSources()
			local sinks = AnalyticsService.GetCreditSinks()
			expect(#sources).toBe(1)
			expect(sources[1].Source).toBe("OfflineBotProduction")
			expect(sources[1].Amount).toBe(producedCredits)
			expect(#sinks).toBe(1)
			expect(sinks[1].Source).toBe("Upgrade:ProcessorSpeed")
			expect(sinks[1].Amount).toBe(upgradeCost)

			for _, instance in
				{
					processor,
					assembler,
					botConsole,
					recycleStation,
					upgradeConsole,
					storageStation,
					table.unpack(nodes),
				}
			do
				instance:Destroy()
			end
		end
	)
end)
