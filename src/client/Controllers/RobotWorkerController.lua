--!strict

local PathfindingService = game:GetService("PathfindingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local Workspace = game:GetService("Workspace")

local Robots = require(ReplicatedStorage.Shared.Config.Robots)
local RobotWorkRules = require(ReplicatedStorage.Shared.Domain.RobotWorkRules)

local RobotWorkerController = {}
local initialized = false

local LocalPlayer = Players.LocalPlayer
local activeWorkers: { [Model]: boolean } = {}
local boundPlots: { [Model]: boolean } = {}

local MAX_ANIMATION_DISTANCE = 280
local WORK_HEIGHT = 3

local NAV_AGENT_RADIUS = 2.5
local NAV_AGENT_HEIGHT = 6
local NAV_WAYPOINT_SPACING = 5
local NAV_REPATH_ATTEMPTS = 3
local NAV_REPATH_DELAY = 0.12
local NAV_MAX_CONCURRENT_COMPUTES = 4
local NAV_CLEARANCE_SIZE = Vector3.new(4.2, 4.8, 4.2)

local activePathComputes = 0

local function getCharacterPosition(): Vector3?
	local character = LocalPlayer.Character
	if character == nil then
		return nil
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart == nil or not rootPart:IsA("BasePart") then
		return nil
	end
	return rootPart.Position
end

local function isNearLocalPlayer(rootPart: BasePart): boolean
	local position = getCharacterPosition()
	return position ~= nil and (position - rootPart.Position).Magnitude <= MAX_ANIMATION_DISTANCE
end

local function getPlot(model: Model): Model?
	local visualFolder = model.Parent
	local plot = if visualFolder ~= nil then visualFolder.Parent else nil
	return if plot ~= nil and plot:IsA("Model") then plot else nil
end

local function getHomePad(plot: Model, model: Model): BasePart?
	local padId = model:GetAttribute("HomePadId")
	if typeof(padId) ~= "string" then
		return nil
	end
	local folder = plot:FindFirstChild("WorkPads")
	if folder == nil then
		return nil
	end
	local pad = folder:FindFirstChild(padId)
	return if pad ~= nil and pad:IsA("BasePart") then pad else nil
end

local function getWorkNode(plot: Model, nodeName: string): BasePart?
	local folder = plot:FindFirstChild("BotWorkNodes")
	if folder == nil then
		return nil
	end
	local node = folder:FindFirstChild(nodeName)
	return if node ~= nil and node:IsA("BasePart") then node else nil
end

local function getMotionRoot(model: Model): BasePart?
	local rootPart = model:FindFirstChild("MotionRoot")
	return if rootPart ~= nil and rootPart:IsA("BasePart") then rootPart else nil
end

local function routeOffset(model: Model): Vector3
	local padId = model:GetAttribute("HomePadId")
	local indexText = if typeof(padId) == "string" then string.match(padId, "^Pad(%d+)$") else nil
	local index = if indexText ~= nil then tonumber(indexText) else 1
	if index == nil then
		index = 1
	end

	local column = (index - 1) % 3
	local row = math.floor((index - 1) / 3)
	return Vector3.new((column - 1) * 2.5, 0, (row - 0.5) * 2.5)
end

local function targetPosition(target: BasePart, offset: Vector3): Vector3
	return target.Position + offset + Vector3.new(0, WORK_HEIGHT, 0)
end

local function cframeForPosition(rootPart: BasePart, position: Vector3): CFrame
	local delta = position - rootPart.Position
	local horizontal = Vector3.new(delta.X, 0, delta.Z)
	if horizontal.Magnitude < 0.05 then
		return CFrame.new(position) * rootPart.CFrame.Rotation
	end
	return CFrame.lookAt(position, position + horizontal.Unit)
end

local function acquirePathCompute(model: Model): boolean
	while activePathComputes >= NAV_MAX_CONCURRENT_COMPUTES do
		if model.Parent == nil then
			return false
		end
		task.wait(0.03)
	end

	activePathComputes += 1
	return true
end

local function computePath(model: Model, startPosition: Vector3, endPosition: Vector3): Path?
	if not acquirePathCompute(model) then
		return nil
	end

	local path = PathfindingService:CreatePath({
		AgentRadius = NAV_AGENT_RADIUS,
		AgentHeight = NAV_AGENT_HEIGHT,
		AgentCanJump = false,
		AgentCanClimb = false,
		WaypointSpacing = NAV_WAYPOINT_SPACING,
	})

	local ok = pcall(function()
		path:ComputeAsync(startPosition, endPosition)
	end)
	activePathComputes -= 1

	if not ok or path.Status ~= Enum.PathStatus.Success then
		return nil
	end

	return path
end

local function hasSegmentClearance(model: Model, rootPart: BasePart, destination: Vector3): boolean
	local direction = destination - rootPart.Position
	local distance = direction.Magnitude
	if distance <= 0.6 then
		return true
	end

	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = { model }
	params.RespectCanCollide = true

	local travel = direction.Unit * math.max(0, distance - 0.45)
	local result = Workspace:Blockcast(rootPart.CFrame, NAV_CLEARANCE_SIZE, travel, params)
	return result == nil
end

local function tweenSegment(
	model: Model,
	rootPart: BasePart,
	destination: Vector3,
	speed: number
): (boolean, Tween?)
	if model.Parent == nil then
		return false, nil
	end
	if not hasSegmentClearance(model, rootPart, destination) then
		return false, nil
	end

	local distance = (destination - rootPart.Position).Magnitude
	if distance <= 0.15 then
		return true, nil
	end

	local duration = math.clamp(distance / math.max(1, speed), 0.08, 3)
	local tween = TweenService:Create(
		rootPart,
		TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{ CFrame = cframeForPosition(rootPart, destination) }
	)
	tween:Play()
	local playbackState = tween.Completed:Wait()
	return model.Parent ~= nil and playbackState == Enum.PlaybackState.Completed, tween
end

local function followPath(
	model: Model,
	rootPart: BasePart,
	path: Path,
	destination: Vector3,
	speed: number
): boolean
	local waypoints = path:GetWaypoints()
	if #waypoints < 2 then
		return false
	end

	local currentWaypointIndex = 2
	local pathBlocked = false
	local activeTween: Tween? = nil
	local blockedConnection = path.Blocked:Connect(function(blockedWaypointIndex)
		if blockedWaypointIndex >= currentWaypointIndex then
			pathBlocked = true
			if activeTween ~= nil then
				activeTween:Cancel()
			end
		end
	end)

	for waypointIndex = 2, #waypoints do
		if model.Parent == nil or pathBlocked then
			blockedConnection:Disconnect()
			return false
		end

		currentWaypointIndex = waypointIndex
		local waypoint = waypoints[waypointIndex]
		if waypoint.Action == Enum.PathWaypointAction.Jump then
			blockedConnection:Disconnect()
			return false
		end

		local waypointPosition =
			Vector3.new(waypoint.Position.X, destination.Y, waypoint.Position.Z)

		local ok, tween = tweenSegment(model, rootPart, waypointPosition, speed)
		activeTween = tween
		if not ok then
			blockedConnection:Disconnect()
			return false
		end
		activeTween = nil
	end

	blockedConnection:Disconnect()

	if (destination - rootPart.Position).Magnitude > 0.5 then
		local ok = tweenSegment(model, rootPart, destination, speed)
		return ok
	end

	return true
end

local function moveTo(
	model: Model,
	rootPart: BasePart,
	target: BasePart,
	speed: number,
	offset: Vector3?
): boolean
	if model.Parent == nil then
		return false
	end

	local destination = targetPosition(target, offset or Vector3.zero)
	model:SetAttribute("PresentationState", "Travelling")

	for attempt = 1, NAV_REPATH_ATTEMPTS do
		if model.Parent == nil then
			return false
		end

		local path = computePath(model, rootPart.Position, destination)
		if path ~= nil and followPath(model, rootPart, path, destination, speed) then
			return true
		end

		if attempt < NAV_REPATH_ATTEMPTS then
			model:SetAttribute("PresentationState", "Repathing")
			task.wait(NAV_REPATH_DELAY * attempt)
		end
	end

	model:SetAttribute("PresentationState", "PathBlocked")
	return false
end

local function workAnimation(model: Model, rootPart: BasePart, seconds: number)
	model:SetAttribute("PresentationState", "Working")
	local motor = rootPart:FindFirstChild("ToolMotor")
	local cycles = math.max(1, math.floor(seconds / 0.45))

	if motor == nil or not motor:IsA("Motor6D") then
		task.wait(seconds)
		return
	end

	for cycle = 1, cycles do
		if model.Parent == nil then
			return
		end
		local angle = if cycle % 2 == 0 then math.rad(18) else math.rad(-24)
		local forward = TweenService:Create(
			motor,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out),
			{ Transform = CFrame.Angles(angle, 0, 0) }
		)
		forward:Play()
		forward.Completed:Wait()

		local back = TweenService:Create(
			motor,
			TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.InOut),
			{ Transform = CFrame.new() }
		)
		back:Play()
		back.Completed:Wait()
	end
end

local function idleAtHome(model: Model, rootPart: BasePart)
	model:SetAttribute("PresentationState", "Idle")
	local start = rootPart.CFrame
	local up = TweenService:Create(
		rootPart,
		TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.Out),
		{ CFrame = start * CFrame.new(0, 0.15, 0) }
	)
	up:Play()
	up.Completed:Wait()
	if model.Parent == nil then
		return
	end
	local down = TweenService:Create(
		rootPart,
		TweenInfo.new(0.28, Enum.EasingStyle.Sine, Enum.EasingDirection.In),
		{ CFrame = start }
	)
	down:Play()
	down.Completed:Wait()
end

local function runWorker(model: Model)
	if activeWorkers[model] then
		return
	end
	activeWorkers[model] = true

	task.spawn(function()
		while model.Parent ~= nil do
			local plot = getPlot(model)
			local rootPart = getMotionRoot(model)
			local robotId = model:GetAttribute("RobotId")
			if
				plot == nil
				or rootPart == nil
				or typeof(robotId) ~= "string"
				or Robots.Definitions[robotId] == nil
			then
				task.wait(0.5)
				continue
			end

			if not isNearLocalPlayer(rootPart) then
				model:SetAttribute("PresentationState", "Culled")
				task.wait(1.5)
				continue
			end

			local definition = Robots.Definitions[robotId]
			local route = RobotWorkRules.GetRoute(definition.Family)
			local speed = RobotWorkRules.GetMoveSpeed(definition.Visual.Locomotion)
			local workSeconds = RobotWorkRules.GetWorkPauseSeconds(definition.Family)
			local unlockedZone = plot:GetAttribute("UnlockedZone")
			if typeof(unlockedZone) ~= "number" then
				unlockedZone = 1
			end

			for _, nodeName in route do
				if model.Parent == nil then
					break
				end
				if nodeName == "CircuitSalvage" and unlockedZone < 2 then
					continue
				end

				local node = getWorkNode(plot, nodeName)
				if node ~= nil then
					if not moveTo(model, rootPart, node, speed, routeOffset(model)) then
						break
					end
					workAnimation(model, rootPart, workSeconds)
				end
			end

			if model.Parent == nil then
				break
			end
			local homePad = getHomePad(plot, model)
			if homePad ~= nil then
				moveTo(model, rootPart, homePad, speed)
			end
			if model.Parent ~= nil then
				idleAtHome(model, rootPart)
				task.wait(0.6)
			end
		end

		activeWorkers[model] = nil
	end)
end

local function bindVisualFolder(folder: Folder)
	for _, child in folder:GetChildren() do
		if child:IsA("Model") then
			runWorker(child)
		end
	end

	folder.ChildAdded:Connect(function(child)
		if child:IsA("Model") then
			runWorker(child)
		end
	end)
end

local function bindPlot(plot: Model)
	if boundPlots[plot] then
		return
	end
	boundPlots[plot] = true

	local existing = plot:FindFirstChild("RobotVisuals")
	if existing ~= nil and existing:IsA("Folder") then
		bindVisualFolder(existing)
	end

	plot.ChildAdded:Connect(function(child)
		if child.Name == "RobotVisuals" and child:IsA("Folder") then
			bindVisualFolder(child)
		end
	end)
end

function RobotWorkerController.Init()
	if initialized then
		return
	end
	initialized = true

	task.spawn(function()
		local root = Workspace:WaitForChild("ScrapToBotGraybox")
		local plots = root:WaitForChild("FactoryPlots")

		for _, plot in plots:GetChildren() do
			if plot:IsA("Model") then
				bindPlot(plot)
			end
		end

		plots.ChildAdded:Connect(function(child)
			if child:IsA("Model") then
				bindPlot(child)
			end
		end)
	end)
end

return RobotWorkerController
