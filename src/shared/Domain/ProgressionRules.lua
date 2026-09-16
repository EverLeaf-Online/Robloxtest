--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local ProgressionRules = {}

function ProgressionRules.GetNextZone(currentZone: number): any?
	return Zones[currentZone + 1]
end

function ProgressionRules.NormalizeCurrentZone(value: any): number
	if typeof(value) ~= "number" or value ~= value or value % 1 ~= 0 or value < 1 then
		return 1
	end

	local requestedZone = math.floor(value)
	local currentZone = 1
	for zoneId = 2, requestedZone do
		if Zones[zoneId] == nil then
			break
		end
		currentZone = zoneId
	end
	return currentZone
end

function ProgressionRules.EvaluateZoneUnlock(
	currentZone: number,
	targetZone: number,
	credits: number,
	lifetimeRobotsBuilt: number
): (boolean, string, any?)
	local definition = Zones[targetZone]
	if definition == nil then
		return false, "UNKNOWN_ZONE", nil
	end
	if targetZone <= currentZone then
		return false, "ZONE_ALREADY_UNLOCKED", definition
	end
	if targetZone ~= currentZone + 1 then
		return false, "ZONE_SEQUENCE_INVALID", definition
	end
	if lifetimeRobotsBuilt < definition.RequiredLifetimeRobots then
		return false, "MORE_ROBOTS_REQUIRED", definition
	end
	if credits < definition.UnlockCredits then
		return false, "NOT_ENOUGH_CREDITS", definition
	end
	return true, "ZONE_UNLOCK_READY", definition
end

return table.freeze(ProgressionRules)
