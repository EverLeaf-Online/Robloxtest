-- ServerScriptService/RemoteSetup.server.lua
-- Creates all RemoteEvents and RemoteFunctions used by the game.

local ReplicatedFirst = game:GetService("ReplicatedFirst")

local remotes = ReplicatedFirst:FindFirstChild("Remotes")
if not remotes then
	remotes = Instance.new("Folder")
	remotes.Name = "Remotes"
	remotes.Parent = ReplicatedFirst
end

local function create(className, name)
	local obj = remotes:FindFirstChild(name)
	if not obj then
		obj = Instance.new(className)
		obj.Name = name
		obj.Parent = remotes
	end
	return obj
end

-- Client -> Server
create("RemoteEvent", "ApplyAction")

-- Server -> Client
create("RemoteEvent", "UpdateEnergy")
create("RemoteEvent", "UpdateTile")
create("RemoteEvent", "MilestoneReached")
create("RemoteEvent", "PurchaseConfirmed")
create("RemoteEvent", "Notify")
create("RemoteEvent", "UpdateStats")

-- Client -> Server request/response
create("RemoteFunction", "GetPlanetState")

print("[Grow a Tiny Planet] Remotes created in ReplicatedFirst/Remotes")
