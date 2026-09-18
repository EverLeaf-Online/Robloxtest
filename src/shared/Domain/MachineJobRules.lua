--!strict

local MachineJobRules = {}

local function isFiniteNumber(value: any): boolean
	return typeof(value) == "number" and value == value and value > -math.huge and value < math.huge
end

function MachineJobRules.IsDue(active: boolean, completesAt: any, now: any): boolean
	if not active or not isFiniteNumber(completesAt) or not isFiniteNumber(now) then
		return false
	end
	return completesAt <= now
end

function MachineJobRules.IsWaiting(active: boolean, completesAt: any, now: any): boolean
	if not active or not isFiniteNumber(completesAt) or not isFiniteNumber(now) then
		return false
	end
	return completesAt > now
end

return table.freeze(MachineJobRules)
