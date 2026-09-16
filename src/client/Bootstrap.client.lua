--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local UIController = require(script.Parent.Controllers.UIController)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

for _, remoteName in {
	RemoteNames.StateSnapshot,
	RemoteNames.StateDelta,
	RemoteNames.ActionResult,
} do
	assert(Remotes:WaitForChild(remoteName):IsA("RemoteEvent"), ("Expected RemoteEvent %s"):format(remoteName))
end

UIController.Init()

print("[ScrapToBotFactory] Client foundation initialized")
