--!strict

local RobotInventoryRules = {}

local MAX_UID_NUMBER = 2_147_483_647

local function normalizeStart(value: any): number
	if
		typeof(value) == "number"
		and value == value
		and value > -math.huge
		and value < math.huge
		and value % 1 == 0
		and value >= 1
		and value <= MAX_UID_NUMBER
	then
		return value
	end
	return 1
end

function RobotInventoryRules.FormatUid(uidNumber: number): string
	assert(
		uidNumber % 1 == 0 and uidNumber >= 1 and uidNumber <= MAX_UID_NUMBER,
		"invalid robot uid number"
	)
	return ("R%d"):format(uidNumber)
end

function RobotInventoryRules.AdvanceUidNumber(uidNumber: number): number
	if uidNumber >= MAX_UID_NUMBER then
		return 1
	end
	return uidNumber + 1
end

function RobotInventoryRules.FindAvailableUidNumber(
	ownedByUid: any,
	requestedNext: any,
	maxOwnedRobots: number
): number?
	if typeof(ownedByUid) ~= "table" then
		return nil
	end

	local attempts = math.max(1, math.floor(maxOwnedRobots) + 1)
	local candidate = normalizeStart(requestedNext)
	for _ = 1, attempts do
		local uid = RobotInventoryRules.FormatUid(candidate)
		if ownedByUid[uid] == nil then
			return candidate
		end
		candidate = RobotInventoryRules.AdvanceUidNumber(candidate)
	end

	return nil
end

return table.freeze(RobotInventoryRules)
