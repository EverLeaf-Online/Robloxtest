print("OCALE_PROBE_OK")
print("PLACE_ID", game.PlaceId)
print("RUNTIME_OVERRIDE", tostring(game:GetAttribute("RuntimeModeOverride")))
print("RUNTIME_MODE", tostring(game:GetAttribute("RuntimeMode")))

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local packages = ReplicatedStorage:FindFirstChild("Packages")
print("PACKAGES", packages ~= nil, packages and packages.ClassName or "nil")
if packages ~= nil then
	print("PACKAGE_REACT", packages:FindFirstChild("React") ~= nil)
	print("PACKAGE_REACT_ROBLOX", packages:FindFirstChild("ReactRoblox") ~= nil)
end

local starterPlayer = game:GetService("StarterPlayer")
local scripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
local client = if scripts ~= nil then scripts:FindFirstChild("Client") else nil
print("CLIENT_CONTAINER", client ~= nil, client and client.ClassName or "nil")
if client ~= nil then
	local bootstrap = client:FindFirstChild("Bootstrap")
	local controllers = client:FindFirstChild("Controllers")
	print("CLIENT_BOOTSTRAP", bootstrap ~= nil, bootstrap and bootstrap.ClassName or "nil")
	print("UI_CONTROLLER", controllers ~= nil and controllers:FindFirstChild("UIController") ~= nil)
	print("HUB_UI_CONTROLLER", controllers ~= nil and controllers:FindFirstChild("HubUIController") ~= nil)
	if bootstrap ~= nil and bootstrap:IsA("LocalScript") then
		local ok, source = pcall(function()
			return bootstrap.Source
		end)
		print("BOOTSTRAP_SOURCE_READABLE", ok)
		if ok then
			print("BOOTSTRAP_HAS_FACTORY_ROLE", string.find(source, "FactoryRole", 1, true) ~= nil)
			print("BOOTSTRAP_HAS_HUB_UI", string.find(source, "HubUIController", 1, true) ~= nil)
		end
	end
end
