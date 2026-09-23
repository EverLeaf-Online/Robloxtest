print("LIVE_PLACE_SMOKE_OK")
print("PLACE_ID", game.PlaceId)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local packages = ReplicatedStorage:FindFirstChild("Packages")
print("PACKAGES", packages ~= nil, packages and packages.ClassName or "nil")
if packages ~= nil then
	local react = packages:FindFirstChild("React")
	local reactRoblox = packages:FindFirstChild("ReactRoblox")
	print("REACT", react ~= nil, react and react.ClassName or "nil")
	print("REACT_ROBLOX", reactRoblox ~= nil, reactRoblox and reactRoblox.ClassName or "nil")
end

local starterScripts = StarterPlayer:FindFirstChild("StarterPlayerScripts")
print("STARTER_PLAYER_SCRIPTS", starterScripts ~= nil)
local client = if starterScripts ~= nil then starterScripts:FindFirstChild("Client") else nil
print("CLIENT", client ~= nil, client and client.ClassName or "nil")

if client ~= nil then
	local bootstrap = client:FindFirstChild("Bootstrap")
	local controllers = client:FindFirstChild("Controllers")
	local ui = client:FindFirstChild("UI")

	print("CLIENT_BOOTSTRAP", bootstrap ~= nil, bootstrap and bootstrap.ClassName or "nil")
	if bootstrap ~= nil and bootstrap:IsA("LocalScript") then
		print("CLIENT_BOOTSTRAP_ENABLED", bootstrap.Enabled)
		local ok, source = pcall(function()
			return bootstrap.Source
		end)
		print("CLIENT_BOOTSTRAP_SOURCE_READABLE", ok)
		if ok then
			print("CLIENT_BOOTSTRAP_SOURCE_LENGTH", #source)
			print(
				"CLIENT_BOOTSTRAP_HAS_UI_INIT",
				string.find(source, "UIController.Init()", 1, true) ~= nil
			)
			print(
				"CLIENT_BOOTSTRAP_HAS_HUB_INIT",
				string.find(source, "HubUIController.Init()", 1, true) ~= nil
			)
		end
	end
	print("CONTROLLERS", controllers ~= nil)
	print("UI_FOLDER", ui ~= nil)
	if controllers ~= nil then
		print("UI_CONTROLLER", controllers:FindFirstChild("UIController") ~= nil)
		print("HUB_UI_CONTROLLER", controllers:FindFirstChild("HubUIController") ~= nil)
		print(
			"GAMEPAD_CONTROLLER",
			controllers:FindFirstChild("GamepadNavigationController") ~= nil
		)
	end
end

local serverScripts = game:GetService("ServerScriptService")
local server = serverScripts:FindFirstChild("Server")
print("SERVER_CONTAINER", server ~= nil)
if server ~= nil then
	local bootstrap = server:FindFirstChild("Bootstrap")
	print("SERVER_BOOTSTRAP", bootstrap ~= nil, bootstrap and bootstrap.ClassName or "nil")
end

local HttpService = game:GetService("HttpService")
print("HTTP_ENABLED", HttpService.HttpEnabled)
assert(HttpService.HttpEnabled, "Live place must have HTTP requests enabled")

local secretOk, secretOrError =
	pcall(HttpService.GetSecret, HttpService, "SCRAPBOT_DISCORD_WEBHOOK_SECRET")
print("DISCORD_SECRET_AVAILABLE", secretOk)
assert(secretOk, ("Live Discord secret unavailable: %s"):format(tostring(secretOrError)))

-- Exercise the shipped architecture in this isolated Open Cloud session.
assert(server ~= nil, "Server sources missing")
local presentation = server:FindFirstChild("Presentation")
assert(presentation ~= nil, "Presentation sources missing")
local builderModule = presentation:FindFirstChild("FactoryEnvironmentBuilder")
assert(builderModule ~= nil and builderModule:IsA("ModuleScript"), "Factory builder missing")
local builder = require(builderModule)
local testPlot = Instance.new("Model")
testPlot.Name = "ScrapyardDeploymentProbe"
local environment = builder.Build(testPlot, 999, Vector3.new(1000, 0, 1000))
assert(environment:GetAttribute("ArtRevision") == "ScrapyardWorkshop1", "Wrong art revision")
assert(environment:FindFirstChild("SalvageTruck") ~= nil, "Salvage truck missing")
assert(environment:FindFirstChild("ScrapProcessTrain") ~= nil, "Processing train missing")
assert(environment:FindFirstChild("BotWorksLandmark") ~= nil, "Robot landmark missing")
local head = environment:FindFirstChild("RobotHead", true)
assert(head ~= nil and head:IsA("BasePart"), "Robot head geometry missing")
assert(head.Position == Vector3.new(1037, 25.5, 1061), "Plot translation failed")
local count = 0
for _, instance in environment:GetDescendants() do
	if instance:IsA("BasePart") then
		assert(instance.Anchored, "Unanchored factory geometry")
		count += 1
	end
end
assert(count <= 900, "Factory part budget exceeded")
print("SCRAPYARD_RUNTIME_OK", count, game.PlaceVersion)
testPlot:Destroy()

local expeditionModule = presentation:FindFirstChild("ExpeditionBuilder")
assert(
	expeditionModule ~= nil and expeditionModule:IsA("ModuleScript"),
	"Expedition builder missing"
)
local expeditionBuilder = require(expeditionModule)
local probe = Instance.new("Model")
for zoneId = 3, 4 do
	local region = expeditionBuilder.Build(probe, 999, Vector3.zero, zoneId)
	assert(#region.Nodes == 12, "Expedition salvage layout incomplete")
	assert(
		region.Root:GetAttribute("ArtRevision") == "SalvageExpeditions1",
		"Wrong expedition revision"
	)
	assert(region.Return:GetAttribute("CurrentZone") == zoneId, "Return portal zone mismatch")
	assert(region.Arrival.Position.Y > 0, "Arrival below floor")
end
local zones = require(ReplicatedStorage.Shared.Config.Zones)
assert(
	zones[3].DisplayName == "Rustrail Depot" and zones[4].DisplayName == "Dynamo Works",
	"Missing expedition catalog"
)
probe:Destroy()
print("SALVAGE_EXPEDITIONS_RUNTIME_OK", game.PlaceVersion)

-- Build the full private factory in this isolated session to verify service wiring.
local worldService = require(server.Services.WorldService)
worldService.Init()
local worldLayout = require(ReplicatedStorage.Shared.Config.WorldLayout)
local factoryPlot = worldService.GetPlot(1)
assert(factoryPlot ~= nil, "Factory plot missing")
local factoryFloor = factoryPlot:FindFirstChild("Floor")
assert(factoryFloor ~= nil and factoryFloor:IsA("BasePart"), "Factory floor missing")
local transitPosition = factoryFloor.Position + worldLayout.Plot.HubReturnAttendantOffset

for zoneId = 3, 4 do
	local gate = worldService.GetPlotZoneGate(1, zoneId)
	local gateOffset = worldLayout.ExpeditionGateOffsets[zoneId]
	assert(gate ~= nil, ("Expedition gate %d missing"):format(zoneId))
	assert(gateOffset ~= nil, ("Expedition gate offset %d missing"):format(zoneId))
	local expectedPosition = factoryFloor.Position + gateOffset
	assert((gate.Position - expectedPosition).Magnitude < 0.01, "Expedition gate layout mismatch")
	assert(
		(gate.Position - transitPosition).Magnitude <= 22,
		"Expedition gate too far from transit bot"
	)
end
print("EXPEDITION_TRANSIT_CLUSTER_OK", game.PlaceVersion)

local expeditionNodeCount = 0
local cacheCount = 0
for _, node in worldService.GetSalvageNodes() do
	local zone = node:GetAttribute("ZoneId")
	if typeof(zone) == "number" and zone >= 3 then
		expeditionNodeCount += 1
		if node:GetAttribute("ExpeditionCache") == true then
			cacheCount += 1
		end
	end
end
assert(expeditionNodeCount == 24 and cacheCount == 4, "Expedition nodes not registered")
for zoneId = 3, 4 do
	local gate = worldService.GetPlotZoneGate(1, zoneId)
	local arrival = worldService.GetPlotZoneArrival(1, zoneId)
	local returnPortal = worldService.GetPlotZoneReturn(1, zoneId)
	assert(gate ~= nil and gate:GetAttribute("TravelGate") == true, "Travel terminal missing")
	assert(arrival ~= nil and returnPortal ~= nil, "Travel route incomplete")
	assert(returnPortal:FindFirstChildOfClass("ProximityPrompt") ~= nil, "Return prompt missing")
end
print("SALVAGE_EXPEDITIONS_WORLD_OK", expeditionNodeCount, cacheCount)
