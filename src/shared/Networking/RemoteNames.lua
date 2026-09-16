--!strict

local RemoteNames = table.freeze({
	RequestCollect = "RequestCollect",
	RequestProcess = "RequestProcess",
	RequestAssemble = "RequestAssemble",
	RequestAssignRobot = "RequestAssignRobot",
	RequestSellRobot = "RequestSellRobot",
	RequestUpgrade = "RequestUpgrade",
	RequestUnlockZone = "RequestUnlockZone",
	RequestPrestige = "RequestPrestige",

	StateSnapshot = "StateSnapshot",
	StateDelta = "StateDelta",
	ActionResult = "ActionResult",
})

return RemoteNames
