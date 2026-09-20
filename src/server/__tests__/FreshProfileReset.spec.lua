--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it

local serverRoot = script.Parent.Parent
local FreshProfileReset = require(serverRoot.Data.FreshProfileReset)
local ProfileTemplate = require(serverRoot.Data.ProfileTemplate)
local TransactionRules = require(ReplicatedStorage.Shared.Domain.TransactionRules)

local function fresh()
	return TransactionRules.Snapshot(ProfileTemplate)
end

it("resets progression while advancing the profile revision", function()
	local data = fresh()
	data.Revision = 42
	data.Currencies.Credits = 900
	data.Materials.ScrapMetal = 100
	data.Robots.OwnedByUid.R000001 = {
		RobotId = "TinScout",
		AcquiredAt = 1,
	}
	data.Robots.NextUid = 2
	data.Progression.Zone = 2
	data.Stats.LifetimeRobotsBuilt = 8
	data.Tutorial.Milestones.FirstRobotBuilt = true

	FreshProfileReset.Apply(data)

	expect(data.Revision).toBe(43)
	expect(FreshProfileReset.LooksFresh(data)).toBe(true)
	expect(FreshProfileReset.HasPaidValueHistory(data)).toBe(false)
end)

it("detects paid-value history so creator reset cannot erase receipt protection", function()
	local receiptData = fresh()
	table.insert(receiptData.Receipts.RecentPurchaseIds, "purchase-1")
	expect(FreshProfileReset.HasPaidValueHistory(receiptData)).toBe(true)

	local starterPackData = fresh()
	starterPackData.Entitlements.StarterPackClaimed = true
	expect(FreshProfileReset.HasPaidValueHistory(starterPackData)).toBe(true)

	local clubData = fresh()
	clubData.Entitlements.FactoryClubLastGrantedCycle = "2026-09"
	expect(FreshProfileReset.HasPaidValueHistory(clubData)).toBe(true)

	local cachedOwnershipOnly = fresh()
	cachedOwnershipOnly.Entitlements.FactoryClubActiveCached = true
	expect(FreshProfileReset.HasPaidValueHistory(cachedOwnershipOnly)).toBe(false)
end)
