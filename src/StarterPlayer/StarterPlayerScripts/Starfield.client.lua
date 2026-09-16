local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local planetsFolder = Workspace:WaitForChild("Planets", 30)
if not planetsFolder then
	return
end

local planet = planetsFolder:WaitForChild("Planet_" .. player.UserId, 60)
if not planet then
	return
end

local center = Vector3.new(
	planet:GetAttribute("CenterX") or 0,
	planet:GetAttribute("CenterY") or 0,
	planet:GetAttribute("CenterZ") or 0
)

local folderName = "LocalStarfield_" .. player.UserId
local existing = Workspace:FindFirstChild(folderName)
if existing then
	existing:Destroy()
end

local folder = Instance.new("Folder")
folder.Name = folderName
folder.Parent = Workspace

local rng = Random.new(player.UserId * 7919 + 17)
for index = 1, 240 do
	local direction = Vector3.new(
		rng:NextNumber(-1, 1),
		rng:NextNumber(-1, 1),
		rng:NextNumber(-1, 1)
	)
	if direction.Magnitude < 0.01 then
		direction = Vector3.yAxis
	end
	direction = direction.Unit

	local star = Instance.new("Part")
	star.Name = "Star_" .. index
	star.Shape = Enum.PartType.Ball
	local size = rng:NextNumber(0.18, 0.75)
	star.Size = Vector3.new(size, size, size)
	star.Anchored = true
	star.CanCollide = false
	star.CanQuery = false
	star.CanTouch = false
	star.CastShadow = false
	star.Material = Enum.Material.Neon
	star.Color = index % 11 == 0 and Color3.fromRGB(170, 205, 255) or Color3.fromRGB(245, 248, 255)
	star.Transparency = rng:NextNumber(0, 0.22)
	star.Position = center + direction * rng:NextNumber(220, 420)
	star.Parent = folder
end
