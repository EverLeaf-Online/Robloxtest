--!strict

local AssignmentRules = {}

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
