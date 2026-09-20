--!strict

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

local function targetCFrame(rootPart: BasePart, target: BasePart, offset: Vector3): CFrame
	local destination = target.Position + offset + Vector3.new(0, WORK_HEIGHT, 0)
	local delta = destination - rootPart.Position
	local horizontal = Vector3.new(delta.X, 0, delta.Z)
	if horizontal.Magnitude < 0.05 then
		return CFrame.new(destination) * rootPart.CFrame.Rotation
	end

	return CFrame.lookAt(destination, destination + horizontal.Unit)
end

local function moveTo(
	model: Model,
	rootPart: BasePart,
	target: BasePart,
	speed: number,
	offset: Vector3?
): boolean
	if model.Parent == nil or rootPart.Parent == nil or target.Parent == nil then
		return false
	end

	local destination = targetCFrame(rootPart, target, offset or Vector3.zero)
	local distance = (destination.Position - rootPart.Position).Magnitude
	if distance <= 0.15 then
		return true
	end

	local duration = math.clamp(distance / math.max(1, speed), 0.15, 12)
	model:SetAttribute("PresentationState", "Travelling")

	-- Robot travel is presentation-only. Passive production and assignments are
	-- server-authoritative, and these targets are authored factory work nodes.
	-- Direct tweening avoids route-specific navmesh/clearance failures that can
	-- strand one pad while another continues to animate.
	local tween = TweenService:Create(
		rootPart,
		TweenInfo.new(duration, Enum.EasingStyle.Linear),
		{ CFrame = destination }
	)
	tween:Play()
	local playbackState = tween.Completed:Wait()

	return model.Parent ~= nil
		and rootPart.Parent ~= nil
		and playbackState == Enum.PlaybackState.Completed
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
	plot.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			boundPlots[plot] = nil
		end
	end)

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
		local root = Workspace:WaitForChild("ScrapToBotFactoryWorld")
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
