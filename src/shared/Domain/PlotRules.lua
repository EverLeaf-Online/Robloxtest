--!strict

local PlotRules = {}

function PlotRules.IsValidPlotId(plotId: number, plotCount: number): boolean
	return plotId % 1 == 0 and plotId >= 1 and plotId <= plotCount
end

function PlotRules.FindFirstFree(plotCount: number, claimed: { [number]: boolean }): number?
	if plotCount < 1 then
		return nil
	end

	for plotId = 1, plotCount do
		if claimed[plotId] ~= true then
			return plotId
		end
	end
	return nil
end

return table.freeze(PlotRules)
