--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local FactoryReadyDeliveryRules = require(script.Parent.Parent.Domain.FactoryReadyDeliveryRules)

describe("FactoryReadyDeliveryRules", function()
	it("rejects a stale page after another poller has fully delivered the generation", function()
		local state = FactoryReadyDeliveryRules.Schedule("gen-a", 100, 90)
		assert(state ~= nil, "schedule should succeed")

		local claimed, firstAccepted =
			FactoryReadyDeliveryRules.Claim(state, "gen-a", 100, "server-a", 100, 45)
		expect(firstAccepted).toBe(true)

		local completed, completionAccepted =
			FactoryReadyDeliveryRules.Complete(claimed, "gen-a", "server-a", 101)
		expect(completionAccepted).toBe(true)

		local afterStaleClaim, secondAccepted, code =
			FactoryReadyDeliveryRules.Claim(completed, "gen-a", 100, "server-b", 102, 45)
		expect(secondAccepted).toBe(false)
		expect(code).toBe("STALE")
		expect(afterStaleClaim.Status).toBe("sent")
	end)

	it("does not let an old page claim or overwrite a newer schedule", function()
		local first = FactoryReadyDeliveryRules.Schedule("gen-a", 100, 90)
		local rescheduled = FactoryReadyDeliveryRules.Schedule("gen-b", 200, 95)
		assert(first ~= nil, "first schedule should succeed")
		assert(rescheduled ~= nil, "reschedule should succeed")

		local afterStaleClaim, accepted, code =
			FactoryReadyDeliveryRules.Claim(rescheduled, "gen-a", 100, "server-a", 101, 45)
		expect(accepted).toBe(false)
		expect(code).toBe("STALE")
		expect(afterStaleClaim.Generation).toBe("gen-b")
		expect(afterStaleClaim.DueAt).toBe(200)
		expect(afterStaleClaim.Status).toBe("scheduled")
	end)

	it("rejects a page that was cancelled before lock acquisition", function()
		local scheduled = FactoryReadyDeliveryRules.Schedule("gen-a", 100, 90)
		assert(scheduled ~= nil, "schedule should succeed")
		local cancelled = FactoryReadyDeliveryRules.Cancel(scheduled, 95)

		local afterClaim, accepted, code =
			FactoryReadyDeliveryRules.Claim(cancelled, "gen-a", 100, "server-a", 100, 45)
		expect(accepted).toBe(false)
		expect(code).toBe("STALE")
		expect(afterClaim.Status).toBe("cancelled")
	end)

	it("keeps another poller out while an in-flight send renews its claim", function()
		local scheduled = FactoryReadyDeliveryRules.Schedule("gen-a", 100, 90)
		assert(scheduled ~= nil, "schedule should succeed")
		local claimed, accepted =
			FactoryReadyDeliveryRules.Claim(scheduled, "gen-a", 100, "server-a", 100, 30)
		expect(accepted).toBe(true)

		local renewed, renewedOk =
			FactoryReadyDeliveryRules.Renew(claimed, "gen-a", "server-a", 120, 30)
		expect(renewedOk).toBe(true)
		expect(renewed.ClaimUntil).toBe(150)

		local stillLocked, secondAccepted, code =
			FactoryReadyDeliveryRules.Claim(renewed, "gen-a", 100, "server-b", 131, 30)
		expect(secondAccepted).toBe(false)
		expect(code).toBe("BUSY")
		expect(stillLocked.Owner).toBe("server-a")
	end)

	it("prevents stale completion from erasing a rescheduled generation", function()
		local scheduled = FactoryReadyDeliveryRules.Schedule("gen-a", 100, 90)
		assert(scheduled ~= nil, "schedule should succeed")
		local _, accepted =
			FactoryReadyDeliveryRules.Claim(scheduled, "gen-a", 100, "server-a", 100, 45)
		expect(accepted).toBe(true)

		local rescheduled = FactoryReadyDeliveryRules.Schedule("gen-b", 200, 101)
		assert(rescheduled ~= nil, "reschedule should succeed")
		local afterCompletion, completed =
			FactoryReadyDeliveryRules.Complete(rescheduled, "gen-a", "server-a", 102)
		expect(completed).toBe(false)
		expect(afterCompletion.Generation).toBe("gen-b")
		expect(afterCompletion.Status).toBe("scheduled")
	end)
end)
