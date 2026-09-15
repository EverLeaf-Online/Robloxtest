local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer

local function waitForPlanet()
	local planets = Workspace:WaitForChild("Planets")
	return planets:WaitForChild("Planet_" .. player.UserId)
end

local planet = waitForPlanet()
local core = planet:WaitForChild("Core")
local center = core.Position

Lighting.Brightness = 1.2
Lighting.ClockTime = 0
Lighting.Ambient = Color3.fromRGB(32, 37, 61)
Lighting.OutdoorAmbient = Color3.fromRGB(18, 23, 42)
Lighting.EnvironmentDiffuseScale = 0.35
Lighting.EnvironmentSpecularScale = 0.75

local existingBloom = Lighting:FindFirstChild("GrowPlanetBloom")
if not existingBloom then
	local bloom = Instance.new("BloomEffect")
	bloom.Name = "GrowPlanetBloom"
	bloom.Intensity = 0.7
	bloom.Size = 24
	bloom.Threshold = 1.2
	bloom.Parent = Lighting
end

local existingColor = Lighting:FindFirstChild("GrowPlanetColor")
if not existingColor then
	local color = Instance.new("ColorCorrectionEffect")
	color.Name = "GrowPlanetColor"
	color.Brightness = -0.04
	color.Contrast = 0.12
	color.Saturation = 0.08
	color.TintColor = Color3.fromRGB(210, 220, 255)
	color.Parent = Lighting
end

local oldStars = Workspace:FindFirstChild("_ClientStars")
if oldStars then
	oldStars:Destroy()
end

local stars = Instance.new("Folder")
stars.Name = "_ClientStars"
stars.Parent = Workspace

local rng = Random.new(player.UserId * 7919 + 17)
for index = 1, 220 do
	local direction = Vector3.new(
		rng:NextNumber(-1, 1),
		rng:NextNumber(-1, 1),
		rng:NextNumber(-1, 1)
	)
	if direction.Magnitude < 0.01 then
		direction = Vector3.new(1, 0, 0)
	end
	direction = direction.Unit
	local distance = rng:NextNumber(190, 330)
	local size = rng:NextNumber(0.18, 0.7)
	local star = Instance.new("Part")
	star.Name = "Star_" .. index
	star.Shape = Enum.PartType.Ball
	star.Size = Vector3.new(size, size, size)
	star.Color = index % 9 == 0 and Color3.fromRGB(170, 205, 255) or Color3.fromRGB(245, 248, 255)
	star.Material = Enum.Material.Neon
	star.Transparency = rng:NextNumber(0, 0.25)
	star.Anchored = true
	star.CanCollide = false
	star.CanTouch = false
	star.CanQuery = false
	star.CastShadow = false
	star.Position = center + direction * distance
	star.Parent = stars
end
