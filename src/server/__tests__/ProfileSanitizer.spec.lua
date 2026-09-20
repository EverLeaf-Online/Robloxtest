--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)

local serverRoot = script.Parent.Parent
local ProfileSanitizer = require(serverRoot.Data.ProfileSanitizer)
local ProfileTemplate = require(serverRoot.Data.ProfileTemplate)

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

describe("ProfileSanitizer", function()
	it("clears malformed current-schema server-overclock lease ids on reconnect", function()
		local data = deepCopy(ProfileTemplate)
		data.Entitlements.ServerOverclockUntil = 1_900_000_000
		data.Entitlements.ServerOverclockLeaseId = string.rep("L", 129)

		ProfileSanitizer.Sanitize(data)

		expect(data.Version).toBe(GameConfig.ProfileSchemaVersion)
		expect(data.Entitlements.ServerOverclockUntil).toBe(1_900_000_000)
		expect(data.Entitlements.ServerOverclockLeaseId).toBe("")
	end)

	it("preserves a bounded valid server-overclock lease id", function()
		local data = deepCopy(ProfileTemplate)
		data.Entitlements.ServerOverclockUntil = 1_900_000_000
		data.Entitlements.ServerOverclockLeaseId = "lease-job-abc"

		ProfileSanitizer.Sanitize(data)

		expect(data.Entitlements.ServerOverclockLeaseId).toBe("lease-job-abc")
	end)

	it("repairs malformed persisted economy, jobs, assignments, flags, and receipts", function()
		local data = deepCopy(ProfileTemplate)
		data.Revision = -50
		data.Currencies.Credits = -10
		data.Materials.ScrapMetal = -5
		data.Materials.UnknownMaterial = 999
		data.Consumables.InstantProcessTokens = GameConfig.Economy.MaxInstantProcessTokens + 1

		data.Robots.OwnedByUid.BadUid = {
			RobotId = "NotARobot",
			AcquiredAt = -5,
		}
		data.Robots.NextUid = -1
		data.Assignments.WorkPads.Pad1 = "BadUid"

		data.Machines.ProcessorLevel = 999
		data.Machines.ProcessorJob = {
			Active = true,
			RecipeId = "ForgedRecipe",
			StartedAt = 100,
			CompletesAt = 50,
		}
		data.Machines.AssemblerJob = {
			Active = true,
			StartedAt = -1,
			CompletesAt = math.huge,
		}

		data.Entitlements.CachedPassFlags = {
			Production2x = true,
			ForgedPass = true,
			ExpandedStorage = "yes",
		}
		data.Entitlements.ServerOverclockLeaseId = 12345
		data.Entitlements.FactoryClubCosmetics = {
			[""] = true,
			[string.rep("X", 33)] = true,
			ValidCosmetic = false,
		}
		data.Entitlements.EquippedFactoryClubCosmetic = "MissingCosmetic"

		data.Receipts.RecentPurchaseIds = {
			"purchase-a",
			"purchase-a",
			string.rep("Y", 129),
			42,
			"purchase-b",
		}

		ProfileSanitizer.Sanitize(data)

		expect(data.Revision).toBe(0)
		expect(data.Currencies.Credits).toBe(0)
		expect(data.Materials.ScrapMetal).toBe(0)
		expect(data.Materials.UnknownMaterial).toBe(nil)
		expect(data.Consumables.InstantProcessTokens).toBe(0)

		expect(next(data.Robots.OwnedByUid)).toBe(nil)
		expect(data.Robots.NextUid).toBe(1)
		expect(next(data.Assignments.WorkPads)).toBe(nil)

		expect(data.Machines.ProcessorLevel).toBe(#Upgrades.ProcessorSpeed.Levels)
		expect(data.Machines.ProcessorJob.Active).toBe(false)
		expect(data.Machines.ProcessorJob.RecipeId).toBe("")
		expect(data.Machines.ProcessorJob.StartedAt).toBe(0)
		expect(data.Machines.ProcessorJob.CompletesAt).toBe(0)
		expect(data.Machines.AssemblerJob.Active).toBe(false)
		expect(data.Machines.AssemblerJob.StartedAt).toBe(0)
		expect(data.Machines.AssemblerJob.CompletesAt).toBe(0)

		expect(data.Entitlements.CachedPassFlags.Production2x).toBe(true)
		expect(data.Entitlements.CachedPassFlags.ForgedPass).toBe(nil)
		expect(data.Entitlements.CachedPassFlags.ExpandedStorage).toBe(nil)
		expect(data.Entitlements.ServerOverclockLeaseId).toBe("")
		expect(next(data.Entitlements.FactoryClubCosmetics)).toBe(nil)
		expect(data.Entitlements.EquippedFactoryClubCosmetic).toBe("")

		expect(#data.Receipts.RecentPurchaseIds).toBe(2)
		expect(data.Receipts.RecentPurchaseIds[1]).toBe("purchase-a")
		expect(data.Receipts.RecentPurchaseIds[2]).toBe("purchase-b")
	end)

	it("preserves valid reconnect-critical production and entitlement state", function()
		local data = deepCopy(ProfileTemplate)
		data.Revision = 42
		data.Currencies.Credits = 12_345
		data.Materials.ScrapMetal = 12
		data.Materials.Wiring = 4
		data.Consumables.InstantProcessTokens = 3
		data.Robots.OwnedByUid.R1 = {
			RobotId = "TinScout",
			AcquiredAt = 1_800_000_000,
		}
		data.Robots.NextUid = 2
		data.Assignments.WorkPads.Pad1 = "R1"
		data.Machines.ProcessorJob = {
			Active = true,
			RecipeId = "MakeWiring",
			StartedAt = 1_800_000_000,
			CompletesAt = 1_800_000_030,
		}
		data.Machines.AssemblerJob = {
			Active = true,
			StartedAt = 1_800_000_000,
			CompletesAt = 1_800_000_045,
		}
		data.Progression.Zone = 2
		data.Entitlements.CachedPassFlags.Production2x = true
		data.Entitlements.CachedPassFlags.BotWorkSlots2 = true
		data.Entitlements.ServerOverclockUntil = 1_900_000_000
		data.Entitlements.ServerOverclockLeaseId = "lease-reconnect-1"
		data.Receipts.RecentPurchaseIds = { "purchase-1", "purchase-2" }

		ProfileSanitizer.Sanitize(data)

		expect(data.Revision).toBe(42)
		expect(data.Currencies.Credits).toBe(12_345)
		expect(data.Materials.ScrapMetal).toBe(12)
		expect(data.Materials.Wiring).toBe(4)
		expect(data.Consumables.InstantProcessTokens).toBe(3)
		expect(data.Robots.OwnedByUid.R1.RobotId).toBe("TinScout")
		expect(data.Assignments.WorkPads.Pad1).toBe("R1")
		expect(data.Machines.ProcessorJob.Active).toBe(true)
		expect(data.Machines.ProcessorJob.RecipeId).toBe("MakeWiring")
		expect(data.Machines.AssemblerJob.Active).toBe(true)
		expect(data.Progression.Zone).toBe(2)
		expect(data.Entitlements.CachedPassFlags.Production2x).toBe(true)
		expect(data.Entitlements.CachedPassFlags.BotWorkSlots2).toBe(true)
		expect(data.Entitlements.ServerOverclockLeaseId).toBe("lease-reconnect-1")
		expect(#data.Receipts.RecentPurchaseIds).toBe(2)
	end)
end)
