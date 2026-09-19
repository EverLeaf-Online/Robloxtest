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
	it("builds a compact scrap-processing plant with a real process train", function()
		local plot = Instance.new("Model")
		local environment = FactoryEnvironmentBuilder.Build(plot, 1, Vector3.zero)

		expect(environment:FindFirstChild("FactorySite") ~= nil).toBe(true)
		local receiving = environment:FindFirstChild("ReceivingGate")
		expect(receiving ~= nil and receiving:IsA("Model")).toBe(true)
		expect((receiving :: Model):FindFirstChild("TruckWeighbridge") ~= nil).toBe(true)
		expect(environment:FindFirstChild("ScrapReceivingYard") ~= nil).toBe(true)
		expect(environment:FindFirstChild("ScrapGantryCrane") ~= nil).toBe(true)
		expect(environment:FindFirstChild("ProductionHall") ~= nil).toBe(true)
		expect(environment:FindFirstChild("ScrapProcessTrain") ~= nil).toBe(true)
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

		expect(partCount >= 360).toBe(true)
		expect(partCount <= 760).toBe(true)

		plot:Destroy()
	end)

	it("provides substantial collidable plant geometry for robot navigation", function()
		local plot = Instance.new("Model")
		local environment = FactoryEnvironmentBuilder.Build(plot, 1, Vector3.zero)

		local collidable = 0
		for _, descendant in environment:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.CanCollide then
				collidable += 1
			end
		end

		expect(collidable >= 110).toBe(true)
		plot:Destroy()
	end)

	it("physically separates receiving, processing, shipping, and utilities", function()
		local plot = Instance.new("Model")
		local environment = FactoryEnvironmentBuilder.Build(plot, 1, Vector3.zero)
		local hall = environment:FindFirstChild("ProductionHall")
		local process = environment:FindFirstChild("ScrapProcessTrain")
		local dock = environment:FindFirstChild("MaterialWarehouse")
		local utilities = environment:FindFirstChild("UtilityYard")

		expect(hall ~= nil and hall:IsA("Model")).toBe(true)
		expect(process ~= nil and process:IsA("Model")).toBe(true)
		expect(dock ~= nil and dock:IsA("Model")).toBe(true)
		expect(utilities ~= nil and utilities:IsA("Model")).toBe(true)
		expect((hall :: Model):FindFirstChild("NorthWall") ~= nil).toBe(true)
		expect((process :: Model):FindFirstChild("PrimaryShredderFeed") ~= nil).toBe(true)
		expect((process :: Model):FindFirstChild("OverbandMagnetSeparator") ~= nil).toBe(true)
		expect((process :: Model):FindFirstChild("MagneticDrumSeparator") ~= nil).toBe(true)
		expect((process :: Model):FindFirstChild("EddyCurrentSeparator") ~= nil).toBe(true)
		expect((process :: Model):FindFirstChild("SortedMaterialBunkers") ~= nil).toBe(true)
		expect((dock :: Model):FindFirstChild("WarehouseWall") ~= nil).toBe(true)

		plot:Destroy()
	end)

	it("anchors every static factory part so Play mode cannot collapse the plant", function()
		local plot = Instance.new("Model")
		local environment = FactoryEnvironmentBuilder.Build(plot, 1, Vector3.zero)
		local unanchored = {}

		for _, descendant in environment:GetDescendants() do
			if descendant:IsA("BasePart") and not descendant.Anchored then
				table.insert(unanchored, descendant:GetFullName())
			end
		end

		expect(unanchored).toEqual({})
		plot:Destroy()
	end)
end)
