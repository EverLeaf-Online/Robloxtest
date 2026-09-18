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
	it("builds the full scrap-to-factory campus without placeholder-only departments", function()
		local plot = Instance.new("Model")
		plot.Name = "TestPlot"

		local environment = FactoryEnvironmentBuilder.Build(plot, 1, Vector3.zero)

		expect(environment:FindFirstChild("ReceivingGate") ~= nil).toBe(true)
		expect(environment:FindFirstChild("ScrapReceivingYard") ~= nil).toBe(true)
		expect(environment:FindFirstChild("ScrapGantryCrane") ~= nil).toBe(true)
		expect(environment:FindFirstChild("ProductionHall") ~= nil).toBe(true)
		expect(environment:FindFirstChild("WorkerChargingBay") ~= nil).toBe(true)
		expect(environment:FindFirstChild("MaterialWarehouse") ~= nil).toBe(true)
		expect(environment:FindFirstChild("UtilityYard") ~= nil).toBe(true)
		expect(environment:FindFirstChild("CircuitAnnex") ~= nil).toBe(true)

		plot:Destroy()
	end)

	it("keeps the static environment within the private-instance part budget", function()
		local plot = Instance.new("Model")
		local environment = FactoryEnvironmentBuilder.Build(plot, 1, Vector3.zero)
		local partCount = countBaseParts(environment)

		expect(partCount >= 180).toBe(true)
		expect(partCount <= 320).toBe(true)

		plot:Destroy()
	end)

	it("provides collidable industrial obstacles for robot navigation", function()
		local plot = Instance.new("Model")
		local environment = FactoryEnvironmentBuilder.Build(plot, 1, Vector3.zero)

		local collidable = 0
		for _, descendant in environment:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.CanCollide then
				collidable += 1
			end
		end

		expect(collidable >= 40).toBe(true)
		plot:Destroy()
	end)
end)
