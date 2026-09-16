--!strict

local AnalyticsService = require(script.Parent.Services.AnalyticsService)
local DataService = require(script.Parent.Services.DataService)
local MachineService = require(script.Parent.Services.MachineService)
local ProductionService = require(script.Parent.Services.ProductionService)
local RemoteService = require(script.Parent.Services.RemoteService)
local RobotService = require(script.Parent.Services.RobotService)
local SalvageService = require(script.Parent.Services.SalvageService)
local StateService = require(script.Parent.Services.StateService)
local UpgradeService = require(script.Parent.Services.UpgradeService)
local WorldService = require(script.Parent.Services.WorldService)

local function start()
	WorldService.Init()
	RemoteService.Init()
	StateService.Init()
	SalvageService.Init()
	MachineService.Init()
	RobotService.Init()
	UpgradeService.Init()
	ProductionService.Init()
	AnalyticsService.Init()
	DataService.Init()
	print("[ScrapToBotFactory] Graybox gameplay services initialized")
end

start()
