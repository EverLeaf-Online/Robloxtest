--!strict

local EngineAnalyticsService = game:GetService("AnalyticsService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local DataService = require(script.Parent.DataService)

local AnalyticsService = {}
local initialized = false

local MOVEMENT_DISTANCE = 2
local POLL_SECONDS = 0.25
local ECONOMY_FLUSH_SECONDS = 30
local CREDIT_CURRENCY = "Credits"
local GAMEPLAY_TRANSACTION = "Gameplay"

local milestoneSteps = table.freeze({
	{ Key = "FirstScrap", Step = 3, Name = "FirstScrap" },
	{ Key = "FirstProcess", Step = 4, Name = "FirstProcess" },
	{ Key = "FirstBotReveal", Step = 5, Name = "FirstBotReveal" },
	{ Key = "FirstBotAssigned", Step = 6, Name = "FirstBotAssigned" },
	{ Key = "FirstIncomeEarned", Step = 7, Name = "FirstIncomeEarned" },
	{ Key = "FirstUpgrade", Step = 8, Name = "FirstUpgrade" },
	{ Key = "FirstZoneGoalSeen", Step = 9, Name = "FirstZoneGoalSeen" },
	{ Key = "FirstZoneUnlock", Step = 10, Name = "FirstZoneUnlock" },
})

type SessionState = {
	Emitted: { [string]: boolean },
	MovementOrigin: Vector3?,
}

type PendingEconomySource = {
	Amount: number,
	EndingBalance: number,
}

local sessions: { [Player]: SessionState } = {}
local pendingCreditSources: { [Player]: { [string]: PendingEconomySource } } = {}

local function isFiniteNonNegative(value: number): boolean
	return value == value and value ~= math.huge and value ~= -math.huge and value >= 0
end

local function logOnboardingStep(player: Player, step: number, stepName: string)
	if RunService:IsStudio() then
		return
	end

	local ok, err = pcall(function()
		EngineAnalyticsService:LogOnboardingFunnelStepEvent(player, step, stepName, {})
	end)
	if not ok then
		warn(
			("[AnalyticsService] Failed onboarding event %s for %d: %s"):format(
				stepName,
				player.UserId,
				tostring(err)
			)
		)
	end
end

local function logCreditEconomyEvent(
	player: Player,
	flowType: Enum.AnalyticsEconomyFlowType,
	amount: number,
	endingBalance: number,
	itemSku: string
)
	if RunService:IsStudio() or amount <= 0 then
		return
	end
	if not isFiniteNonNegative(amount) or not isFiniteNonNegative(endingBalance) then
		return
	end

	local ok, err = pcall(function()
		EngineAnalyticsService:LogEconomyEvent(
			player,
			flowType,
			CREDIT_CURRENCY,
			amount,
			endingBalance,
			GAMEPLAY_TRANSACTION,
			itemSku,
			{}
		)
	end)
	if not ok then
		warn(
			("[AnalyticsService] Failed economy event %s for %d: %s"):format(
				itemSku,
				player.UserId,
				tostring(err)
			)
		)
	end
end

local function flushCreditSources(player: Player)
	local bySku = pendingCreditSources[player]
	if bySku == nil then
		return
	end
	pendingCreditSources[player] = nil

	for itemSku, pending in bySku do
		logCreditEconomyEvent(
			player,
			Enum.AnalyticsEconomyFlowType.Source,
			pending.Amount,
			pending.EndingBalance,
			itemSku
		)
	end
end

local function rootPosition(player: Player): Vector3?
	local character = player.Character
	if character == nil then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end
	return root.Position
end

local function beginSession(player: Player)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end

	local emitted: { [string]: boolean } = {}
	for _, definition in milestoneSteps do
		emitted[definition.Key] = data.Tutorial.Milestones[definition.Key] == true
	end

	local alreadyCollected = emitted.FirstScrap == true
	local state: SessionState = {
		Emitted = emitted,
		MovementOrigin = rootPosition(player),
	}
	state.Emitted.JoinedGame = alreadyCollected
	state.Emitted.FirstMovement = alreadyCollected
	sessions[player] = state

	if not alreadyCollected then
		state.Emitted.JoinedGame = true
		logOnboardingStep(player, 1, "JoinedGame")
	end
end

local function checkMovement(player: Player, state: SessionState)
	if state.Emitted.FirstMovement then
		return
	end

	local position = rootPosition(player)
	if position == nil then
		return
	end
	if state.MovementOrigin == nil then
		state.MovementOrigin = position
		return
	end

	if (position - state.MovementOrigin).Magnitude >= MOVEMENT_DISTANCE then
		state.Emitted.FirstMovement = true
		logOnboardingStep(player, 2, "FirstMovement")
	end
end

local function checkMilestones(player: Player, state: SessionState)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end

	for _, definition in milestoneSteps do
		if
			not state.Emitted[definition.Key]
			and data.Tutorial.Milestones[definition.Key] == true
		then
			state.Emitted[definition.Key] = true
			logOnboardingStep(player, definition.Step, definition.Name)
		end
	end
end

function AnalyticsService.RecordCreditSource(
	player: Player,
	itemSku: string,
	amount: number,
	endingBalance: number
)
	if amount <= 0 or not isFiniteNonNegative(amount) or not isFiniteNonNegative(endingBalance) then
		return
	end

	local bySku = pendingCreditSources[player]
	if bySku == nil then
		bySku = {}
		pendingCreditSources[player] = bySku
	end

	local pending = bySku[itemSku]
	if pending == nil then
		bySku[itemSku] = {
			Amount = amount,
			EndingBalance = endingBalance,
		}
		return
	end

	pending.Amount += amount
	pending.EndingBalance = endingBalance
end

function AnalyticsService.RecordCreditSink(
	player: Player,
	itemSku: string,
	amount: number,
	endingBalance: number
)
	logCreditEconomyEvent(
		player,
		Enum.AnalyticsEconomyFlowType.Sink,
		amount,
		endingBalance,
		itemSku
	)
end

function AnalyticsService.Init()
	if initialized then
		return
	end
	initialized = true

	DataService.ProfileLoaded:Connect(function(player)
		beginSession(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		flushCreditSources(player)
		sessions[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		if DataService.IsReady(player) then
			beginSession(player)
		end
	end

	task.spawn(function()
		while true do
			task.wait(POLL_SECONDS)
			for player, state in sessions do
				if player.Parent == Players then
					checkMovement(player, state)
					checkMilestones(player, state)
				else
					sessions[player] = nil
				end
			end
		end
	end)

	task.spawn(function()
		while true do
			task.wait(ECONOMY_FLUSH_SECONDS)
			for player in pendingCreditSources do
				flushCreditSources(player)
			end
		end
	end)
end

return AnalyticsService
