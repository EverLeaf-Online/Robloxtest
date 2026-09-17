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
	RequestUseInstantProcessToken = "RequestUseInstantProcessToken",
	RequestEquipClubCosmetic = "RequestEquipClubCosmetic",
	RequestAdminBroadcast = "RequestAdminBroadcast",

	StateSnapshot = "StateSnapshot",
	StateDelta = "StateDelta",
	ActionResult = "ActionResult",
	Announcement = "Announcement",
})

return RemoteNames
