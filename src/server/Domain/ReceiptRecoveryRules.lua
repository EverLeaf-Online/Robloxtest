--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RobloxIds = require(ReplicatedStorage.Shared.Config.RobloxIds)
local ProfileTypes = require(script.Parent.Parent.Data.ProfileTypes)

type ProfileData = ProfileTypes.ProfileData

export type RecoveryEvidence = {
	UserId: number,
	PurchaseId: string,
	ProductId: number,
	EvidenceReference: string,
	ExpectedRevision: number,
	ExpectedCredits: number?,
	ExpectedScrapMetal: number?,
	ExpectedWiring: number?,
	ExpectedPowerCoreFragments: number?,
	ExpectedInstantProcessTokens: number?,
	ExpectedStarterPackClaimed: boolean?,
	ExpectedPersonalOverclockUntil: number?,
	ExpectedServerOverclockUntil: number?,
}

local ReceiptRecoveryRules = {}

local PRODUCT = RobloxIds.DeveloperProducts

local function isWholeNonNegative(value: any): boolean
	return typeof(value) == "number"
		and value == value
		and value ~= math.huge
		and value ~= -math.huge
		and value >= 0
		and value % 1 == 0
end

local function requiredNumberMatches(actual: number, expected: any): boolean
	return isWholeNonNegative(expected) and actual == expected
end

function ReceiptRecoveryRules.ValidateEvidence(evidence: RecoveryEvidence): (boolean, string)
	if not isWholeNonNegative(evidence.UserId) or evidence.UserId <= 0 then
		return false, "INVALID_USER_ID"
	end
	if evidence.PurchaseId == "" or #evidence.PurchaseId > 128 then
		return false, "INVALID_PURCHASE_ID"
	end
	if evidence.EvidenceReference == "" or #evidence.EvidenceReference > 128 then
		return false, "INVALID_EVIDENCE_REFERENCE"
	end
	if not isWholeNonNegative(evidence.ExpectedRevision) then
		return false, "INVALID_EXPECTED_REVISION"
	end

	local productId = evidence.ProductId
	if productId == PRODUCT.MaterialSupplyCrate then
		if
			not isWholeNonNegative(evidence.ExpectedScrapMetal)
			or not isWholeNonNegative(evidence.ExpectedWiring)
			or not isWholeNonNegative(evidence.ExpectedPowerCoreFragments)
		then
			return false, "INCOMPLETE_EXPECTED_STATE"
		end
	elseif productId == PRODUCT.FactoryOverclock15m then
		if not isWholeNonNegative(evidence.ExpectedPersonalOverclockUntil) then
			return false, "INCOMPLETE_EXPECTED_STATE"
		end
	elseif productId == PRODUCT.InstantProcessTokens then
		if not isWholeNonNegative(evidence.ExpectedInstantProcessTokens) then
			return false, "INCOMPLETE_EXPECTED_STATE"
		end
	elseif productId == PRODUCT.StarterPack then
		if
			not isWholeNonNegative(evidence.ExpectedCredits)
			or not isWholeNonNegative(evidence.ExpectedScrapMetal)
			or not isWholeNonNegative(evidence.ExpectedWiring)
			or not isWholeNonNegative(evidence.ExpectedPowerCoreFragments)
			or not isWholeNonNegative(evidence.ExpectedInstantProcessTokens)
			or typeof(evidence.ExpectedStarterPackClaimed) ~= "boolean"
		then
			return false, "INCOMPLETE_EXPECTED_STATE"
		end
	elseif productId == PRODUCT.ServerOverclock then
		if not isWholeNonNegative(evidence.ExpectedServerOverclockUntil) then
			return false, "INCOMPLETE_EXPECTED_STATE"
		end
	else
		return false, "UNSUPPORTED_PRODUCT"
	end

	return true, "EVIDENCE_VALID"
end

function ReceiptRecoveryRules.MatchesProfile(
	data: ProfileData,
	evidence: RecoveryEvidence
): (boolean, string)
	local valid, code = ReceiptRecoveryRules.ValidateEvidence(evidence)
	if not valid then
		return false, code
	end
	if data.Revision ~= evidence.ExpectedRevision then
		return false, "REVISION_MISMATCH"
	end

	local productId = evidence.ProductId
	if productId == PRODUCT.MaterialSupplyCrate then
		if
			not requiredNumberMatches(data.Materials.ScrapMetal, evidence.ExpectedScrapMetal)
			or not requiredNumberMatches(data.Materials.Wiring, evidence.ExpectedWiring)
			or not requiredNumberMatches(
				data.Materials.PowerCoreFragments,
				evidence.ExpectedPowerCoreFragments
			)
		then
			return false, "EXPECTED_STATE_MISMATCH"
		end
	elseif productId == PRODUCT.FactoryOverclock15m then
		if
			not requiredNumberMatches(
				data.Entitlements.PersonalOverclockUntil,
				evidence.ExpectedPersonalOverclockUntil
			)
		then
			return false, "EXPECTED_STATE_MISMATCH"
		end
	elseif productId == PRODUCT.InstantProcessTokens then
		if
			not requiredNumberMatches(
				data.Consumables.InstantProcessTokens,
				evidence.ExpectedInstantProcessTokens
			)
		then
			return false, "EXPECTED_STATE_MISMATCH"
		end
	elseif productId == PRODUCT.StarterPack then
		if
			not requiredNumberMatches(data.Currencies.Credits, evidence.ExpectedCredits)
			or not requiredNumberMatches(data.Materials.ScrapMetal, evidence.ExpectedScrapMetal)
			or not requiredNumberMatches(data.Materials.Wiring, evidence.ExpectedWiring)
			or not requiredNumberMatches(
				data.Materials.PowerCoreFragments,
				evidence.ExpectedPowerCoreFragments
			)
			or not requiredNumberMatches(
				data.Consumables.InstantProcessTokens,
				evidence.ExpectedInstantProcessTokens
			)
			or data.Entitlements.StarterPackClaimed ~= evidence.ExpectedStarterPackClaimed
		then
			return false, "EXPECTED_STATE_MISMATCH"
		end
	elseif productId == PRODUCT.ServerOverclock then
		if
			not requiredNumberMatches(
				data.Entitlements.ServerOverclockUntil,
				evidence.ExpectedServerOverclockUntil
			)
		then
			return false, "EXPECTED_STATE_MISMATCH"
		end
	end

	return true, "EVIDENCE_MATCH"
end

return table.freeze(ReceiptRecoveryRules)
