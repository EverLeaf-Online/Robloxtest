--!strict

local SalvageAccessRules = {}

function SalvageAccessRules.Evaluate(
	ownedPlotId: number?,
	nodePlotId: number?,
	unlockedZone: number,
	nodeZone: number
): (boolean, string)
	if nodePlotId ~= nil then
		if ownedPlotId == nil or ownedPlotId ~= nodePlotId then
			return false, "NOT_YOUR_PLOT"
		end
	end

	if unlockedZone < nodeZone then
		return false, "ZONE_LOCKED"
	end

	return true, "SALVAGE_ALLOWED"
end

return table.freeze(SalvageAccessRules)
