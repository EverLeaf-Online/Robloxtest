--!strict

local RemoteNames = table.freeze({
	RequestState = "RequestState",
	RequestCollect = "RequestCollect",
	RequestProcess = "RequestProcess",
	RequestAssemble = "RequestAssemble",
	RequestAssignRobot = "RequestAssignRobot",
	RequestUnassignRobot = "RequestUnassignRobot",
	RequestSellRobot = "RequestSellRobot",
	RequestUpgrade = "RequestUpgrade",
	RequestUnlockZone = "RequestUnlockZone",
	RequestPrestige = "RequestPrestige",

	StateSnapshot = "StateSnapshot",
	StateDelta = "StateDelta",
	ActionResult = "ActionResult",
})

return RemoteNames
