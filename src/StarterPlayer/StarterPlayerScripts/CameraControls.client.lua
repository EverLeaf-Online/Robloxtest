-- StarterPlayer/StarterPlayerScripts/CameraControls.client.lua
-- Orbit camera: left-click drag to rotate, mouse wheel to zoom, smooth lerp.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local MIN_DISTANCE = 70
local MAX_DISTANCE = 500

local targetDistance = 190
local currentDistance = 190

local targetYaw = 0.6
local targetPitch = 0.35

local currentYaw = targetYaw
local currentPitch = targetPitch

local dragging = false
local lastMousePos = nil

local planetsFolder = Workspace:WaitForChild("Planets", 60)
if not planetsFolder then
	warn("[CameraControls] Planets folder not found.")
	return
end

local planet = planetsFolder:WaitForChild("Planet_" .. player.UserId, 120)
if not planet then
	warn("[CameraControls] Player planet not found.")
	return
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		lastMousePos = input.Position
	end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		if dragging and lastMousePos then
			local delta = input.Position - lastMousePos
			lastMousePos = input.Position

			targetYaw -= delta.X * 0.005
			targetPitch -= delta.Y * 0.005

			local maxPitch = 1.45
			targetPitch = math.clamp(targetPitch, -maxPitch, maxPitch)
		end
	end

	if input.UserInputType == Enum.UserInputType.MouseWheel then
		targetDistance -= input.Position.Z * 18
		targetDistance = math.clamp(targetDistance, MIN_DISTANCE, MAX_DISTANCE)
	end
end)

UserInputService.InputEnded:Connect(function(input, _gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
		lastMousePos = nil
	end
end)

RunService.RenderStepped:Connect(function(dt)
	if not planet or not planet.PrimaryPart then
		return
	end

	camera.CameraType = Enum.CameraType.Scriptable

	local smooth = math.min(1, dt * 8)

	currentYaw += (targetYaw - currentYaw) * smooth
	currentPitch += (targetPitch - currentPitch) * smooth
	currentDistance += (targetDistance - currentDistance) * smooth

	local center = planet.PrimaryPart.Position
	local offset = CFrame.fromEulerAnglesYXZ(currentPitch, currentYaw, 0) * Vector3.new(0, 0, 1) * currentDistance

	camera.CFrame = CFrame.lookAt(center + offset, center)
end)