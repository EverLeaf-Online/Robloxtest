--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local ObjectiveGuidanceRules = require(script.Parent.Parent.Domain.ObjectiveGuidanceRules)

local function snapshot(): any
	return {
		Tutorial = {
			Milestones = {
				FirstScrap = false,
				FirstProcess = false,
				FirstBotReveal = false,
				FirstBotAssigned = false,
				FirstIncomeEarned = false,
				FirstUpgrade = false,
			},
		},
		Progression = {
			Zone = 1,
		},
	}
end

describe("ObjectiveGuidanceRules", function()
	it("advances through the first-session factory loop in order", function()
		local state = snapshot()
		local milestones = state.Tutorial.Milestones

		expect(ObjectiveGuidanceRules.GetStep(state)).toBe("CollectScrap")

		milestones.FirstScrap = true
		expect(ObjectiveGuidanceRules.GetStep(state)).toBe("ProcessMaterials")

		milestones.FirstProcess = true
		expect(ObjectiveGuidanceRules.GetStep(state)).toBe("BuildFirstBot")

		milestones.FirstBotReveal = true
		expect(ObjectiveGuidanceRules.GetStep(state)).toBe("AssignFirstBot")

		milestones.FirstBotAssigned = true
		expect(ObjectiveGuidanceRules.GetStep(state)).toBe("EarnFirstCredits")

		milestones.FirstIncomeEarned = true
		expect(ObjectiveGuidanceRules.GetStep(state)).toBe("BuyFirstUpgrade")

		milestones.FirstUpgrade = true
		expect(ObjectiveGuidanceRules.GetStep(state)).toBe("UnlockCircuitYard")

		state.Progression.Zone = 2
		expect(ObjectiveGuidanceRules.GetStep(state)).toBe("ExploreCircuitYard")
	end)

	it("fails closed to the first objective when snapshot state is incomplete", function()
		expect(ObjectiveGuidanceRules.GetStep(nil)).toBe("CollectScrap")
		expect(ObjectiveGuidanceRules.GetStep({})).toBe("CollectScrap")
		expect(ObjectiveGuidanceRules.GetStep({ Tutorial = {} })).toBe("CollectScrap")
	end)
end)
