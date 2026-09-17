--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ProfileMigrations = require(script.Parent.Parent.Data.ProfileMigrations)

describe("ProfileMigrations", function()
	it("adds and sanitizes the server overclock lease id in schema 6", function()
		local data = {
			Version = 5,
			Entitlements = {
				ServerOverclockUntil = 1234,
				ServerOverclockLeaseId = 123,
			},
		}

		ProfileMigrations.Apply(data)

		expect(data.Version).toBe(GameConfig.ProfileSchemaVersion)
		expect(data.Entitlements.ServerOverclockLeaseId).toBe("")
	end)

	it("preserves a bounded server overclock lease id", function()
		local data = {
			Version = 5,
			Entitlements = {
				ServerOverclockUntil = 1234,
				ServerOverclockLeaseId = "job-abc",
			},
		}

		ProfileMigrations.Apply(data)

		expect(data.Entitlements.ServerOverclockLeaseId).toBe("job-abc")
	end)
end)
