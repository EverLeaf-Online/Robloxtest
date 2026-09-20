--!strict

local REQUESTS = table.freeze({
	"RequestState",
	"RequestCollect",
	"RequestProcess",
	"RequestAssemble",
	"RequestAssignRobot",
	"RequestUnassignRobot",
	"RequestSellRobot",
	"RequestUpgrade",
	"RequestUnlockZone",
	"RequestPrestige",
	"RequestUseInstantProcessToken",
	"RequestEquipClubCosmetic",
	"RequestAdminBroadcast",
})

local OUTBOUND = table.freeze({
	"StateSnapshot",
	"StateDelta",
	"ActionResult",
	"Announcement",
})

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

	Requests = REQUESTS,
	Outbound = OUTBOUND,
})

return RemoteNames
