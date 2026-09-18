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

	local prompt = gate:FindFirstChildOfClass("ProximityPrompt")
	if prompt ~= nil then
		prompt.Enabled = not unlocked
		prompt.ActionText = "Unlock"
		prompt.ObjectText = ("%s • %d Credits • Build %d Bots"):format(
			zone.DisplayName,
			zone.UnlockCredits,
			zone.RequiredLifetimeRobots
		)
	end

	local billboard = gate:FindFirstChild("CircuitUnlockLabel")
	if billboard ~= nil and billboard:IsA("BillboardGui") then
		billboard.Enabled = not unlocked
	end

	local label = gate:FindFirstChild("Label", true)
	if label ~= nil and label:IsA("TextLabel") then
		label.Text = ("CIRCUIT YARD ACCESS\n%d CREDITS • BUILD %d BOTS"):format(
			zone.UnlockCredits,
			zone.RequiredLifetimeRobots
		)
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
