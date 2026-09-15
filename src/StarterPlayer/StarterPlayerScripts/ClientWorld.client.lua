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

-- Keep the scene visually in deep space while providing enough ambient fill for
-- the earthy starting planet to remain readable from every orbit angle. Using a
-- daytime ClockTime would light the planet but would also turn the default sky
-- bright blue, which breaks the space presentation.
Lighting.Brightness = 2
Lighting.ClockTime = 0
Lighting.Ambient = Color3.fromRGB(128, 138, 166)
Lighting.OutdoorAmbient = Color3.fromRGB(94, 105, 137)
Lighting.EnvironmentDiffuseScale = 0.75
Lighting.EnvironmentSpecularScale = 0.9
Lighting.GlobalShadows = true

local existingBloom = Lighting:FindFirstChild("GrowPlanetBloom")
if existingBloom then
	existingBloom:Destroy()
end
local bloom = Instance.new("BloomEffect")
bloom.Name = "GrowPlanetBloom"
bloom.Intensity = 0.45
bloom.Size = 22
bloom.Threshold = 1.35
bloom.Parent = Lighting

local existingColor = Lighting:FindFirstChild("GrowPlanetColor")
if existingColor then
	existingColor:Destroy()
end
local color = Instance.new("ColorCorrectionEffect")
color.Name = "GrowPlanetColor"
color.Brightness = 0.035
color.Contrast = 0.08
color.Saturation = 0.12
color.TintColor = Color3.fromRGB(224, 230, 255)
color.Parent = Lighting

-- A local key light gives the sphere shape and depth without changing the sky.
-- It follows the planet model rather than the camera, so orbiting still reveals
-- a natural light-to-shadow transition instead of a flat fully-lit ball.
local oldKeyLight = Workspace:FindFirstChild("_ClientPlanetKeyLight")
if oldKeyLight then
	oldKeyLight:Destroy()
end
local keyLightPart = Instance.new("Part")
keyLightPart.Name = "_ClientPlanetKeyLight"
keyLightPart.Anchored = true
keyLightPart.CanCollide = false
keyLightPart.CanTouch = false
keyLightPart.CanQuery = false
keyLightPart.CastShadow = false
keyLightPart.Transparency = 1
keyLightPart.Size = Vector3.new(1, 1, 1)
keyLightPart.Position = center + Vector3.new(-70, 55, 95)
keyLightPart.Parent = Workspace

local keyLight = Instance.new("PointLight")
keyLight.Name = "PlanetKeyLight"
keyLight.Brightness = 4.5
keyLight.Range = 220
keyLight.Shadows = true
keyLight.Color = Color3.fromRGB(225, 235, 255)
keyLight.Parent = keyLightPart

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
