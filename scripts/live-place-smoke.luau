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
