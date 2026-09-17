--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local FactoryClubCosmeticController = require(script.Parent.Controllers.FactoryClubCosmeticController)
local InstantProcessController = require(script.Parent.Controllers.InstantProcessController)
local NotificationOptInController = require(script.Parent.Controllers.NotificationOptInController)
local PlotController = require(script.Parent.Controllers.PlotController)
local StudioMonetizationTestController = require(script.Parent.Controllers.StudioMonetizationTestController)
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
FactoryClubCosmeticController.Init()
InstantProcessController.Init()
NotificationOptInController.Init()
StudioMonetizationTestController.Init()

print("[ScrapToBotFactory] Client foundation initialized")
