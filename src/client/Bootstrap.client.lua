--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local PlotController = require(script.Parent.Controllers.PlotController)
local UIController = require(script.Parent.Controllers.UIController)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

for _, remoteName in
	{
		RemoteNames.StateSnapshot,
		RemoteNames.StateDelta,
		RemoteNames.ActionResult,
	}
do
	assert(
		Remotes:WaitForChild(remoteName):IsA("RemoteEvent"),
		("Expected RemoteEvent %s"):format(remoteName)
	)
end

PlotController.Init()
UIController.Init()

print("[ScrapToBotFactory] Client foundation initialized")
