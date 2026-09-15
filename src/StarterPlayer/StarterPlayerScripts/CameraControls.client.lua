local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local camera = Workspace.CurrentCamera
local planet = Workspace:WaitForChild("Planets"):WaitForChild("Planet_" .. player.UserId)
local core = planet:WaitForChild("Core")

local targetYaw = math.rad(30)
local targetPitch = math.rad(-12)
local targetDistance = 145
local yaw = targetYaw
local pitch = targetPitch
local distance = targetDistance
local dragging = false

camera.CameraType = Enum.CameraType.Scriptable

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = true
	end
end)

UserInputService.InputEnded:Connect(function(input)
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		dragging = false
	end
end)

UserInputService.InputChanged:Connect(function(input, gameProcessed)
	if gameProcessed then
		return
	end
	if dragging and input.UserInputType == Enum.UserInputType.MouseMovement then
		targetYaw -= input.Delta.X * 0.0055
		targetPitch = math.clamp(targetPitch - input.Delta.Y * 0.0055, math.rad(-72), math.rad(72))
	elseif input.UserInputType == Enum.UserInputType.MouseWheel then
		targetDistance = math.clamp(targetDistance - input.Position.Z * 10, 92, 230)
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
