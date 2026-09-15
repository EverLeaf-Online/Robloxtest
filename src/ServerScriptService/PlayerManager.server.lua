local Players = game:GetService("Players")

local PlanetStateService = require(script.Parent.PlanetStateService)
local PlanetRenderer = require(script.Parent.PlanetRenderer)
local EnergySystem = require(script.Parent.EnergySystem)
local MonetizationService = require(script.Parent.MonetizationService)
local MilestoneSystem = require(script.Parent.MilestoneSystem)

local initialized = {}

local function parkCharacter(player, character)
	local center = PlanetStateService.GetCenter(player)
	if not center then
		return
	end
	local root = character:WaitForChild("HumanoidRootPart", 10)
	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if root then
		root.CFrame = CFrame.new(center + Vector3.new(0, -250, 0))
		root.Anchored = true
	end
	if humanoid then
		humanoid.WalkSpeed = 0
		humanoid.JumpPower = 0
		humanoid.AutoRotate = false
	end
	for _, descendant in ipairs(character:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.Transparency = 1
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
		elseif descendant:IsA("Decal") then
			descendant.Transparency = 1
		end
	end
end

local function onPlayerAdded(player)
	if initialized[player.UserId] then
		return
	end
	initialized[player.UserId] = true

	PlanetStateService.LoadPlayer(player)
	MonetizationService.RefreshPasses(player)
	local starterApplied = MonetizationService.ApplyStarterBenefit(player)
	PlanetRenderer.CreatePlanet(player)
	MilestoneSystem.Check(player)
	if starterApplied then
		PlanetStateService.QueueSave(player)
	end
	EnergySystem.Start(player)

	player.CharacterAdded:Connect(function(character)
		task.defer(parkCharacter, player, character)
	end)
	if player.Character then
		task.defer(parkCharacter, player, player.Character)
	end
end

local function onPlayerRemoving(player)
	initialized[player.UserId] = nil
	EnergySystem.Stop(player)
	if PlanetStateService.IsLoaded(player) then
		PlanetStateService.SavePlayer(player)
	end
	PlanetRenderer.DestroyPlanet(player)
	PlanetStateService.UnloadPlayer(player)
end

Players.PlayerAdded:Connect(onPlayerAdded)
Players.PlayerRemoving:Connect(onPlayerRemoving)

for _, player in ipairs(Players:GetPlayers()) do
	task.spawn(onPlayerAdded, player)
end
