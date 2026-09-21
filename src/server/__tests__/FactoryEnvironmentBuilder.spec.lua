--!strict
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe, expect, it = JestGlobals.describe, JestGlobals.expect, JestGlobals.it
local serverRoot = script.Parent.Parent
local Builder = require(serverRoot.Presentation.FactoryEnvironmentBuilder)
local Kit = require(serverRoot.Content.ScrapyardWorkshopKit)

describe("FactoryEnvironmentBuilder", function()
	it("keeps the gameplay aisle open beneath the cutaway workshop", function()
		for _, spec in Kit do
			if spec.group == "ProductionHall" and spec.collision then
				-- All structural authority stays behind the process line.
				expect(spec.pos[3] - spec.size[3] / 2 >= 60).toBe(true)
			end
		end
	end)

	it("uses a bounded kit with explicit safe collision", function()
		expect(#Kit <= 300).toBe(true)
		for _, spec in Kit do
			expect(type(spec.collision)).toBe("boolean")
			for _, dimension in spec.size do
				expect(dimension > 0).toBe(true)
			end
		end
	end)

	it("builds the complete workshop and retains the real processing train", function()
		local plot = Instance.new("Model")
		local environment = Builder.Build(plot, 1, Vector3.zero)
		for _, name in {
			"FactorySite", "ProductionHall", "ScrapGantryCrane", "ScrapReceivingYard",
			"BotWorksLandmark", "MaterialWarehouse", "WorkerChargingBay", "WorkshopOffice",
			"UtilityYard", "CircuitBridgeApproach", "CircuitAnnex", "ScrapProcessTrain",
		} do
			expect(environment:FindFirstChild(name) ~= nil).toBe(true)
		end
		local count = 0
		for _, descendant in environment:GetDescendants() do
			if descendant:IsA("BasePart") then
				count += 1
				expect(descendant.Anchored).toBe(true)
				expect(descendant.CanTouch).toBe(false)
				expect(descendant:GetAttribute("PlotId")).toBe(1)
			end
		end
		-- Includes the procedural fallback when approved meshes are unavailable.
		expect(count <= 900).toBe(true)
		expect(Builder.Build(plot, 1, Vector3.zero)).toBe(environment)
		plot:Destroy()
	end, 15000)

	it("places native kit geometry relative to each plot without moving authority", function()
		local plot = Instance.new("Model")
		local offset = Vector3.new(400, 10, 600)
		local environment = Builder.Build(plot, 2, offset)
		local head = environment:FindFirstChild("RobotHead", true) :: BasePart
		expect(head.Position).toBe(offset + Vector3.new(37, 25.5, 61))
		expect(head.CanCollide).toBe(false)
		expect(head.CanQuery).toBe(false)
		plot:Destroy()
	end, 15000)
end)
