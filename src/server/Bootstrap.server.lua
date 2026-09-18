--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RuntimeMode = require(ReplicatedStorage.Shared.RuntimeMode)

local STUDIO_SELECTOR_REMOTE = "StudioRuntimeSelector"

local function isMode(value: any): boolean
	return value == "Hub" or value == "Factory"
end

local function resolveServerMode(): string
	local override = game:GetAttribute("RuntimeModeOverride")
	if isMode(override) then
		return override :: string
	end

	if not RunService:IsStudio() then
		return RuntimeMode.Resolve()
	end

	game:SetAttribute("RuntimeMode", "Selecting")

	local existing = ReplicatedStorage:FindFirstChild(STUDIO_SELECTOR_REMOTE)
	if existing ~= nil then
		existing:Destroy()
	end

	local selector = Instance.new("RemoteFunction")
	selector.Name = STUDIO_SELECTOR_REMOTE
	selector.Parent = ReplicatedStorage

	local selected: string? = nil
	selector.OnServerInvoke = function(_player, requestedMode)
		if selected ~= nil then
			return selected
		end
		if not isMode(requestedMode) then
			return nil
		end

		selected = requestedMode
		game:SetAttribute("RuntimeMode", requestedMode)
		return requestedMode
	end

	-- Server-only Studio runs have no LocalPlayer to display the selector. Preserve
	-- existing automation by falling back to Factory only when no player appears.
	local playerDeadline = os.clock() + 5
	while selected == nil and #Players:GetPlayers() == 0 and os.clock() < playerDeadline do
		task.wait(0.05)
	end
	if selected == nil and #Players:GetPlayers() == 0 then
		selected = "Factory"
		game:SetAttribute("RuntimeMode", selected)
	else
		while selected == nil do
			task.wait(0.05)
		end
	end

	-- Keep the Studio-only selector function alive for this Play session so
	-- additional local-test clients can receive the already-selected mode.
	return selected :: string
end

local mode = resolveServerMode()
game:SetAttribute("RuntimeMode", mode)

local function startHub()
	local HubFactoryPortalService = require(script.Parent.Services.HubFactoryPortalService)
	local HubSessionService = require(script.Parent.Services.HubSessionService)
	local HubWorldService = require(script.Parent.Services.HubWorldService)

	HubWorldService.Init()
	HubSessionService.Init()
	HubFactoryPortalService.Init()

	print("[ScrapToBotFactory] Hub runtime initialized")
end

local function startFactory()
	local AdminBroadcastService = require(script.Parent.Services.AdminBroadcastService)
	local AnalyticsService = require(script.Parent.Services.AnalyticsService)
	local BadgeService = require(script.Parent.Services.BadgeService)
	local DataService = require(script.Parent.Services.DataService)
	local EntitlementPresentationService =
		require(script.Parent.Services.EntitlementPresentationService)
	local FactoryReadyNotificationService =
		require(script.Parent.Services.FactoryReadyNotificationService)
	local FactoryReturnService = require(script.Parent.Services.FactoryReturnService)
	local FactorySessionService = require(script.Parent.Services.FactorySessionService)
	local MachineService = require(script.Parent.Services.MachineService)
	local MonetizationService = require(script.Parent.Services.MonetizationService)
	local NotificationService = require(script.Parent.Services.NotificationService)
	local PlotPresentationService = require(script.Parent.Services.PlotPresentationService)
	local PlotService = require(script.Parent.Services.PlotService)
	local ProductionService = require(script.Parent.Services.ProductionService)
	local ReferralService = require(script.Parent.Services.ReferralService)
	local RemoteService = require(script.Parent.Services.RemoteService)
	local RobotService = require(script.Parent.Services.RobotService)
	local RobotVisualService = require(script.Parent.Services.RobotVisualService)
	local SalvageService = require(script.Parent.Services.SalvageService)
	local ServerOverclockCoordinator = require(script.Parent.Services.ServerOverclockCoordinator)
	local StateService = require(script.Parent.Services.StateService)
	local StudioSecurityTestService = require(script.Parent.Services.StudioSecurityTestService)
	local StudioTestService = require(script.Parent.Services.StudioTestService)
	local UpgradeService = require(script.Parent.Services.UpgradeService)
	local WorldService = require(script.Parent.Services.WorldService)
	local ZoneService = require(script.Parent.Services.ZoneService)

	FactorySessionService.Init()
	WorldService.Init()
	PlotPresentationService.Init()
	FactoryReturnService.Init()
	RemoteService.Init()
	PlotService.Init()
	StateService.Init()
	SalvageService.Init()
	MachineService.Init()
	RobotService.Init()
	RobotVisualService.Init()
	UpgradeService.Init()
	ProductionService.Init()
	AnalyticsService.Init()
	ZoneService.Init()
	MonetizationService.Init()
	ServerOverclockCoordinator.Init()
	NotificationService.Init()
	AdminBroadcastService.Init()
	FactoryReadyNotificationService.Init()
	EntitlementPresentationService.Init()
	BadgeService.Init()
	ReferralService.Init()
	StudioTestService.Init()
	StudioSecurityTestService.Init()
	DataService.Init()

	print("[ScrapToBotFactory] Instanced factory runtime initialized")
end

if mode == "Hub" then
	startHub()
else
	startFactory()
end
