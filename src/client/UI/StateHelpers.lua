--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ObjectiveGuidanceRules = require(ReplicatedStorage.Shared.Domain.ObjectiveGuidanceRules)
local Robots = require(ReplicatedStorage.Shared.Config.Robots)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local StateHelpers = {}

function StateHelpers.FormatNumber(value: number): string
	if value >= 1_000_000_000 then
		return ("%.1fB"):format(value / 1_000_000_000)
	elseif value >= 1_000_000 then
		return ("%.1fM"):format(value / 1_000_000)
	elseif value >= 1_000 then
		return ("%.1fK"):format(value / 1_000)
	end
	return tostring(math.floor(value))
end

function StateHelpers.ReadableCode(code: string): string
	local text = string.gsub(code, "_", " ")
	return string.lower(text):gsub("^%l", string.upper)
end

function StateHelpers.MergeProductionDelta(currentSnapshot: any, delta: any): any
	if typeof(currentSnapshot) ~= "table" or typeof(delta) ~= "table" then
		return currentSnapshot
	end

	local currentRevision = currentSnapshot.Revision
	local deltaRevision = delta.Revision
	if
		typeof(currentRevision) == "number"
		and typeof(deltaRevision) == "number"
		and deltaRevision < currentRevision
	then
		return currentSnapshot
	end

	local nextSnapshot = table.clone(currentSnapshot)
	if typeof(deltaRevision) == "number" then
		nextSnapshot.Revision = deltaRevision
	end

	if typeof(delta.Currencies) == "table" and typeof(delta.Currencies.Credits) == "number" then
		local currencies = table.clone(currentSnapshot.Currencies)
		currencies.Credits = delta.Currencies.Credits
		nextSnapshot.Currencies = currencies
	end

	if typeof(delta.Stats) == "table" and typeof(delta.Stats.LifetimeCredits) == "number" then
		local stats = table.clone(currentSnapshot.Stats)
		stats.LifetimeCredits = delta.Stats.LifetimeCredits
		nextSnapshot.Stats = stats
	end

	if typeof(delta.Tutorial) == "table" and typeof(delta.Tutorial.Milestones) == "table" then
		local tutorial = table.clone(currentSnapshot.Tutorial)
		local milestones = table.clone(currentSnapshot.Tutorial.Milestones)
		if typeof(delta.Tutorial.Milestones.FirstIncomeEarned) == "boolean" then
			milestones.FirstIncomeEarned = delta.Tutorial.Milestones.FirstIncomeEarned
		end
		tutorial.Milestones = milestones
		nextSnapshot.Tutorial = tutorial
	end

	return nextSnapshot
end

function StateHelpers.PlotId(snapshot: any): number?
	if typeof(snapshot.Plot) ~= "table" or typeof(snapshot.Plot.Id) ~= "number" then
		return nil
	end
	return snapshot.Plot.Id
end

function StateHelpers.GetObjective(snapshot: any): (string, string)
	local step = ObjectiveGuidanceRules.GetStep(snapshot)
	local ownedPlotId = StateHelpers.PlotId(snapshot)
	local plotText = if ownedPlotId then " in your factory" else ""

	if step == "CollectScrap" then
		return "Collect scrap", "Follow the NEXT marker to a scrap pile and collect it."
	elseif step == "ProcessMaterials" then
		return "Process materials",
			("Follow NEXT to your processor%s and make wiring or recover a core."):format(plotText)
	elseif step == "BuildFirstBot" then
		return "Build your first bot",
			("Follow NEXT to your assembler%s once you have enough materials."):format(plotText)
	elseif step == "AssignFirstBot" then
		return "Put your bot to work",
			"Follow NEXT to BOT CONTROL and assign the bot to a work pad."
	elseif step == "EarnFirstCredits" then
		return "Earn your first credits", "Your assigned bot is working automatically."
	elseif step == "BuyFirstUpgrade" then
		return "Buy an upgrade", "Follow NEXT to the UPGRADES terminal at your factory."
	elseif step == "UnlockCircuitYard" then
		local zone = Zones[2]
		return "Unlock Circuit Yard",
			("Follow NEXT to the gate • %s/%s Credits • %d/%d bots built."):format(
				StateHelpers.FormatNumber(snapshot.Currencies.Credits),
				StateHelpers.FormatNumber(zone.UnlockCredits),
				math.min(snapshot.Stats.LifetimeRobotsBuilt, zone.RequiredLifetimeRobots),
				zone.RequiredLifetimeRobots
			)
	end

	return "Explore Circuit Yard", "Follow NEXT to its higher-value salvage piles."
end

function StateHelpers.GetAssignedPad(snapshot: any, robotUid: string): string?
	for padId, assignedUid in snapshot.Assignments.WorkPads do
		if assignedUid == robotUid then
			return padId
		end
	end
	return nil
end

function StateHelpers.FirstFreePad(snapshot: any, extraWorkSlots: number): string?
	local slots = math.min(
		GameConfig.Factory.MaxWorkSlots + 2,
		FactoryRules.GetWorkSlots(snapshot.Machines.WorkSlotsLevel) + extraWorkSlots
	)
	for index = 1, slots do
		local padId = ("Pad%d"):format(index)
		if snapshot.Assignments.WorkPads[padId] == nil then
			return padId
		end
	end
	return nil
end

function StateHelpers.CountOwnedRobots(snapshot: any): number
	local count = 0
	for _ in snapshot.Robots.OwnedByUid do
		count += 1
	end
	return count
end

function StateHelpers.CountOwnedRobotId(snapshot: any, robotId: string): number
	local count = 0
	for _, owned in snapshot.Robots.OwnedByUid do
		if owned.RobotId == robotId then
			count += 1
		end
	end
	return count
end

function StateHelpers.CountRobotDefinitions(): number
	local count = 0
	for _ in Robots.Definitions do
		count += 1
	end
	return count
end

function StateHelpers.CountDiscovered(snapshot: any): number
	local count = 0
	for robotId in Robots.Definitions do
		if snapshot.Collection.RobotSeen[robotId] == true then
			count += 1
		end
	end
	return count
end

function StateHelpers.MachineStatus(snapshot: any, now: number): string
	local processor = snapshot.Machines.ProcessorJob
	local assembler = snapshot.Machines.AssemblerJob
	local lines = {}
	local ownedPlotId = StateHelpers.PlotId(snapshot)

	table.insert(lines, if ownedPlotId then "Private Factory" else "Loading factory...")
	if processor.Active then
		local remaining = math.max(0, processor.CompletesAt - now)
		table.insert(
			lines,
			("Processor: %s (%ds)"):format(processor.RecipeId, math.ceil(remaining))
		)
	else
		table.insert(lines, "Processor: Ready")
	end
	if assembler.Active then
		local remaining = math.max(0, assembler.CompletesAt - now)
		table.insert(lines, ("Assembler: Building (%ds)"):format(math.ceil(remaining)))
	else
		table.insert(lines, "Assembler: Ready")
	end
	return table.concat(lines, "\n")
end

return table.freeze(StateHelpers)
