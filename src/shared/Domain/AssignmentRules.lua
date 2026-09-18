--!strict

export type AssignmentDecision = {
	Allowed: boolean,
	Code: string,
	PadIndex: number?,
	ExistingPadId: string?,
}

local AssignmentRules = {}

function AssignmentRules.ParsePadIndex(padId: string): number?
	local match = string.match(padId, "^Pad(%d+)$")
	if match == nil then
		return nil
	end

	local index = tonumber(match)
	if index == nil or index % 1 ~= 0 or index < 1 then
		return nil
	end
	return index
end

function AssignmentRules.FindAssignedPad(workPads: { [string]: string }, robotUid: string): string?
	for padId, assignedUid in workPads do
		if assignedUid == robotUid then
			return padId
		end
	end
	return nil
end

function AssignmentRules.EvaluateAssignment(
	workPads: { [string]: string },
	ownedByUid: { [string]: any },
	robotUid: string,
	padId: string,
	unlockedSlots: number
): AssignmentDecision
	local padIndex = AssignmentRules.ParsePadIndex(padId)
	if padIndex == nil then
		return {
			Allowed = false,
			Code = "UNKNOWN_WORK_PAD",
			PadIndex = nil,
			ExistingPadId = nil,
		}
	end

	if ownedByUid[robotUid] == nil then
		return {
			Allowed = false,
			Code = "ROBOT_NOT_OWNED",
			PadIndex = padIndex,
			ExistingPadId = nil,
		}
	end

	local slotLimit = math.max(0, math.floor(unlockedSlots))
	if padIndex > slotLimit then
		return {
			Allowed = false,
			Code = "WORK_PAD_LOCKED",
			PadIndex = padIndex,
			ExistingPadId = nil,
		}
	end

	local existingPadId = AssignmentRules.FindAssignedPad(workPads, robotUid)
	if existingPadId ~= nil then
		return {
			Allowed = false,
			Code = "ROBOT_ALREADY_ASSIGNED",
			PadIndex = padIndex,
			ExistingPadId = existingPadId,
		}
	end

	if workPads[padId] ~= nil then
		return {
			Allowed = false,
			Code = "WORK_PAD_OCCUPIED",
			PadIndex = padIndex,
			ExistingPadId = nil,
		}
	end

	return {
		Allowed = true,
		Code = "ROBOT_ASSIGNED",
		PadIndex = padIndex,
		ExistingPadId = nil,
	}
end

function AssignmentRules.NormalizeWorkPads(
	workPads: any,
	ownedByUid: any,
	maxSlots: number
): { [string]: string }
	local normalized: { [string]: string } = {}
	local seenRobots: { [string]: boolean } = {}
	if typeof(workPads) ~= "table" or typeof(ownedByUid) ~= "table" then
		return normalized
	end

	local slotLimit = math.max(0, math.floor(maxSlots))
	for index = 1, slotLimit do
		local padId = ("Pad%d"):format(index)
		local robotUid = workPads[padId]
		if
			typeof(robotUid) == "string"
			and ownedByUid[robotUid] ~= nil
			and seenRobots[robotUid] ~= true
		then
			normalized[padId] = robotUid
			seenRobots[robotUid] = true
		end
	end

	return normalized
end

return table.freeze(AssignmentRules)
