--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local AnnouncementController = require(script.Parent.Controllers.AnnouncementController)
local CreatorAdminController = require(script.Parent.Controllers.CreatorAdminController)
local FactoryClubCosmeticController =
	require(script.Parent.Controllers.FactoryClubCosmeticController)
local InstantProcessController = require(script.Parent.Controllers.InstantProcessController)
local MonetizationShopController = require(script.Parent.Controllers.MonetizationShopController)
local NotificationOptInController = require(script.Parent.Controllers.NotificationOptInController)
local PlotController = require(script.Parent.Controllers.PlotController)
local StudioMonetizationTestController =
	require(script.Parent.Controllers.StudioMonetizationTestController)
local UIController = require(script.Parent.Controllers.UIController)
local WorldInteractionController = require(script.Parent.Controllers.WorldInteractionController)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

for _, remoteName in
	{
		RemoteNames.StateSnapshot,
		RemoteNames.ActionResult,
		RemoteNames.Announcement,
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
AnnouncementController.Init()
FactoryClubCosmeticController.Init()
InstantProcessController.Init()
MonetizationShopController.Init()
NotificationOptInController.Init()
CreatorAdminController.Init()
StudioMonetizationTestController.Init()

print("[ScrapToBotFactory] Client foundation initialized")
