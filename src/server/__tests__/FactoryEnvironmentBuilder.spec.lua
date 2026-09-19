--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local serverRoot = script.Parent.Parent
local FactoryEnvironmentBuilder = require(serverRoot.Presentation.FactoryEnvironmentBuilder)

local function countBaseParts(root: Instance): number
	local count = 0
	for _, descendant in root:GetDescendants() do
		if descendant:IsA("BasePart") then
			count += 1
		end
	end
	return count
end

describe("FactoryEnvironmentBuilder", function()
	it("builds one connected industrial plant instead of isolated placeholder zones", function()
		local plot = Instance.new("Model")
		local environment = FactoryEnvironmentBuilder.Build(plot, 1, Vector3.zero)

		expect(environment:FindFirstChild("FactorySite") ~= nil).toBe(true)
		expect(environment:FindFirstChild("ReceivingGate") ~= nil).toBe(true)
		expect(environment:FindFirstChild("ScrapReceivingYard") ~= nil).toBe(true)
		expect(environment:FindFirstChild("ScrapGantryCrane") ~= nil).toBe(true)
		expect(environment:FindFirstChild("ProductionHall") ~= nil).toBe(true)
		expect(environment:FindFirstChild("ProductionLine") ~= nil).toBe(true)
		expect(environment:FindFirstChild("ServiceMezzanine") ~= nil).toBe(true)
		expect(environment:FindFirstChild("WorkerChargingBay") ~= nil).toBe(true)
		expect(environment:FindFirstChild("MaterialWarehouse") ~= nil).toBe(true)
		expect(environment:FindFirstChild("UtilityYard") ~= nil).toBe(true)
		expect(environment:FindFirstChild("CircuitBridgeApproach") ~= nil).toBe(true)
		expect(environment:FindFirstChild("CircuitAnnex") ~= nil).toBe(true)

		plot:Destroy()
	end)

	it("keeps the detailed private-instance environment within a bounded part budget", function()
		local plot = Instance.new("Model")
		local environment = FactoryEnvironmentBuilder.Build(plot, 1, Vector3.zero)
		local partCount = countBaseParts(environment)

		expect(partCount >= 300).toBe(true)
		expect(partCount <= 560).toBe(true)

		plot:Destroy()
	end)

	it("provides substantial collidable factory geometry for robot navigation", function()
		local plot = Instance.new("Model")
		local environment = FactoryEnvironmentBuilder.Build(plot, 1, Vector3.zero)

		local collidable = 0
		for _, descendant in environment:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.CanCollide then
				collidable += 1
			end
		end

		expect(collidable >= 90).toBe(true)
		plot:Destroy()
	end)

	it("builds hall shell, line, and loading dock as physically connected plant systems", function()
		local plot = Instance.new("Model")
		local environment = FactoryEnvironmentBuilder.Build(plot, 1, Vector3.zero)
		local hall = environment:FindFirstChild("ProductionHall")
		local line = environment:FindFirstChild("ProductionLine")
		local dock = environment:FindFirstChild("MaterialWarehouse")

		expect(hall ~= nil and hall:IsA("Model")).toBe(true)
		expect(line ~= nil and line:IsA("Model")).toBe(true)
		expect(dock ~= nil and dock:IsA("Model")).toBe(true)
		expect((hall :: Model):FindFirstChild("NorthWall") ~= nil).toBe(true)
		expect((hall :: Model):FindFirstChild("SouthWall") ~= nil).toBe(true)
		expect((line :: Model):FindFirstChild("ScrapFeed") ~= nil).toBe(true)
		expect((line :: Model):FindFirstChild("AssemblerOutfeed") ~= nil).toBe(true)
		expect((dock :: Model):FindFirstChild("WarehouseWall") ~= nil).toBe(true)

		plot:Destroy()
	end)
end)
