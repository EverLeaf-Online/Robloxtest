--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local Validation = require(ReplicatedStorage.Shared.Util.Validation)

local AnalyticsService = require(script.Parent.AnalyticsService)
local DataService = require(script.Parent.DataService)
local EconomyService = require(script.Parent.EconomyService)
local PlotService = require(script.Parent.PlotService)
local RemoteService = require(script.Parent.RemoteService)
local StateService = require(script.Parent.StateService)
local PlayerCharacter = require(script.Parent.Parent.Util.PlayerCharacter)

local UpgradeService = {}
local initialized = false

local machineFields = table.freeze({
	ProcessorSpeed = "ProcessorLevel",
	AssemblerSpeed = "AssemblerLevel",
	Storage = "StorageLevel",
	WorkSlots = "WorkSlotsLevel",
})

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

function UpgradeService.Purchase(player: Player, upgradeId: any)
	if not Validation.isBoundedString(upgradeId, GameConfig.Networking.MaxStringLength) then
		StateService.ActionResult(
			player,
			RemoteNames.RequestUpgrade,
			false,
			"INVALID_UPGRADE_ID",
			nil
		)
		return
	end

	local definition = Upgrades[upgradeId]
	local machineField = machineFields[upgradeId]
	if definition == nil or machineField == nil then
		StateService.ActionResult(player, RemoteNames.RequestUpgrade, false, "UNKNOWN_UPGRADE", nil)
		return
	end

	local console = PlotService.GetUpgradeConsole(player)
	local storageStation = if upgradeId == "Storage"
		then PlotService.GetStorageStation(player)
		else nil
	if console == nil then
		StateService.ActionResult(player, RemoteNames.RequestUpgrade, false, "NO_FACTORY_PLOT", nil)
		return
	end
	local nearAllowedStation = isNear(player, console)
		or (storageStation ~= nil and isNear(player, storageStation))
	if not nearAllowedStation then
		StateService.ActionResult(player, RemoteNames.RequestUpgrade, false, "TOO_FAR_AWAY", nil)
		return
	end

	local executed, transactionResult = DataService.Transaction(player, function(data)
		local currentLevel = data.Machines[machineField]
		local nextUpgrade = FactoryRules.GetNextUpgrade(upgradeId, currentLevel)
		if nextUpgrade == nil then
			return false, result(false, "MAX_LEVEL", { Level = currentLevel })
		end
		if not EconomyService.SpendCredits(data, nextUpgrade.CostCredits) then
			return false,
				result(false, "NOT_ENOUGH_CREDITS", {
					CostCredits = nextUpgrade.CostCredits,
				})
		end

		data.Machines[machineField] = currentLevel + 1
		data.Tutorial.Milestones.FirstUpgrade = true
		return true,
			result(true, "UPGRADE_PURCHASED", {
				UpgradeId = upgradeId,
				Level = currentLevel + 1,
				Value = nextUpgrade.Value,
				CostCredits = nextUpgrade.CostCredits,
			})
	end)

	if not executed then
		StateService.ActionResult(
			player,
			RemoteNames.RequestUpgrade,
			false,
			tostring(transactionResult),
			nil
		)
		return
	end
	if typeof(transactionResult) ~= "table" then
		StateService.ActionResult(
			player,
			RemoteNames.RequestUpgrade,
			false,
			"INVALID_TRANSACTION_RESULT",
			nil
		)
		return
	end

	StateService.ActionResult(
		player,
		RemoteNames.RequestUpgrade,
		transactionResult.Success == true,
		tostring(transactionResult.Code),
		transactionResult.Payload
	)
	if transactionResult.Success == true then
		local payload = transactionResult.Payload
		local updatedData = DataService.GetData(player)
		if
			typeof(payload) == "table"
			and typeof(payload.CostCredits) == "number"
			and updatedData ~= nil
		then
			AnalyticsService.RecordCreditSink(
				player,
				("Upgrade:%s"):format(upgradeId),
				payload.CostCredits,
				updatedData.Currencies.Credits
			)
		end
		StateService.PushSnapshot(player)
	end
end

function UpgradeService.Init()
	if initialized then
		return
	end
	initialized = true

	RemoteService.BindRequest(RemoteNames.RequestUpgrade, function(player, upgradeId)
		UpgradeService.Purchase(player, upgradeId)
	end)
end

return UpgradeService
