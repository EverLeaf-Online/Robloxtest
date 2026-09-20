--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TransactionRules = require(ReplicatedStorage.Shared.Domain.TransactionRules)

local ProfileTemplate = require(script.Parent.ProfileTemplate)
local ProfileTypes = require(script.Parent.ProfileTypes)

type ProfileData = ProfileTypes.ProfileData

local FreshProfileReset = {}

function FreshProfileReset.HasPaidValueHistory(data: ProfileData): boolean
	if #data.Receipts.RecentPurchaseIds > 0 then
		return true
	end

	local entitlements = data.Entitlements
	if entitlements.StarterPackClaimed then
		return true
	end
	if entitlements.PersonalOverclockUntil > 0 or entitlements.ServerOverclockUntil > 0 then
		return true
	end
	if entitlements.FactoryClubLastGrantedCycle ~= "" then
		return true
	end
	if next(entitlements.FactoryClubCosmetics) ~= nil then
		return true
	end

	return false
end

function FreshProfileReset.Apply(data: ProfileData)
	local previousRevision = data.Revision
	TransactionRules.Restore(data, ProfileTemplate)
	data.Revision = math.max(0, math.floor(previousRevision)) + 1
end

function FreshProfileReset.LooksFresh(data: ProfileData): boolean
	return data.Currencies.Credits == 0
		and data.Materials.ScrapMetal == 0
		and data.Materials.Wiring == 0
		and data.Materials.PowerCoreFragments == 0
		and data.Consumables.InstantProcessTokens == 0
		and next(data.Robots.OwnedByUid) == nil
		and next(data.Assignments.WorkPads) == nil
		and data.Machines.ProcessorLevel == 1
		and data.Machines.AssemblerLevel == 1
		and data.Machines.StorageLevel == 1
		and data.Machines.WorkSlotsLevel == 1
		and data.Progression.Zone == 1
		and data.Progression.FactoryTier == 1
		and data.Progression.PrestigeCount == 0
		and data.Stats.LifetimeCredits == 0
		and data.Stats.LifetimeRobotsBuilt == 0
		and next(data.Tutorial.Milestones) == nil
end

return table.freeze(FreshProfileReset)
