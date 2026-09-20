--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local RobloxIds = require(ReplicatedStorage.Shared.Config.RobloxIds)

local serverRoot = script.Parent.Parent
local ProfileTemplate = require(serverRoot.Data.ProfileTemplate)
local ReceiptRecoveryRules = require(serverRoot.Domain.ReceiptRecoveryRules)

local PRODUCT = RobloxIds.DeveloperProducts

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

describe("ReceiptRecoveryRules", function()
	it("requires exact product-specific durable state evidence", function()
		local data = deepCopy(ProfileTemplate)
		data.Revision = 12
		data.Consumables.InstantProcessTokens = 7

		local evidence = {
			UserId = 123,
			PurchaseId = "known-orphan-1",
			ProductId = PRODUCT.InstantProcessTokens,
			EvidenceReference = "incident-2026-09-20-a",
			ExpectedRevision = 12,
			ExpectedInstantProcessTokens = 7,
		}

		local matches, code = ReceiptRecoveryRules.MatchesProfile(data, evidence)
		expect(matches).toBe(true)
		expect(code).toBe("EVIDENCE_MATCH")

		evidence.ExpectedInstantProcessTokens = 8
		local mismatch, mismatchCode = ReceiptRecoveryRules.MatchesProfile(data, evidence)
		expect(mismatch).toBe(false)
		expect(mismatchCode).toBe("EXPECTED_STATE_MISMATCH")
	end)

	it("rejects missing expected fields instead of inferring current state", function()
		local data = deepCopy(ProfileTemplate)
		local evidence = {
			UserId = 123,
			PurchaseId = "known-orphan-2",
			ProductId = PRODUCT.MaterialSupplyCrate,
			EvidenceReference = "incident-2026-09-20-b",
			ExpectedRevision = 0,
			ExpectedScrapMetal = 0,
			ExpectedWiring = 0,
		}

		local matches, code = ReceiptRecoveryRules.MatchesProfile(data, evidence :: any)
		expect(matches).toBe(false)
		expect(code).toBe("INCOMPLETE_EXPECTED_STATE")
	end)

	it("rejects stale evidence when the profile revision moved", function()
		local data = deepCopy(ProfileTemplate)
		data.Revision = 20

		local evidence = {
			UserId = 123,
			PurchaseId = "known-orphan-3",
			ProductId = PRODUCT.ServerOverclock,
			EvidenceReference = "incident-2026-09-20-c",
			ExpectedRevision = 19,
			ExpectedServerOverclockUntil = 0,
		}

		local matches, code = ReceiptRecoveryRules.MatchesProfile(data, evidence)
		expect(matches).toBe(false)
		expect(code).toBe("REVISION_MISMATCH")
	end)

	it("requires a traceable evidence reference and supported product", function()
		local invalidReference = {
			UserId = 123,
			PurchaseId = "known-orphan-4",
			ProductId = PRODUCT.InstantProcessTokens,
			EvidenceReference = "",
			ExpectedRevision = 0,
			ExpectedInstantProcessTokens = 0,
		}
		local valid, code = ReceiptRecoveryRules.ValidateEvidence(invalidReference)
		expect(valid).toBe(false)
		expect(code).toBe("INVALID_EVIDENCE_REFERENCE")

		local unknownProduct = {
			UserId = 123,
			PurchaseId = "known-orphan-5",
			ProductId = 999_999_999,
			EvidenceReference = "incident-unknown",
			ExpectedRevision = 0,
		}
		local unknownValid, unknownCode = ReceiptRecoveryRules.ValidateEvidence(unknownProduct :: any)
		expect(unknownValid).toBe(false)
		expect(unknownCode).toBe("UNSUPPORTED_PRODUCT")
	end)
end)
