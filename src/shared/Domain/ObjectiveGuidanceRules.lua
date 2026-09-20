--!strict

export type ObjectiveStep =
	"CollectScrap"
	| "MakeWiring"
	| "RecoverCore"
	| "BuildFirstBot"
	| "AssignFirstBot"
	| "EarnFirstCredits"
	| "BuyFirstUpgrade"
	| "UnlockCircuitYard"
	| "ExploreCircuitYard"

local ObjectiveGuidanceRules = {}

function ObjectiveGuidanceRules.GetStep(snapshot: any): ObjectiveStep
	if typeof(snapshot) ~= "table" then
		return "CollectScrap"
	end

	local tutorial = snapshot.Tutorial
	local milestones = if typeof(tutorial) == "table" then tutorial.Milestones else nil
	if typeof(milestones) ~= "table" then
		return "CollectScrap"
	end

	if milestones.FirstScrap ~= true then
		return "CollectScrap"
	elseif milestones.FirstBotReveal ~= true and milestones.FirstWiring ~= true then
		return "MakeWiring"
	elseif milestones.FirstBotReveal ~= true and milestones.FirstCore ~= true then
		return "RecoverCore"
	elseif milestones.FirstBotReveal ~= true then
		return "BuildFirstBot"
	elseif milestones.FirstBotAssigned ~= true then
		return "AssignFirstBot"
	elseif milestones.FirstIncomeEarned ~= true then
		return "EarnFirstCredits"
	elseif milestones.FirstUpgrade ~= true then
		return "BuyFirstUpgrade"
	end

	local progression = snapshot.Progression
	local zone = if typeof(progression) == "table" and typeof(progression.Zone) == "number"
		then progression.Zone
		else 1
	if zone < 2 then
		return "UnlockCircuitYard"
	end

	return "ExploreCircuitYard"
end

return table.freeze(ObjectiveGuidanceRules)
