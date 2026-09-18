--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StudioRuntimeSelectorController =
	require(script.Parent.Controllers.StudioRuntimeSelectorController)

local mode = StudioRuntimeSelectorController.ResolveMode()

local function startHubClient()
	local HubUIController = require(script.Parent.Controllers.HubUIController)

	HubUIController.Init()
	print("[ScrapToBotFactory] Hub client initialized")
end

local function waitForFactoryRole(): string
	local player = Players.LocalPlayer
	local role = player:GetAttribute("FactoryRole")
	if role == "Owner" or role == "Visitor" then
		return role
	end

	local deadline = os.clock() + 10
	while os.clock() < deadline do
		role = player:GetAttribute("FactoryRole")
		if role == "Owner" or role == "Visitor" then
			return role
		end
		task.wait(0.05)
	end

	return "Visitor"
end

local function startFactoryClient()
	local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
	local MachineEffectsController = require(script.Parent.Controllers.MachineEffectsController)
	local RobotWorkerController = require(script.Parent.Controllers.RobotWorkerController)
	local WorldLabelController = require(script.Parent.Controllers.WorldLabelController)

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	for _, remoteName in
		{
			RemoteNames.StateSnapshot,
			RemoteNames.ActionResult,
			RemoteNames.Announcement,
		}
	do
		assert(
			remotes:WaitForChild(remoteName):IsA("RemoteEvent"),
			("Expected RemoteEvent %s"):format(remoteName)
		)
	end

	MachineEffectsController.Init()
	RobotWorkerController.Init()
	WorldLabelController.Init()

	local role = waitForFactoryRole()
	if role ~= "Owner" then
		print("[ScrapToBotFactory] Factory visitor client initialized")
		return
	end

	local AnnouncementController = require(script.Parent.Controllers.AnnouncementController)
	local CreatorAdminController = require(script.Parent.Controllers.CreatorAdminController)
	local FactoryClubCosmeticController =
		require(script.Parent.Controllers.FactoryClubCosmeticController)
	local InstantProcessController = require(script.Parent.Controllers.InstantProcessController)
	local MonetizationShopController = require(script.Parent.Controllers.MonetizationShopController)
	local NotificationOptInController =
		require(script.Parent.Controllers.NotificationOptInController)
	local StudioToolsController = require(script.Parent.Controllers.StudioToolsController)
	local UIController = require(script.Parent.Controllers.UIController)
	local WorldInteractionController = require(script.Parent.Controllers.WorldInteractionController)
	local ZonePresentationController = require(script.Parent.Controllers.ZonePresentationController)

	WorldInteractionController.Init()
	ZonePresentationController.Init()
	UIController.Init()
	AnnouncementController.Init()
	FactoryClubCosmeticController.Init()
	InstantProcessController.Init()
	MonetizationShopController.Init()
	NotificationOptInController.Init()
	CreatorAdminController.Init()
	StudioToolsController.Init()

	print("[ScrapToBotFactory] Factory owner client initialized")
end

if mode == "Hub" then
	startHubClient()
else
	startFactoryClient()
end
