--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
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
	local milestones = snapshot.Tutorial.Milestones
	local ownedPlotId = StateHelpers.PlotId(snapshot)
	local plotText = if ownedPlotId then " in your factory" else ""
	if milestones.FirstScrap ~= true then
		return "Collect scrap", "Walk to a scrap pile and use its Collect prompt."
	elseif milestones.FirstProcess ~= true then
		return "Process materials",
			("Use your processor%s to make wiring or recover a core."):format(plotText)
	elseif milestones.FirstBotReveal ~= true then
		return "Build your first bot",
			("Use your assembler%s once you have enough materials."):format(plotText)
	elseif milestones.FirstBotAssigned ~= true then
		return "Put your bot to work",
			"Use the BOT CONTROL terminal and assign the bot to a work pad."
	elseif milestones.FirstIncomeEarned ~= true then
		return "Earn your first credits", "Your assigned bot produces credits automatically."
	elseif milestones.FirstUpgrade ~= true then
		return "Buy an upgrade", "Use the UPGRADES terminal at your factory."
	elseif snapshot.Progression.Zone < 2 then
		local zone = Zones[2]
		return "Unlock Circuit Yard",
			("Gate progress: %s/%s Credits • %d/%d bots built."):format(
				StateHelpers.FormatNumber(snapshot.Currencies.Credits),
				StateHelpers.FormatNumber(zone.UnlockCredits),
				math.min(snapshot.Stats.LifetimeRobotsBuilt, zone.RequiredLifetimeRobots),
				zone.RequiredLifetimeRobots
			)
	end
	return "Explore Circuit Yard", "Its salvage piles have better wiring and core-fragment yields."
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
