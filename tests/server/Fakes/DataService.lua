--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local TransactionRules = require(ReplicatedStorage.Shared.Domain.TransactionRules)

local DataService = {}

local dataByPlayer: { [Player]: any } = {}
local busyByPlayer: { [Player]: boolean } = {}

local profileLoadedEvent = Instance.new("BindableEvent")
DataService.ProfileLoaded = profileLoadedEvent.Event

function DataService.Reset()
	table.clear(dataByPlayer)
	table.clear(busyByPlayer)
end

function DataService.SetData(player: Player, data: any)
	dataByPlayer[player] = data
end

function DataService.SetBusy(player: Player, busy: boolean)
	busyByPlayer[player] = if busy then true else nil
end

function DataService.GetData(player: Player): any?
	return dataByPlayer[player]
end

function DataService.IsReady(player: Player): boolean
	return dataByPlayer[player] ~= nil
end

function DataService.Transaction(
	player: Player,
	transaction: (any) -> (boolean, any?)
): (boolean, any?)
	local data = dataByPlayer[player]
	if data == nil then
		return false, "PROFILE_NOT_READY"
	end
	if busyByPlayer[player] then
		return false, "TRANSACTION_BUSY"
	end

	busyByPlayer[player] = true
	local callOk, executed, result = pcall(
		TransactionRules.Execute,
		data,
		transaction,
		function(draft)
			draft.Revision += 1
		end
	)
	busyByPlayer[player] = nil

	if not callOk or executed ~= true then
		return false, if callOk then result else "TRANSACTION_FAILED"
	end
	return true, result
end

return DataService
