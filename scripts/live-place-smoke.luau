print("LIVE_PLACE_SMOKE_OK")
print("PLACE_ID", game.PlaceId)

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPlayer = game:GetService("StarterPlayer")

local packages = ReplicatedStorage:FindFirstChild("Packages")
print("PACKAGES", packages ~= nil, packages and packages.ClassName or "nil")
if packages ~= nil then
	print("REACT", packages:FindFirstChild("React") ~= nil)
	print("REACT_ROBLOX", packages:FindFirstChild("ReactRoblox") ~= nil)
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
	print("CONTROLLERS", controllers ~= nil)
	print("UI_FOLDER", ui ~= nil)
	if controllers ~= nil then
		print("UI_CONTROLLER", controllers:FindFirstChild("UIController") ~= nil)
		print("HUB_UI_CONTROLLER", controllers:FindFirstChild("HubUIController") ~= nil)
		print("GAMEPAD_CONTROLLER", controllers:FindFirstChild("GamepadNavigationController") ~= nil)
	end
end

local serverScripts = game:GetService("ServerScriptService")
local server = serverScripts:FindFirstChild("Server")
print("SERVER_CONTAINER", server ~= nil)
if server ~= nil then
	local bootstrap = server:FindFirstChild("Bootstrap")
	print("SERVER_BOOTSTRAP", bootstrap ~= nil, bootstrap and bootstrap.ClassName or "nil")
end
