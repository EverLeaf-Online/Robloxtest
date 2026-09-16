local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local planet = Workspace:WaitForChild("Planets"):WaitForChild("Planet_" .. player.UserId)
local core = planet:WaitForChild("Core")

local MIN_DISTANCE = 78
local MAX_DISTANCE = 205
local ROTATE_SPEED = 0.0055
local TOUCH_ROTATE_SPEED = 0.0065
local ZOOM_STEP = 10

local targetYaw = math.rad(30)
local targetPitch = math.rad(-10)
local targetDistance = 116
local yaw = targetYaw
local pitch = targetPitch
local distance = targetDistance
local mouseDragging = false
local activeTouches = {}
local lastPinchDistance

camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 62

local function clampPitch(value)
	return math.clamp(value, math.rad(-72), math.rad(72))
end

local function getTwoTouches()
	local first
	local second
	for touch in pairs(activeTouches) do
		if not first then
			first = touch
		elseif not second then
			second = touch
			break
		end
	end
	return first, second
end

local function refreshPinchBaseline()
	local first, second = getTwoTouches()
	if first and second then
		local firstPosition = Vector2.new(first.Position.X, first.Position.Y)
		local secondPosition = Vector2.new(second.Position.X, second.Position.Y)
		lastPinchDistance = (firstPosition - secondPosition).Magnitude
	else
		lastPinchDistance = nil
	end
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		mouseDragging = true
	elseif input.UserInputType == Enum.UserInputType.Touch then
		activeTouches[input] = true
		refreshPinchBaseline()
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		mouseDragging = false
	elseif input.UserInputType == Enum.UserInputType.Touch then
		activeTouches[input] = nil
		refreshPinchBaseline()
	end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if mouseDragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		targetYaw -= input.Delta.X * ROTATE_SPEED
		targetPitch = clampPitch(targetPitch - input.Delta.Y * ROTATE_SPEED)
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseWheel then
		targetDistance = math.clamp(targetDistance - input.Position.Z * ZOOM_STEP, MIN_DISTANCE, MAX_DISTANCE)
		return
	end

	if input.UserInputType == Enum.UserInputType.Touch and activeTouches[input] then
		local first, second = getTwoTouches()
		if first and second then
			local firstPosition = Vector2.new(first.Position.X, first.Position.Y)
			local secondPosition = Vector2.new(second.Position.X, second.Position.Y)
			local pinchDistance = (firstPosition - secondPosition).Magnitude
			if lastPinchDistance then
				local delta = pinchDistance - lastPinchDistance
				targetDistance = math.clamp(targetDistance - delta * 0.28, MIN_DISTANCE, MAX_DISTANCE)
			end
			lastPinchDistance = pinchDistance
		else
			targetYaw -= input.Delta.X * TOUCH_ROTATE_SPEED
			targetPitch = clampPitch(targetPitch - input.Delta.Y * TOUCH_ROTATE_SPEED)
		end
	end
end)

RunService:BindToRenderStep("GrowPlanetCamera", Enum.RenderPriority.Camera.Value + 1, function(deltaTime)
	if not core.Parent then
		return
	end

	local alpha = 1 - math.exp(-10 * deltaTime)
	yaw += (targetYaw - yaw) * alpha
	pitch += (targetPitch - pitch) * alpha
	distance += (targetDistance - distance) * alpha

	local center = core.Position
	local orbit = CFrame.fromOrientation(pitch, yaw, 0)
	local lookDirection = orbit.LookVector
	local cameraPosition = center - lookDirection * distance
	camera.CFrame = CFrame.lookAt(cameraPosition, center, Vector3.yAxis)
	camera.Focus = CFrame.new(center)
end)
