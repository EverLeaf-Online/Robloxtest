-- Run with Lune after: rojo build default.project.json -o build/expeditions.rbxlx
-- Executes shipped modules with explicit service doubles; this is not a Roblox client playtest.
local fs = require("@lune/fs")
local roblox = require("@lune/roblox")
local luau = require("@lune/luau")
local process = require("@lune/process")
local serde = require("@lune/serde")
local game = roblox.deserializePlace(fs.readFile(process.args[1] or "build/expeditions.rbxlx"))
local shared = game:GetService("ReplicatedStorage").Shared
local server = game:GetService("ServerScriptService").Server
local modules = {}
local doubles = {}
local deferred = {}
local checks = 0
local function check(condition, message)
	assert(condition, message)
	checks += 1
end
local loadModule
loadModule = function(module)
	if doubles[module] then
		return doubles[module]
	end
	if modules[module] then
		return modules[module]
	end
	local env = {
		game = game,
		script = module,
		require = loadModule,
		Instance = roblox.Instance,
		Vector3 = roblox.Vector3,
		Vector2 = roblox.Vector2,
		CFrame = roblox.CFrame,
		Color3 = roblox.Color3,
		Enum = roblox.Enum,
		UDim2 = roblox.UDim2,
		UDim = roblox.UDim,
		Random = {
			new = function()
				return {
					NextInteger = function(_, low)
						return low
					end,
					NextNumber = function()
						return 0.99
					end,
				}
			end,
		},
		task = {
			delay = function(seconds, callback)
				table.insert(deferred, { seconds, callback })
			end,
		},
	}
	local value =
		luau.load(module.Source, { environment = env, debugName = module:GetFullName() })()
	modules[module] = value
	return value
end
local zones = loadModule(shared.Config.Zones)
local progression = loadModule(shared.Domain.ProgressionRules)
for zoneId = 3, 4 do
	local zone = zones[zoneId]
	check(
		progression.EvaluateZoneUnlock(
			zoneId - 1,
			zoneId,
			zone.UnlockCredits,
			zone.RequiredLifetimeRobots
		),
		"Exact unlock requirements"
	)
	check(not progression.EvaluateZoneUnlock(zoneId - 2, zoneId, 1e6, 100), "Cannot skip zones")
	check(
		not progression.EvaluateZoneUnlock(zoneId - 1, zoneId, zone.UnlockCredits - 1, 100),
		"Insufficient credits"
	)
	check(
		not progression.EvaluateZoneUnlock(zoneId - 1, zoneId, 1e6, zone.RequiredLifetimeRobots - 1),
		"Insufficient robots"
	)
	check(not progression.EvaluateZoneUnlock(zoneId, zoneId, 1e6, 100), "Cannot rebuy zone")
	check(progression.NormalizeCurrentZone(zoneId) == zoneId, "Persisted expedition retained")
end
check(progression.NormalizeCurrentZone(99) == 4, "Unknown zone capped")
local objective = loadModule(shared.Domain.ObjectiveGuidanceRules)
local snapshot = {
	Tutorial = {
		Milestones = {
			FirstScrap = true,
			FirstBotReveal = true,
			FirstBotAssigned = true,
			FirstIncomeEarned = true,
			FirstUpgrade = true,
		},
	},
	Progression = { Zone = 2 },
	Currencies = { Credits = 8000 },
	Stats = { LifetimeRobotsBuilt = 8 },
}
check(objective.GetStep(snapshot) == "UnlockExpedition", "Affordable next expedition objective")
snapshot.Currencies.Credits = 0
check(objective.GetStep(snapshot) == "ExploreCircuitYard", "Keep collecting until affordable")
snapshot.Progression.Zone = 3
check(objective.GetStep(snapshot) == "ExploreExpedition", "Explore unlocked region")
snapshot.Progression.Zone = 4
snapshot.Currencies.Credits = 100000
check(
	objective.GetStep(snapshot) == "ExploreExpedition",
	"Final zone has no nonexistent next unlock"
)
local builder = loadModule(server.Presentation.ExpeditionBuilder)
local plot = roblox.Instance.new("Model")
local exported = {}
for zoneId = 3, 4 do
	local region = builder.Build(plot, 1, roblox.Vector3.zero, zoneId)
	check(#region.Nodes == 12, "Twelve salvage nodes per region")
	check(region.Return:GetAttribute("CurrentZone") == zoneId, "Return portal routes to factory")
	local origin = region.Arrival.Position - roblox.Vector3.new(0, 0.5, 66)
	local count = 0
	for _, instance in region.Root:GetDescendants() do
		if instance:IsA("BasePart") then
			count += 1
			check(instance.Anchored, "All scenery anchored")
			local p, s, c = instance.Position, instance.Size, instance.Color
			local rotation = { 0, 0, 0 }
			pcall(function()
				local r = instance.Orientation
				rotation = { r.X, r.Y, r.Z }
			end)
			local shape = "Block"
			pcall(function()
				shape = instance.Shape.Name
			end)
			table.insert(exported, {
				zone = zoneId,
				name = instance.Name,
				position = { p.X, p.Y, p.Z },
				size = { s.X, s.Y, s.Z },
				color = { c.R, c.G, c.B },
				rotation = rotation,
				shape = shape,
			})
		end
	end
	check(count < 190, "Region geometry budget")
	for i, position in region.Nodes do
		local offset = position - origin
		check(math.abs(offset.X) < 82 and math.abs(offset.Z) < 82, "Salvage inside safety barriers")
		for j, other in region.Nodes do
			if i ~= j then
				check((position - other).Magnitude > 10, "Salvage spacing")
			end
		end
		-- Clear a standing corridor beside each pile, on its inward side.
		local stand = position
			+ (
				if math.abs(offset.X) > 60
					then roblox.Vector3.new(-math.sign(offset.X) * 7, 0, 0)
					else roblox.Vector3.new(0, 0, 7)
			)
		for _, obstacle in region.Root:GetDescendants() do
			if obstacle:IsA("BasePart") and obstacle.Size.Y > 1 and obstacle.Position.Y > 0 then
				local d = stand - obstacle.Position
				check(
					not (
							math.abs(d.X) < obstacle.Size.X / 2 + 1.5
							and math.abs(d.Z) < obstacle.Size.Z / 2 + 1.5
							and obstacle.Position.Y - obstacle.Size.Y / 2 < 5
						),
					"Salvage approach obstructed by " .. obstacle.Name
				)
			end
		end
	end
end
fs.writeFile("build/expeditions-geometry.json", serde.encode("json", exported))
local services = server.Services
local data = {
	Progression = { Zone = 2 },
	Currencies = { Credits = 100000 },
	Stats = { LifetimeRobotsBuilt = 100 },
	Tutorial = { Milestones = { FirstScrap = true } },
	Materials = {},
}
local near = true
local ownedPlot = 1
local gates, arrivals, nodes = {}, {}, {}
local lastResult
local sinks = 0
local teleports = 0
local player = {
	Character = { Parent = plot, PivotTo = function() end },
	RequestStreamAroundAsync = function() end,
}
local position = roblox.Vector3.zero
local returnedPosition
player.Character.PivotTo = function(_, cf)
	teleports += 1
	returnedPosition = cf.Position
end
doubles[services.DataService] = {
	GetData = function()
		return data
	end,
	Transaction = function(_, callback)
		local _, result = callback(data)
		return true, result
	end,
}
doubles[services.EconomyService] = {
	SpendCredits = function(profile, amount)
		if profile.Currencies.Credits < amount then
			return false
		end
		profile.Currencies.Credits -= amount
		return true
	end,
	GrantMaterials = function(profile, rewards)
		for key, value in rewards do
			profile.Materials[key] = (profile.Materials[key] or 0) + value
		end
		return true
	end,
}
doubles[services.PlotService] = {
	GetPlotId = function()
		return ownedPlot
	end,
	RefreshPresentation = function() end,
}
doubles[services.WorldService] = {
	GetPlotZoneGate = function(_, zone)
		return gates[zone]
	end,
	GetPlotZoneArrival = function(_, zone)
		return arrivals[zone]
	end,
	GetPlotZoneReturn = function(_, zone)
		return gates[zone]
	end,
	GetSalvageNode = function(id)
		return nodes[id]
	end,
}
doubles[services.StateService] = {
	ActionResult = function(_, _, success, code, payload)
		lastResult = { Success = success, Code = code, Payload = payload }
	end,
	PushSnapshot = function() end,
}
doubles[services.AnalyticsService] = {
	RecordCreditSink = function()
		sinks += 1
	end,
}
doubles[services.RemoteService] = {}
doubles[services.RateLimiter] = {}
doubles[services.MonetizationService] = {
	GetStorageMultiplier = function()
		return 1
	end,
}
doubles[server.Util.PlayerCharacter] = {
	IsNear = function()
		return near
	end,
	GetPosition = function()
		return position
	end,
}
local zoneService = loadModule(services.ZoneService)
for zoneId = 3, 4 do
	local gate = roblox.Instance.new("Part")
	gate:SetAttribute("TravelGate", true)
	gates[zoneId] = gate
	local arrival = roblox.Instance.new("Part")
	arrival.Position = roblox.Vector3.new(zoneId * 100, 0, 0)
	arrivals[zoneId] = arrival
	local before = data.Currencies.Credits
	near = false
	zoneService.UseGate(player, zoneId)
	check(
		lastResult.Code == "TOO_FAR_AWAY" and data.Currencies.Credits == before,
		"Remote unlock requires proximity"
	)
	near = true
	zoneService.UseGate(player, zoneId)
	check(lastResult.Success and data.Progression.Zone == zoneId, "Unlock changes progression")
	check(data.Currencies.Credits == before - zones[zoneId].UnlockCredits, "Charge exactly once")
	check(
		returnedPosition == arrival.Position + roblox.Vector3.new(0, 4, 0),
		"Travel to safe arrival"
	)
	local paid = data.Currencies.Credits
	zoneService.UseGate(player, zoneId)
	check(
		data.Currencies.Credits == paid and lastResult.Code == "ZONE_ALREADY_UNLOCKED",
		"Repeat travel free"
	)
end
check(sinks == 2 and teleports == 4, "One sink per unlock and repeat travel works")
arrivals[1] = { Position = roblox.Vector3.zero }
zoneService.ReturnToStarter(player, 4)
check(returnedPosition == roblox.Vector3.new(0, 4, 0), "Return to factory")
local salvage = loadModule(services.SalvageService)
local cache = roblox.Instance.new("Part")
cache.Position = position
cache:SetAttribute("PlotId", 1)
cache:SetAttribute("ZoneId", 4)
cache:SetAttribute("ExpeditionCache", true)
nodes.Cache = cache
data.Progression.Zone = 3
salvage.Collect(player, "Cache")
check(lastResult.Code == "ZONE_LOCKED", "Locked expedition cannot be collected")
data.Progression.Zone = 4
ownedPlot = 2
salvage.Collect(player, "Cache")
check(not lastResult.Success, "Cannot collect another plot")
ownedPlot = 1
salvage.Collect(player, "Cache")
check(lastResult.Success, "Owner collects cache")
check(
	data.Materials.Wiring == 2 and data.Materials.PowerCoreFragments == 1,
	"Guaranteed cache bonus"
)
check(deferred[#deferred][1] == 60, "Cache respawn is 60 seconds")
salvage.Collect(player, "Cache")
check(lastResult.Code == "NODE_RESPAWNING", "Cannot double collect")
deferred[#deferred][2]()
salvage.Collect(player, "Cache")
check(lastResult.Success, "Cache usable after respawn")
print(
	("PASS: %d expedition checks; production modules executed under Lune service doubles."):format(
		checks
	)
)
