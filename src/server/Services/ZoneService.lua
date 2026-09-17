--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local ProgressionRules = require(ReplicatedStorage.Shared.Domain.ProgressionRules)
local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local Validation = require(ReplicatedStorage.Shared.Util.Validation)

local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local RateLimiter = require(script.Parent.RateLimiter)
local RemoteService = require(script.Parent.RemoteService)
local StateService = require(script.Parent.StateService)
local WorldService = require(script.Parent.WorldService)
local PlayerCharacter = require(script.Parent.Parent.Util.PlayerCharacter)
local ProfileTypes = require(script.Parent.Parent.Data.ProfileTypes)

type ProfileData = ProfileTypes.ProfileData

local ZoneService = {}
local initialized = false

local function result(success: boolean, code: string, payload: any?): any
	return {
		Success = success,
		Code = code,
		Payload = payload,
	}
end

local function isNear(player: Player, part: BasePart): boolean
	return PlayerCharacter.IsNear(player, part, GameConfig.World.InteractionDistance)
end

local function teleportToZone(player: Player, zoneId: number): boolean
	local arrival = WorldService.GetZoneArrival(zoneId)
	local character = player.Character
	if arrival == nil or character == nil then
		return false
	end

	character:PivotTo(CFrame.new(arrival.Position + Vector3.new(0, 4, 0)))
	return true
end

local function requirementPayload(definition: any, data: ProfileData): any
	return {
		TargetZone = definition.Id,
		DisplayName = definition.DisplayName,
		CostCredits = definition.UnlockCredits,
		RequiredLifetimeRobots = definition.RequiredLifetimeRobots,
		CurrentCredits = data.Currencies.Credits,
		LifetimeRobotsBuilt = data.Stats.LifetimeRobotsBuilt,
	}
end

local function sendTransactionResult(player: Player, executed: boolean, transactionResult: any?)
	if not executed then
		StateService.ActionResult(
			player,
			RemoteNames.RequestUnlockZone,
			false,
			tostring(transactionResult),
			nil
		)
		return
	end
	if typeof(transactionResult) ~= "table" then
		StateService.ActionResult(
			player,
			RemoteNames.RequestUnlockZone,
			false,
			"INVALID_TRANSACTION_RESULT",
			nil
		)
		return
	end

	StateService.ActionResult(
		player,
		RemoteNames.RequestUnlockZone,
		transactionResult.Success == true,
		tostring(transactionResult.Code),
		transactionResult.Payload
	)
	StateService.PushSnapshot(player)
end

function ZoneService.UseGate(player: Player, targetZone: any)
	if not Validation.isSafeInteger(targetZone, 2, 100) then
		StateService.ActionResult(
			player,
			RemoteNames.RequestUnlockZone,
			false,
			"INVALID_ZONE_ID",
			nil
		)
		return
	end
	local authoritativeTarget = targetZone :: number
	local gate = WorldService.GetZoneGate(authoritativeTarget)
	if gate == nil then
		StateService.ActionResult(player, RemoteNames.RequestUnlockZone, false, "UNKNOWN_ZONE", nil)
		return
	end
	if not isNear(player, gate) then
		StateService.ActionResult(player, RemoteNames.RequestUnlockZone, false, "TOO_FAR_AWAY", nil)
		return
	end

	local currentData = DataService.GetData(player)
	if currentData == nil then
		return
	end
	if currentData.Progression.Zone >= authoritativeTarget then
		if teleportToZone(player, authoritativeTarget) then
			StateService.ActionResult(
				player,
				RemoteNames.RequestUnlockZone,
				true,
				"ZONE_TRAVELLED",
				{ TargetZone = authoritativeTarget }
			)
		end
		return
	end

	local executed, transactionResult = DataService.Transaction(player, function(data)
		local canUnlock, code, definition = ProgressionRules.EvaluateZoneUnlock(
			data.Progression.Zone,
			authoritativeTarget,
			data.Currencies.Credits,
			data.Stats.LifetimeRobotsBuilt
		)
		if definition == nil then
			return false, result(false, code, nil)
		end

		local firstGoalInteraction = data.Tutorial.Milestones.FirstZoneGoalSeen ~= true
		if firstGoalInteraction then
			data.Tutorial.Milestones.FirstZoneGoalSeen = true
		end

		if not canUnlock then
			return firstGoalInteraction, result(false, code, requirementPayload(definition, data))
		end

		if not EconomyService.SpendCredits(data, definition.UnlockCredits) then
			return firstGoalInteraction,
				result(false, "NOT_ENOUGH_CREDITS", requirementPayload(definition, data))
		end

		data.Progression.Zone = authoritativeTarget
		data.Tutorial.Milestones.FirstZoneUnlock = true
		return true,
			result(true, "ZONE_UNLOCKED", {
				TargetZone = authoritativeTarget,
				DisplayName = definition.DisplayName,
				CostCredits = definition.UnlockCredits,
			})
	end)

	if executed and typeof(transactionResult) == "table" and transactionResult.Success == true then
		local payload = transactionResult.Payload
		local updatedData = DataService.GetData(player)
		if
			typeof(payload) == "table"
			and typeof(payload.CostCredits) == "number"
			and updatedData ~= nil
		then
			AnalyticsService.RecordCreditSink(
				player,
				("ZoneUnlock:%d"):format(authoritativeTarget),
				payload.CostCredits,
				updatedData.Currencies.Credits
			)
		end
	end

	sendTransactionResult(player, executed, transactionResult)
	if executed and typeof(transactionResult) == "table" and transactionResult.Success == true then
		teleportToZone(player, authoritativeTarget)
	end
end

function ZoneService.ReturnToStarter(player: Player, currentZone: number)
	local portal = WorldService.GetZoneReturnPortals()[currentZone]
	if portal == nil or not isNear(player, portal) then
		return
	end
	teleportToZone(player, 1)
end

function ZoneService.Init()
	if initialized then
		return
	end
	initialized = true

	for targetZone, gate in WorldService.GetZoneGates() do
		local prompt = gate:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				if RateLimiter.Consume(player, RemoteNames.RequestUnlockZone) then
					ZoneService.UseGate(player, targetZone)
				end
			end)
		end
	end

	for currentZone, portal in WorldService.GetZoneReturnPortals() do
		local prompt = portal:FindFirstChildOfClass("ProximityPrompt")
		if prompt then
			prompt.Triggered:Connect(function(player)
				if RateLimiter.Consume(player, RemoteNames.RequestUnlockZone) then
					ZoneService.ReturnToStarter(player, currentZone)
				end
			end)
		end
	end

	RemoteService.BindRequest(RemoteNames.RequestUnlockZone, function(player, targetZone)
		ZoneService.UseGate(player, targetZone)
	end)
end

return ZoneService
