--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local Robots = require(script.Parent.Parent.Config.Robots)
local Validation = require(script.Parent.Parent.Util.Validation)

describe("Validation", function()
	it("accepts finite numbers and rejects NaN/infinity", function()
		expect(Validation.isFiniteNumber(0)).toBe(true)
		expect(Validation.isFiniteNumber(42.5)).toBe(true)
		expect(Validation.isFiniteNumber(0 / 0)).toBe(false)
		expect(Validation.isFiniteNumber(math.huge)).toBe(false)
		expect(Validation.isFiniteNumber(-math.huge)).toBe(false)
		expect(Validation.isFiniteNumber("42")).toBe(false)
	end)

	it("requires bounded integers", function()
		expect(Validation.isSafeInteger(5, 0, 10)).toBe(true)
		expect(Validation.isSafeInteger(5.5, 0, 10)).toBe(false)
		expect(Validation.isSafeInteger(-1, 0, 10)).toBe(false)
		expect(Validation.isSafeInteger(11, 0, 10)).toBe(false)
	end)

	it("rejects empty and oversized IDs", function()
		expect(Validation.isBoundedString("Robot_1", 16)).toBe(true)
		expect(Validation.isBoundedString("", 16)).toBe(false)
		expect(Validation.isBoundedString(string.rep("x", 17), 16)).toBe(false)
	end)

	it("only accepts known definition IDs", function()
		expect(Validation.isKnownId("TinScout", Robots.Definitions)).toBe(true)
		expect(Validation.isKnownId("DefinitelyNotARobot", Robots.Definitions)).toBe(false)
	end)
end)
