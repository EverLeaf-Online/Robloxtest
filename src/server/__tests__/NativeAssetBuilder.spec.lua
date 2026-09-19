--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local describe = JestGlobals.describe
local expect = JestGlobals.expect
local it = JestGlobals.it

local serverRoot = script.Parent.Parent
local NativeAssetBuilder = require(serverRoot.Presentation.NativeAssetBuilder)

describe("NativeAssetBuilder", function()
	it("uses the approved bot assembler asset without losing machine feedback", function()
		local plot = Instance.new("Model")
		plot.Name = "Plot"

		local anchor = Instance.new("Part")
		anchor.Name = "Assembler"
		anchor.Anchored = true
		anchor.Size = Vector3.new(11, 8, 9)
		anchor.CFrame = CFrame.new(0, 4.5, 0)
		anchor.Parent = plot

		local visual = NativeAssetBuilder.BuildAssembler(anchor, 1)
		local imported = visual:FindFirstChild("BotAssemblerStation", true)
		local buildPlate = visual:FindFirstChild("BuildPlate", true)
		local busyBeacon = visual:FindFirstChild("BusyBeacon", true)

		expect(imported ~= nil and imported:GetAttribute("FactoryImportedAsset") == true).toBe(true)
		expect(buildPlate ~= nil and buildPlate:GetAttribute("MachineEffect") == "Spin").toBe(true)
		expect(busyBeacon ~= nil and busyBeacon:GetAttribute("BusyOnly") == true).toBe(true)
		expect(anchor.Transparency).toBe(1)

		for _, descendant in visual:GetDescendants() do
			if descendant:IsA("BasePart") then
				expect(descendant.Anchored).toBe(true)
				expect(descendant.CanCollide).toBe(false)
			end
		end

		plot:Destroy()
	end)
end)
