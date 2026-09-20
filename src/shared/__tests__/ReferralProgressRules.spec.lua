--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local ReferralProgressRules = require(script.Parent.Parent.Domain.ReferralProgressRules)

describe("ReferralProgressRules", function()
	local qualificationSeconds = 600

	it("captures the first inviter and never replaces it", function()
		local record, captured, code =
			ReferralProgressRules.Capture(nil, 101, 1_000, qualificationSeconds)
		expect(captured).toBe(true)
		expect(code).toBe("INVITER_CAPTURED")
		expect(record.InviterUserId).toBe(101)
		expect(record.Eligibility).toBe("Pending")

		local second, recaptured, secondCode =
			ReferralProgressRules.Capture(record, 202, 1_010, qualificationSeconds)
		expect(recaptured).toBe(false)
		expect(secondCode).toBe("INVITER_ALREADY_CAPTURED")
		expect(second.InviterUserId).toBe(101)
	end)

	it("accumulates active time across server transitions and reconnects", function()
		local record = ReferralProgressRules.Capture(nil, 101, 1_000, qualificationSeconds)
		record = ReferralProgressRules.SetEligibility(record, true, 1_001, qualificationSeconds)

		-- Hub session.
		record = ReferralProgressRules.AddActiveSeconds(record, 125, 1_125, qualificationSeconds)
		expect(record.ActivePlaySeconds).toBe(125)

		-- Factory session after teleport.
		record = ReferralProgressRules.AddActiveSeconds(record, 275, 1_400, qualificationSeconds)
		expect(record.ActivePlaySeconds).toBe(400)

		-- Later reconnect.
		local finalRecord, crossed =
			ReferralProgressRules.AddActiveSeconds(record, 200, 2_000, qualificationSeconds)
		expect(crossed).toBe(true)
		expect(finalRecord.ActivePlaySeconds).toBe(600)
		expect(ReferralProgressRules.CanFinalize(finalRecord, qualificationSeconds)).toBe(true)
	end)

	it("counts pending time but does not finalize until eligibility is confirmed", function()
		local record = ReferralProgressRules.Capture(nil, 101, 1_000, qualificationSeconds)
		record = ReferralProgressRules.AddActiveSeconds(record, 600, 1_600, qualificationSeconds)
		expect(record.ActivePlaySeconds).toBe(600)
		expect(ReferralProgressRules.CanFinalize(record, qualificationSeconds)).toBe(false)

		record = ReferralProgressRules.SetEligibility(record, true, 1_601, qualificationSeconds)
		expect(ReferralProgressRules.CanFinalize(record, qualificationSeconds)).toBe(true)
	end)

	it("stops tracking rejected referrals", function()
		local record = ReferralProgressRules.Capture(nil, 101, 1_000, qualificationSeconds)
		record = ReferralProgressRules.SetEligibility(record, false, 1_001, qualificationSeconds)
		expect(ReferralProgressRules.ShouldTrack(record, qualificationSeconds)).toBe(false)

		local after =
			ReferralProgressRules.AddActiveSeconds(record, 300, 1_301, qualificationSeconds)
		expect(after.ActivePlaySeconds).toBe(0)
		expect(ReferralProgressRules.CanFinalize(after, qualificationSeconds)).toBe(false)
	end)

	it("marks a qualified referral terminal and idempotent", function()
		local record = ReferralProgressRules.Capture(nil, 101, 1_000, qualificationSeconds)
		record = ReferralProgressRules.SetEligibility(record, true, 1_001, qualificationSeconds)
		record = ReferralProgressRules.AddActiveSeconds(record, 600, 1_601, qualificationSeconds)
		record = ReferralProgressRules.MarkQualified(record, 1_602, qualificationSeconds)

		expect(record.Qualified).toBe(true)
		expect(ReferralProgressRules.ShouldTrack(record, qualificationSeconds)).toBe(false)
		expect(ReferralProgressRules.CanFinalize(record, qualificationSeconds)).toBe(false)

		local after =
			ReferralProgressRules.AddActiveSeconds(record, 600, 2_202, qualificationSeconds)
		expect(after.ActivePlaySeconds).toBe(600)
		expect(after.Qualified).toBe(true)
	end)

	it("rejects invalid inviter ids", function()
		local record, captured, code =
			ReferralProgressRules.Capture(nil, 0, 1_000, qualificationSeconds)
		expect(captured).toBe(false)
		expect(code).toBe("INVITER_INVALID")
		expect(record.InviterUserId).toBe(0)
	end)
end)
