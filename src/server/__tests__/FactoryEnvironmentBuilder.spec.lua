--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local function environmentIt(name: string, testFn: () -> ())
	-- The first environment test on a cold Open Cloud worker can spend several
	-- seconds loading approved Roblox assets. The production builder preloads
	-- unique assets concurrently, but the integration suite still needs a
	-- network-tolerant ceiling.
	it(name, testFn, 15_000)
end

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
	environmentIt("builds a compact scrap-processing plant with a real process train", function()
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

	environmentIt(
		"keeps the detailed private-instance environment within a bounded part budget",
		function()
			local plot = Instance.new("Model")
			local environment = FactoryEnvironmentBuilder.Build(plot, 1, Vector3.zero)
			local partCount = countBaseParts(environment)

			expect(partCount <= 620).toBe(true)

			plot:Destroy()
		end
	)

	environmentIt("provides substantial collidable plant geometry for robot navigation", function()
		local plot = Instance.new("Model")
		local environment = FactoryEnvironmentBuilder.Build(plot, 1, Vector3.zero)

		local collidable = 0
		for _, descendant in environment:GetDescendants() do
			if descendant:IsA("BasePart") and descendant.CanCollide then
				collidable += 1
			end
		end

		expect(collidable >= 70).toBe(true)
		expect(collidable <= 220).toBe(true)
		plot:Destroy()
	end)

	environmentIt("physically separates receiving, processing, shipping, and utilities", function()
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

	environmentIt("loads approved production meshes for the public factory presentation", function()
		local plot = Instance.new("Model")
		local environment = FactoryEnvironmentBuilder.Build(plot, 1, Vector3.zero)

		local shredder = environment:FindFirstChild("Industrial Scrap Shredder", true)
		local sorter = environment:FindFirstChild("MagneticSortingConveyor", true)
		local baler = environment:FindFirstChild("HydraulicScrapBaler", true)
		local hopper = environment:FindFirstChild("ReceivingHopper", true)
		local infeed = environment:FindFirstChild("InfeedConveyorVisual", true)
		local outfeed = environment:FindFirstChild("FinishedRobotOutfeedVisual", true)
		local scrapPile = environment:FindFirstChild("ScrapPileVisual", true)

		for _, imported in { shredder, sorter, baler, hopper, infeed, outfeed, scrapPile } do
			expect(imported ~= nil and imported:GetAttribute("FactoryImportedAsset") == true).toBe(
				true
			)
		end

		for _, optimized in { sorter, baler, hopper, infeed, outfeed, scrapPile } do
			local baseParts = 0
			for _, descendant in (optimized :: Instance):GetDescendants() do
				if descendant:IsA("BasePart") then
					baseParts += 1
				end
			end
			expect(baseParts <= 2).toBe(true)
		end

		plot:Destroy()
	end)

	it(
		"loads optimized support assets without turning visual meshes into physics authority",
		function()
			local plot = Instance.new("Model")
			local environment = FactoryEnvironmentBuilder.Build(plot, 1, Vector3.zero)

			local light = environment:FindFirstChild("HallLight_-52_-25", true)
			local storageRack = environment:FindFirstChild("WarehouseRack1", true)
			local pipeRack = environment:FindFirstChild("UtilityPipeRack1", true)
			local barrier = environment:FindFirstChild("ServiceBayBarrier1", true)
			local cabinet = environment:FindFirstChild("RecoveryCabinetVisual", true)
			local structuralColumn = environment:FindFirstChild("HallColumnVisual", true)

			for _, imported in
				{
					light,
					storageRack,
					pipeRack,
					barrier,
					cabinet,
					structuralColumn,
				}
			do
				expect(imported ~= nil and imported:GetAttribute("FactoryImportedAsset") == true).toBe(
					true
				)
				local baseParts = 0
				for _, descendant in (imported :: Instance):GetDescendants() do
					if descendant:IsA("BasePart") then
						baseParts += 1
						expect(descendant.Anchored).toBe(true)
						expect(descendant.CanCollide).toBe(false)
					end
				end
				expect(baseParts <= 2).toBe(true)
			end

			local cabinetCollision = environment:FindFirstChild("CabinetCollision", true)
			expect(cabinetCollision ~= nil and (cabinetCollision :: BasePart).CanCollide).toBe(true)
			local columnCollision = environment:FindFirstChild("HallColumnCollision", true)
			expect(columnCollision ~= nil and (columnCollision :: BasePart).CanCollide).toBe(true)

			plot:Destroy()
		end
	)

	environmentIt(
		"anchors every static factory part so Play mode cannot collapse the plant",
		function()
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
		end
	)
end)
