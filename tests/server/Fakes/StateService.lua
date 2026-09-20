--!strict

local StateService = {}

local lastResultByPlayer: { [Player]: any } = {}
local snapshotPushCountByPlayer: { [Player]: number } = {}
local productionDeltaCountByPlayer: { [Player]: number } = {}

function StateService.Reset()
	table.clear(lastResultByPlayer)
	table.clear(snapshotPushCountByPlayer)
	table.clear(productionDeltaCountByPlayer)
end

function StateService.ActionResult(
	player: Player,
	actionName: string,
	success: boolean,
	code: string,
	payload: any?
)
	lastResultByPlayer[player] = {
		Action = actionName,
		Success = success,
		Code = code,
		Payload = payload,
	}
end

function StateService.PushSnapshot(player: Player)
	snapshotPushCountByPlayer[player] = (snapshotPushCountByPlayer[player] or 0) + 1
end

function StateService.PushProductionDelta(player: Player)
	productionDeltaCountByPlayer[player] = (productionDeltaCountByPlayer[player] or 0) + 1
end

function StateService.GetLastResult(player: Player): any?
	return lastResultByPlayer[player]
end

function StateService.GetSnapshotPushCount(player: Player): number
	return snapshotPushCountByPlayer[player] or 0
end

function StateService.GetProductionDeltaCount(player: Player): number
	return productionDeltaCountByPlayer[player] or 0
end

return StateService
