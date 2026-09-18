--!strict

local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local MachineEffectsController = {}
local initialized = false

local activeSpinners: { [BasePart]: number } = {}
local boundMachines: { [BasePart]: boolean } = {}

local function updateMachine(anchor: BasePart, visualName: string)
	local plot = anchor.Parent
	if plot == nil then
		return
	end

	local visual = plot:FindFirstChild(visualName)
	if visual == nil then
		return
	end

	local busy = anchor:GetAttribute("Busy") == true
	for _, descendant in visual:GetDescendants() do
		if descendant:IsA("BasePart") and descendant:GetAttribute("MachineEffect") == "Spin" then
			if busy then
				local speed = descendant:GetAttribute("EffectSpeedDegrees")
				activeSpinners[descendant] = if typeof(speed) == "number" then speed else 90
			else
				activeSpinners[descendant] = nil
			end
		end
	end
end

local function bindMachine(plot: Model, anchorName: string, visualName: string)
	local anchor = plot:FindFirstChild(anchorName)
	if anchor == nil or not anchor:IsA("BasePart") or boundMachines[anchor] then
		return
	end
	boundMachines[anchor] = true

	local function refresh()
		updateMachine(anchor, visualName)
	end

	anchor:GetAttributeChangedSignal("Busy"):Connect(refresh)
	refresh()
end

local function bindPlot(plot: Model)
	bindMachine(plot, "Processor", "ProcessorVisual")
	bindMachine(plot, "Assembler", "AssemblerVisual")

	plot.ChildAdded:Connect(function(child)
		if child.Name == "ProcessorVisual" then
			local anchor = plot:FindFirstChild("Processor")
			if anchor ~= nil and anchor:IsA("BasePart") then
				bindMachine(plot, "Processor", "ProcessorVisual")
				updateMachine(anchor, "ProcessorVisual")
			end
		elseif child.Name == "AssemblerVisual" then
			local anchor = plot:FindFirstChild("Assembler")
			if anchor ~= nil and anchor:IsA("BasePart") then
				bindMachine(plot, "Assembler", "AssemblerVisual")
				updateMachine(anchor, "AssemblerVisual")
			end
		end
	end)
end

function MachineEffectsController.Init()
	if initialized then
		return
	end
	initialized = true

	task.spawn(function()
		local root = Workspace:WaitForChild("ScrapToBotGraybox")
		local plots = root:WaitForChild("FactoryPlots")

		for _, child in plots:GetChildren() do
			if child:IsA("Model") then
				bindPlot(child)
			end
		end

		plots.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				bindPlot(child)
			end
		end)
	end)

	RunService.Heartbeat:Connect(function(deltaTime)
		for spinner, degreesPerSecond in activeSpinners do
			if spinner.Parent == nil then
				activeSpinners[spinner] = nil
				continue
			end
			local radians = math.rad(degreesPerSecond) * deltaTime
			spinner.CFrame *= CFrame.Angles(radians, 0, 0)
		end
	end)
end

return MachineEffectsController
