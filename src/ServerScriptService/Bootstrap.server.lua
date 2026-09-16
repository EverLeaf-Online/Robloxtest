local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

Players.CharacterAutoLoads = false

local planetsFolder = Workspace:FindFirstChild("Planets")
if not planetsFolder then
	planetsFolder = Instance.new("Folder")
	planetsFolder.Name = "Planets"
	planetsFolder.Parent = Workspace
end

local baseplate = Workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	baseplate:Destroy()
end

for _, child in ipairs(Workspace:GetChildren()) do
	if child:IsA("SpawnLocation") then
		child:Destroy()
	end
end

Lighting.ClockTime = 0
Lighting.Brightness = 2.4
Lighting.Ambient = Color3.fromRGB(128, 138, 166)
Lighting.OutdoorAmbient = Color3.fromRGB(92, 104, 136)
Lighting.EnvironmentDiffuseScale = 0.75
Lighting.EnvironmentSpecularScale = 0.9
Lighting.FogEnd = 1_000_000
Lighting.GlobalShadows = true

local oldBloom = Lighting:FindFirstChild("GrowPlanetBloom")
if oldBloom then
	oldBloom:Destroy()
end
local bloom = Instance.new("BloomEffect")
bloom.Name = "GrowPlanetBloom"
bloom.Intensity = 0.32
bloom.Size = 22
bloom.Threshold = 1.4
bloom.Parent = Lighting

local oldColor = Lighting:FindFirstChild("GrowPlanetColor")
if oldColor then
	oldColor:Destroy()
end
local color = Instance.new("ColorCorrectionEffect")
color.Name = "GrowPlanetColor"
color.Brightness = 0.03
color.Contrast = 0.08
color.Saturation = 0.1
color.TintColor = Color3.fromRGB(228, 234, 255)
color.Parent = Lighting

print(string.format("[Grow a Tiny Planet] Bootstrap complete (StreamingEnabled=%s)", tostring(Workspace.StreamingEnabled)))
