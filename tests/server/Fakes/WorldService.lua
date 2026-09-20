--!strict

local WorldService = {}

local gatesByPlot: { [number]: { [number]: BasePart } } = {}
local arrivalsByPlot: { [number]: { [number]: BasePart } } = {}
local salvageNodes: { [string]: BasePart } = {}

function WorldService.Reset()
	table.clear(gatesByPlot)
	table.clear(arrivalsByPlot)
	table.clear(salvageNodes)
end

function WorldService.SetPlotZoneGate(plotId: number, zoneId: number, gate: BasePart)
	gatesByPlot[plotId] = gatesByPlot[plotId] or {}
	gatesByPlot[plotId][zoneId] = gate
end

function WorldService.SetPlotZoneArrival(plotId: number, zoneId: number, arrival: BasePart)
	arrivalsByPlot[plotId] = arrivalsByPlot[plotId] or {}
	arrivalsByPlot[plotId][zoneId] = arrival
end

function WorldService.SetSalvageNode(nodeId: string, node: BasePart)
	salvageNodes[nodeId] = node
end

function WorldService.GetSalvageNode(nodeId: string): BasePart?
	return salvageNodes[nodeId]
end

function WorldService.GetSalvageNodes(): any
	return pairs(salvageNodes)
end

function WorldService.GetPlotZoneGate(plotId: number, zoneId: number): BasePart?
	local byZone = gatesByPlot[plotId]
	return if byZone ~= nil then byZone[zoneId] else nil
end

function WorldService.GetPlotZoneArrival(plotId: number, zoneId: number): BasePart?
	local byZone = arrivalsByPlot[plotId]
	return if byZone ~= nil then byZone[zoneId] else nil
end

function WorldService.GetProcessorControls(): { BasePart }
	return {}
end

function WorldService.GetPlotAssemblers(): { BasePart }
	return {}
end

function WorldService.GetAllZoneGates(): { BasePart }
	local result = {}
	for _, byZone in gatesByPlot do
		for _, gate in byZone do
			table.insert(result, gate)
		end
	end
	return result
end

function WorldService.GetAllZoneReturnPortals(): { BasePart }
	return {}
end

function WorldService.GetPlotZoneReturn(_plotId: number, _zoneId: number): BasePart?
	return nil
end

return WorldService
