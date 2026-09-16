-- ServerScriptService/Bootstrap.server.lua
-- Global server bootstrap: disables character spawning, prepares workspace/lighting.

local Players = game:GetService("Players")
local Lighting = game:GetService("Lighting")
local Workspace = game:GetService("Workspace")

-- This is a planet-viewing game, so we do not need Roblox avatars walking around.
Players.CharacterAutoLoads = false

local planetsFolder = Workspace:FindFirstChild("Planets")
if not planetsFolder then
	planetsFolder = Instance.new("Folder")
	planetsFolder.Name = "Planets"
	planetsFolder.Parent = Workspace
end

-- Space-style lighting.
Lighting.Ambient = Color3.fromRGB(85, 95, 125)
Lighting.OutdoorAmbient = Color3.fromRGB(45, 55, 85)
Lighting.Brightness = 2
Lighting.ClockTime = 0
Lighting.FogEnd = 1_000_000
Lighting.GlobalShadows = true

pcall(function()
	Lighting.Technology = Enum.Technology.Future
end)

print("[Grow a Tiny Planet] Bootstrap complete")