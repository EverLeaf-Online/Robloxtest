-- StarterPlayer/StarterPlayerScripts/Starfield.client.lua
-- Creates a local decorative starfield around the player's planet.

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local planetsFolder = Workspace:WaitForChild("Planets", 60)
if not planetsFolder then
	return
end

local planet = planetsFolder:WaitForChild("Planet_" .. player.UserId, 120)
if not planet or not planet.PrimaryPart then
	return
end

local folderName = "LocalStarfield_" .. player.UserId
local existing = Workspace:FindFirstChild(folderName)
if existing then
	existing:Destroy()
end

local folder = Instance.new("Folder")
folder.Name = folderName
folder.Parent = Workspace

local center = planet.PrimaryPart.Position

for _ = 1, 240 do
	local star = Instance.new("Part")
	star.Name = "Star"
	star.Anchored = true
	star.CanCollide = false
	star.CanQuery = false
	star.CanTouch = false
	star.Material = Enum.Material.Neon

	local hue = math.random()
	star.Color = Color3.fromHSV(hue, 0.12, 1)

	local size = math.random(10, 32) / 10
	star.Size = Vector3.new(size, size, size)

	local dir = Vector3.new(math.random() * 2 - 1, math.random() * 2 - 1, math.random() * 2 - 1)
	if dir.Magnitude < 0.01 then
		dir = Vector3.new(0, 1, 0)
	end
	dir = dir.Unit

	local distance = math.random(500, 1500)
	star.CFrame = CFrame.new(center + dir * distance)

	star.Parent = folder
end