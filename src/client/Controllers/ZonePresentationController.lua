--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local ZonePresentationController = {}
local initialized = false

local function findGate(plotId: number): BasePart?
	local root = Workspace:FindFirstChild("ScrapToBotFactoryWorld")
	if root == nil then
		return nil
	end
	local plots = root:FindFirstChild("FactoryPlots")
	if plots == nil then
		return nil
	end
	local plot = plots:FindFirstChild(("Plot%02d"):format(plotId))
	if plot == nil or not plot:IsA("Model") then
		return nil
	end
	local gate = plot:FindFirstChild("CircuitYardGate")
	return if gate ~= nil and gate:IsA("BasePart") then gate else nil
end

local function applySnapshot(snapshot: any)
	if
		typeof(snapshot) ~= "table"
		or typeof(snapshot.Progression) ~= "table"
		or typeof(snapshot.Plot) ~= "table"
	then
		return
	end

	local currentZone = snapshot.Progression.Zone
	local plotId = snapshot.Plot.Id
	if typeof(currentZone) ~= "number" or typeof(plotId) ~= "number" then
		return
	end

	local gate = findGate(plotId)
	local zone = Zones[2]
	if gate == nil or zone == nil then
		return
	end

	local unlocked = currentZone >= zone.Id
	gate.Color = if unlocked then Color3.fromRGB(58, 137, 122) else Color3.fromRGB(103, 80, 67)
	gate.Material = if unlocked then Enum.Material.DiamondPlate else Enum.Material.Metal

	local prompt = gate:FindFirstChildOfClass("ProximityPrompt")
	if prompt ~= nil then
		prompt.ActionText = if unlocked then "Travel" else "Unlock / Travel"
		prompt.ObjectText = if unlocked
			then ("%s • Unlocked"):format(zone.DisplayName)
			else zone.DisplayName
	end

	local label = gate:FindFirstChild("Label", true)
	if label ~= nil and label:IsA("TextLabel") then
		label.Text = if unlocked
			then ("%s\nUNLOCKED • PRIVATE FIELD"):format(zone.DisplayName)
			else ("%s\n%d Credits • Build %d Bots"):format(
				zone.DisplayName,
				zone.UnlockCredits,
				zone.RequiredLifetimeRobots
			)
		label.TextColor3 = if unlocked
			then Color3.fromRGB(137, 255, 213)
			else Color3.fromRGB(245, 247, 250)
	end
end

function ZonePresentationController.Init()
	if initialized then
		return
	end
	initialized = true

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local stateSnapshot = remotes:WaitForChild(RemoteNames.StateSnapshot) :: RemoteEvent
	local requestState = remotes:WaitForChild(RemoteNames.RequestState) :: RemoteEvent

	stateSnapshot.OnClientEvent:Connect(applySnapshot)
	requestState:FireServer()
end

return ZonePresentationController
