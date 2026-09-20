print("OCALE_PROBE_OK")
print("PLACE_ID", game.PlaceId)
print("RUNTIME_OVERRIDE", tostring(game:GetAttribute("RuntimeModeOverride")))
print("RUNTIME_MODE", tostring(game:GetAttribute("RuntimeMode")))

local starterPlayer = game:GetService("StarterPlayer")
local scripts = starterPlayer:FindFirstChild("StarterPlayerScripts")
local client = if scripts ~= nil then scripts:FindFirstChild("Client") else nil
print("CLIENT_CONTAINER", client ~= nil, client and client.ClassName or "nil")
if client ~= nil then
	local bootstrap = client:FindFirstChild("Bootstrap")
	print("CLIENT_BOOTSTRAP", bootstrap ~= nil, bootstrap and bootstrap.ClassName or "nil")
end
