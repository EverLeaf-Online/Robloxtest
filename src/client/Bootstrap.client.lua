--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local InstantProcessController = require(script.Parent.Controllers.InstantProcessController)
local PlotController = require(script.Parent.Controllers.PlotController)
local UIController = require(script.Parent.Controllers.UIController)
local WorldInteractionController = require(script.Parent.Controllers.WorldInteractionController)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

for _, remoteName in
	{
		RemoteNames.StateSnapshot,
		RemoteNames.ActionResult,
	}
do
	assert(
		Remotes:WaitForChild(remoteName):IsA("RemoteEvent"),
		("Expected RemoteEvent %s"):format(remoteName)
	)
end

PlotController.Init()
WorldInteractionController.Init()
UIController.Init()
InstantProcessController.Init()

print("[ScrapToBotFactory] Client foundation initialized")
