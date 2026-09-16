--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Robots = require(ReplicatedStorage.Shared.Config.Robots)

local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local StateService = require(script.Parent.StateService)

local ProductionService = {}
local initialized = false
local lastTickByUser: { [number]: number } = {}
local fractionalCreditsByUser: { [number]: number } = {}

local function parsePadIndex(padId: string): number?
	local match = string.match(padId, "^Pad(%d+)$")
	if match == nil then
		return nil
	end
	return tonumber(match)
end

local function productionRate(data: any): number
	local unlockedSlots = FactoryRules.GetWorkSlots(data.Machines.WorkSlotsLevel)
	local total = 0

	for padId, robotUid in data.Assignments.WorkPads do
		local padIndex = parsePadIndex(padId)
		if padIndex ~= nil and padIndex >= 1 and padIndex <= unlockedSlots then
			local robot = data.Robots.OwnedByUid[robotUid]
			if robot ~= nil then
				local definition = Robots.Definitions[robot.RobotId]
				if definition ~= nil then
					total += definition.ProductionPerSecond
				end
			end
		end
	end

	return total
end

function ProductionService.TickPlayer(player: Player)
	if not DataService.IsReady(player) then
		lastTickByUser[player.UserId] = os.clock()
		return
	end

	local now = os.clock()
	local previous = lastTickByUser[player.UserId] or now
	lastTickByUser[player.UserId] = now
	local elapsed = math.clamp(now - previous, 0, GameConfig.Factory.ProductionTickSeconds * 2)
	if elapsed <= 0 then
		return
	end

	local data = DataService.GetData(player)
	if data == nil then
		return
	end
	if data.Currencies.Credits >= GameConfig.Economy.MaxCredits then
		return
	end

	local rate = productionRate(data)
	if rate <= 0 then
		return
	end

	local rawCredits = rate * elapsed + (fractionalCreditsByUser[player.UserId] or 0)
	local wholeCredits = math.floor(rawCredits)
	fractionalCreditsByUser[player.UserId] = rawCredits - wholeCredits
	if wholeCredits <= 0 then
		return
	end

	local executed, transactionResult = DataService.Transaction(player, function(profileData)
		local granted = EconomyService.GrantCredits(profileData, wholeCredits)
		if granted <= 0 then
			return false, 0
		end
		profileData.Tutorial.Milestones.FirstIncomeEarned = true
		return true, granted
	end)

	if executed and typeof(transactionResult) == "number" and transactionResult > 0 then
		local updatedData = DataService.GetData(player)
		if updatedData ~= nil then
			AnalyticsService.RecordCreditSource(
				player,
				"BotProduction",
				transactionResult,
				updatedData.Currencies.Credits
			)
		end
		StateService.PushSnapshot(player)
	end
end

function ProductionService.Init()
	if initialized then
		return
	end
	initialized = true

	DataService.ProfileLoaded:Connect(function(player)
		lastTickByUser[player.UserId] = os.clock()
		fractionalCreditsByUser[player.UserId] = 0
	end)

	Players.PlayerRemoving:Connect(function(player)
		lastTickByUser[player.UserId] = nil
		fractionalCreditsByUser[player.UserId] = nil
	end)

	for _, player in Players:GetPlayers() do
		lastTickByUser[player.UserId] = os.clock()
		fractionalCreditsByUser[player.UserId] = 0
	end

	task.spawn(function()
		while true do
			task.wait(GameConfig.Factory.ProductionTickSeconds)
			for _, player in Players:GetPlayers() do
				ProductionService.TickPlayer(player)
			end
		end
	end)
end

return ProductionService
