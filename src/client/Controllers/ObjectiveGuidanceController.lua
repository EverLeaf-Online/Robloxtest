--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local ObjectiveGuidanceRules = require(ReplicatedStorage.Shared.Domain.ObjectiveGuidanceRules)
local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)

local StateHelpers = require(script.Parent.Parent.UI.StateHelpers)
local Theme = require(script.Parent.Parent.UI.Theme)

local ObjectiveGuidanceController = {}

local initialized = false
local snapshot: any? = nil
local currentTarget: BasePart? = nil
local currentLabel = ""
local targetMarker: BillboardGui? = nil
local targetAncestryConnection: RBXScriptConnection? = nil
local targetPromptConnection: RBXScriptConnection? = nil
local renderConnection: RBXScriptConnection? = nil
local refreshQueued = false

local directionFrame: Frame? = nil
local directionText: TextLabel? = nil

local COLORS = Theme.Colors
local LocalPlayer = Players.LocalPlayer
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local STEP_LABELS: { [ObjectiveGuidanceRules.ObjectiveStep]: string } = {
	CollectScrap = "COLLECT SCRAP",
	ProcessMaterials = "PROCESS MATERIALS",
	BuildFirstBot = "BUILD YOUR FIRST BOT",
	AssignFirstBot = "ASSIGN YOUR BOT",
	EarnFirstCredits = "BOT AT WORK",
	BuyFirstUpgrade = "UPGRADE FACTORY",
	UnlockCircuitYard = "UNLOCK CIRCUIT YARD",
	ExploreCircuitYard = "CIRCUIT SALVAGE",
}

local function getCharacterPosition(): Vector3?
	local character = LocalPlayer.Character
	if character == nil then
		return nil
	end
	local root = character:FindFirstChild("HumanoidRootPart")
	return if root ~= nil and root:IsA("BasePart") then root.Position else nil
end

local function getPlot(currentSnapshot: any): Model?
	if typeof(currentSnapshot) ~= "table" then
		return nil
	end
	local plotState = currentSnapshot.Plot
	if typeof(plotState) ~= "table" or typeof(plotState.Id) ~= "number" then
		return nil
	end

	local world = Workspace:FindFirstChild("ScrapToBotFactoryWorld")
	local plots = if world ~= nil then world:FindFirstChild("FactoryPlots") else nil
	if plots == nil then
		return nil
	end

	for _, child in plots:GetChildren() do
		if child:IsA("Model") and child:GetAttribute("PlotId") == plotState.Id then
			return child
		end
	end
	return nil
end

local function nearestMatchingPart(plot: Model, predicate: (BasePart) -> boolean): BasePart?
	local origin = getCharacterPosition()
	local best: BasePart? = nil
	local bestDistance = math.huge

	for _, descendant in plot:GetDescendants() do
		if descendant:IsA("BasePart") and predicate(descendant) then
			local distance = if origin ~= nil then (descendant.Position - origin).Magnitude else 0
			if best == nil or distance < bestDistance then
				best = descendant
				bestDistance = distance
			end
		end
	end

	return best
end

local function findSalvage(plot: Model, zoneId: number): BasePart?
	local active = nearestMatchingPart(plot, function(part)
		if part:GetAttribute("ZoneId") ~= zoneId then
			return false
		end
		if typeof(part:GetAttribute("SalvageNodeId")) ~= "string" then
			return false
		end
		local prompt = part:FindFirstChildOfClass("ProximityPrompt")
		return prompt == nil or prompt.Enabled
	end)
	if active ~= nil then
		return active
	end

	return nearestMatchingPart(plot, function(part)
		return part:GetAttribute("ZoneId") == zoneId
			and typeof(part:GetAttribute("SalvageNodeId")) == "string"
	end)
end

local function findNamedPart(plot: Model, name: string): BasePart?
	local instance = plot:FindFirstChild(name, true)
	return if instance ~= nil and instance:IsA("BasePart") then instance else nil
end

local function findProcessorControl(plot: Model): BasePart?
	return nearestMatchingPart(plot, function(part)
		return typeof(part:GetAttribute("ProcessorRecipeId")) == "string"
	end)
end

local function findAssignedPad(plot: Model, currentSnapshot: any): BasePart?
	local assignments = currentSnapshot.Assignments
	local workPads = if typeof(assignments) == "table" then assignments.WorkPads else nil
	if typeof(workPads) ~= "table" then
		return nil
	end

	local assignedPadIds: { [string]: boolean } = {}
	for padId, robotUid in workPads do
		if typeof(padId) == "string" and typeof(robotUid) == "string" then
			assignedPadIds[padId] = true
		end
	end

	return nearestMatchingPart(plot, function(part)
		local padId = part:GetAttribute("WorkPadId")
		return typeof(padId) == "string" and assignedPadIds[padId] == true
	end)
end

local function resolveTarget(currentSnapshot: any): (BasePart?, string)
	local plot = getPlot(currentSnapshot)
	if plot == nil then
		return nil, ""
	end

	local step = ObjectiveGuidanceRules.GetStep(currentSnapshot)
	local label = STEP_LABELS[step]

	if step == "CollectScrap" then
		return findSalvage(plot, 1), label
	elseif step == "ProcessMaterials" then
		return findProcessorControl(plot), label
	elseif step == "BuildFirstBot" then
		return findNamedPart(plot, "Assembler"), label
	elseif step == "AssignFirstBot" then
		return findNamedPart(plot, "BotConsole"), label
	elseif step == "EarnFirstCredits" then
		return findAssignedPad(plot, currentSnapshot) or findNamedPart(plot, "BotConsole"), label
	elseif step == "BuyFirstUpgrade" then
		return findNamedPart(plot, "UpgradeConsole"), label
	elseif step == "UnlockCircuitYard" then
		return findNamedPart(plot, "CircuitYardGate"), label
	end

	return findSalvage(plot, 2) or findNamedPart(plot, "CircuitYardArrival"), label
end

local function destroyTargetMarker()
	if targetMarker ~= nil then
		targetMarker:Destroy()
		targetMarker = nil
	end
end

local function createTargetMarker(target: BasePart, labelText: string)
	destroyTargetMarker()

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ObjectiveGuidance"
	billboard.Adornee = target
	billboard.AlwaysOnTop = true
	billboard.LightInfluence = 0
	billboard.MaxDistance = 500
	billboard.Size = UDim2.fromOffset(184, 54)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 4.2, 0)
	billboard.Parent = target

	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = COLORS.Panel
	frame.BackgroundTransparency = 0.08
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = billboard

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Accent
	stroke.Thickness = 1.5
	stroke.Transparency = 0.1
	stroke.Parent = frame

	local eyebrow = Instance.new("TextLabel")
	eyebrow.BackgroundTransparency = 1
	eyebrow.Font = Enum.Font.GothamBold
	eyebrow.Position = UDim2.fromOffset(8, 4)
	eyebrow.Size = UDim2.new(1, -16, 0, 14)
	eyebrow.Text = "NEXT"
	eyebrow.TextColor3 = COLORS.Accent
	eyebrow.TextSize = 10
	eyebrow.TextXAlignment = Enum.TextXAlignment.Center
	eyebrow.Parent = frame

	local label = Instance.new("TextLabel")
	label.BackgroundTransparency = 1
	label.Font = Enum.Font.GothamBold
	label.Position = UDim2.fromOffset(8, 18)
	label.Size = UDim2.new(1, -16, 0, 24)
	label.Text = labelText
	label.TextColor3 = COLORS.Text
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = frame

	local arrow = Instance.new("TextLabel")
	arrow.AnchorPoint = Vector2.new(0.5, 0)
	arrow.BackgroundTransparency = 1
	arrow.Font = Enum.Font.GothamBold
	arrow.Position = UDim2.new(0.5, 0, 1, -4)
	arrow.Size = UDim2.fromOffset(22, 18)
	arrow.Text = "▼"
	arrow.TextColor3 = COLORS.Accent
	arrow.TextSize = 18
	arrow.Parent = frame

	targetMarker = billboard
end

local function createDirectionGui()
	local playerGui = LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui
	local existing = playerGui:FindFirstChild("ObjectiveDirectionHUD")
	if existing ~= nil then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ObjectiveDirectionHUD"
	gui.DisplayOrder = 18
	gui.IgnoreGuiInset = true
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local frame = Instance.new("Frame")
	frame.Name = "Direction"
	frame.AnchorPoint = Vector2.new(0.5, 0.5)
	frame.BackgroundColor3 = COLORS.Panel
	frame.BackgroundTransparency = 0.06
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromOffset(188, 42)
	frame.Visible = false
	frame.ZIndex = 10
	frame.Parent = gui

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 9)
	corner.Parent = frame

	local stroke = Instance.new("UIStroke")
	stroke.Color = COLORS.Accent
	stroke.Thickness = 1
	stroke.Transparency = 0.18
	stroke.Parent = frame

	local text = Instance.new("TextLabel")
	text.BackgroundTransparency = 1
	text.Font = Enum.Font.GothamBold
	text.Position = UDim2.fromOffset(8, 0)
	text.Size = UDim2.new(1, -16, 1, 0)
	text.TextColor3 = COLORS.Text
	text.TextSize = 11
	text.TextWrapped = true
	text.ZIndex = 11
	text.Parent = frame

	directionFrame = frame
	directionText = text
end

local function stopRenderTracking()
	if renderConnection ~= nil then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	if directionFrame ~= nil then
		directionFrame.Visible = false
	end
end

local function startRenderTracking()
	stopRenderTracking()
	if currentTarget == nil then
		return
	end

	renderConnection = RunService.RenderStepped:Connect(function()
		local target = currentTarget
		local frame = directionFrame
		local text = directionText
		local camera = Workspace.CurrentCamera
		if
			target == nil
			or target.Parent == nil
			or frame == nil
			or text == nil
			or camera == nil
		then
			return
		end

		local viewport = camera.ViewportSize
		if viewport.X <= 0 or viewport.Y <= 0 then
			frame.Visible = false
			return
		end

		local projected, onScreen =
			camera:WorldToViewportPoint(target.Position + Vector3.new(0, 4, 0))
		if onScreen and projected.Z > 0 then
			frame.Visible = false
			return
		end

		local x = projected.X
		local y = projected.Y
		if projected.Z <= 0 then
			x = viewport.X - x
			y = viewport.Y - y
		end

		local halfWidth = math.min(94, math.max(70, viewport.X * 0.22))
		local halfHeight = 21
		local margin = 14
		x = math.clamp(x, halfWidth + margin, viewport.X - halfWidth - margin)
		y = math.clamp(y, halfHeight + margin, viewport.Y - halfHeight - margin)

		local distance = getCharacterPosition()
		local studs = if distance ~= nil
			then math.floor((target.Position - distance).Magnitude + 0.5)
			else nil
		text.Text = if studs ~= nil
			then ("%s  •  %d studs"):format(currentLabel, studs)
			else currentLabel
		frame.Position = UDim2.fromOffset(x, y)
		frame.Size = UDim2.fromOffset(math.min(188, viewport.X - 28), 42)
		frame.Visible = true
	end)
end

local function clearTargetConnections()
	if targetAncestryConnection ~= nil then
		targetAncestryConnection:Disconnect()
		targetAncestryConnection = nil
	end
	if targetPromptConnection ~= nil then
		targetPromptConnection:Disconnect()
		targetPromptConnection = nil
	end
end

local refreshTarget: () -> ()

local function setTarget(target: BasePart?, labelText: string)
	if currentTarget == target and currentLabel == labelText then
		return
	end

	clearTargetConnections()
	currentTarget = target
	currentLabel = labelText
	stopRenderTracking()

	if target == nil then
		destroyTargetMarker()
		return
	end

	createTargetMarker(target, labelText)
	targetAncestryConnection = target.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			task.defer(refreshTarget)
		end
	end)

	local prompt = target:FindFirstChildOfClass("ProximityPrompt")
	if prompt ~= nil then
		targetPromptConnection = prompt:GetPropertyChangedSignal("Enabled"):Connect(function()
			task.defer(refreshTarget)
		end)
	end

	startRenderTracking()
end

refreshTarget = function()
	refreshQueued = false
	local currentSnapshot = snapshot
	if currentSnapshot == nil then
		setTarget(nil, "")
		return
	end

	local target, labelText = resolveTarget(currentSnapshot)
	setTarget(target, labelText)
end

local function queueRefresh()
	if refreshQueued then
		return
	end
	refreshQueued = true
	task.defer(refreshTarget)
end

local function acceptSnapshot(nextSnapshot: any)
	if typeof(nextSnapshot) ~= "table" then
		return
	end

	local currentSnapshot = snapshot
	if typeof(currentSnapshot) == "table" then
		local currentRevision = currentSnapshot.Revision
		local nextRevision = nextSnapshot.Revision
		if
			typeof(currentRevision) == "number"
			and typeof(nextRevision) == "number"
			and nextRevision < currentRevision
		then
			return
		end
	end

	snapshot = nextSnapshot
	queueRefresh()
end

function ObjectiveGuidanceController.Init()
	if initialized then
		return
	end
	initialized = true
	createDirectionGui()

	local stateRemote = Remotes:WaitForChild(RemoteNames.StateSnapshot) :: RemoteEvent
	local deltaRemote = Remotes:WaitForChild(RemoteNames.StateDelta) :: RemoteEvent
	local requestState = Remotes:WaitForChild(RemoteNames.RequestState) :: RemoteEvent
	local lastResyncRequest = -math.huge

	local function requestFreshState()
		local now = os.clock()
		if now - lastResyncRequest < 1 then
			return
		end
		lastResyncRequest = now
		requestState:FireServer()
	end

	stateRemote.OnClientEvent:Connect(acceptSnapshot)
	deltaRemote.OnClientEvent:Connect(function(delta)
		if snapshot == nil then
			requestFreshState()
			return
		end
		local nextSnapshot = StateHelpers.MergeProductionDelta(snapshot, delta)
		if nextSnapshot ~= snapshot then
			snapshot = nextSnapshot
			queueRefresh()
		end
	end)

	Workspace.DescendantAdded:Connect(function()
		if snapshot ~= nil and currentTarget == nil then
			queueRefresh()
		end
	end)

	LocalPlayer.CharacterAdded:Connect(function()
		queueRefresh()
	end)

	-- Do not depend on React UI mount order for the initial objective. This
	-- controller owns its own bounded resync request so guidance still appears
	-- if another state consumer initializes late or misses the first snapshot.
	requestFreshState()
end

return table.freeze(ObjectiveGuidanceController)
