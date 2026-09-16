-- StarterPlayer/StarterPlayerScripts/CameraControls.client.lua
-- Reliable orbit camera for the local player's planet.

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera

local MIN_DISTANCE = 78
local MAX_DISTANCE = 240
local targetDistance = 122
local currentDistance = targetDistance
local targetYaw = math.rad(32)
local targetPitch = math.rad(-12)
local currentYaw = targetYaw
local currentPitch = targetPitch
local dragging = false
local lastPointerPosition = nil

local planetsFolder = Workspace:WaitForChild("Planets", 30)
if not planetsFolder then
	warn("[CameraControls] Planets folder not found")
	return
end

local planet = planetsFolder:WaitForChild("Planet_" .. player.UserId, 60)
if not planet then
	warn("[CameraControls] Local player planet not found")
	return
end

local baseSphere = planet:WaitForChild("BaseSphere", 30)
if not baseSphere or not baseSphere:IsA("BasePart") then
	warn("[CameraControls] BaseSphere not found on local planet")
	return
end

camera.CameraType = Enum.CameraType.Scriptable
camera.FieldOfView = 55

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = true
		lastPointerPosition = Vector2.new(input.Position.X, input.Position.Y)
	end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if input.UserInputType == Enum.UserInputType.MouseWheel and not gameProcessed then
		targetDistance = math.clamp(targetDistance - input.Position.Z * 10, MIN_DISTANCE, MAX_DISTANCE)
		return
	end

	if not dragging or gameProcessed then
		return
	end

	if input.UserInputType == Enum.UserInputType.MouseMovement or input.UserInputType == Enum.UserInputType.Touch then
		local current = Vector2.new(input.Position.X, input.Position.Y)
		if lastPointerPosition then
			local delta = current - lastPointerPosition
			targetYaw -= delta.X * 0.0055
			targetPitch = math.clamp(targetPitch - delta.Y * 0.0055, math.rad(-75), math.rad(75))
		end
		lastPointerPosition = current
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 or input.UserInputType == Enum.UserInputType.Touch then
		dragging = false
		lastPointerPosition = nil
	end
end)

RunService:BindToRenderStep("GrowTinyPlanetCamera", Enum.RenderPriority.Camera.Value + 1, function(dt)
	if not baseSphere.Parent then
		return
	end

	local alpha = 1 - math.exp(-10 * dt)
	currentYaw += (targetYaw - currentYaw) * alpha
	currentPitch += (targetPitch - currentPitch) * alpha
	currentDistance += (targetDistance - currentDistance) * alpha

	local center = baseSphere.Position
	local orbit = CFrame.fromOrientation(currentPitch, currentYaw, 0)
	local direction = orbit.LookVector
	local cameraPosition = center - direction * currentDistance
	camera.CFrame = CFrame.lookAt(cameraPosition, center, Vector3.yAxis)
	camera.Focus = CFrame.new(center)
end)

print("[Grow a Tiny Planet] Camera attached to", planet.Name)
