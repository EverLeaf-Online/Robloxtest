--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)

local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local Robots = require(ReplicatedStorage.Shared.Config.Robots)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)
local Zones = require(ReplicatedStorage.Shared.Config.Zones)

local UIBus = require(script.Parent.UIBus)
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LocalPlayer = Players.LocalPlayer

local COLORS = {
	Panel = Color3.fromRGB(24, 27, 34),
	PanelAlt = Color3.fromRGB(34, 38, 47),
	PanelSoft = Color3.fromRGB(43, 48, 59),
	Text = Color3.fromRGB(245, 247, 250),
	Muted = Color3.fromRGB(170, 178, 190),
	Accent = Color3.fromRGB(104, 214, 156),
	AccentDark = Color3.fromRGB(48, 132, 88),
	Danger = Color3.fromRGB(228, 101, 101),
}

local rarityColors = table.freeze({
	Common = Color3.fromRGB(182, 188, 199),
	Uncommon = Color3.fromRGB(91, 199, 121),
	Rare = Color3.fromRGB(83, 151, 232),
	Epic = Color3.fromRGB(186, 95, 229),
})

local rarityOrder = table.freeze({
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
})

local upgradeFields = table.freeze({
	ProcessorSpeed = "ProcessorLevel",
	AssemblerSpeed = "AssemblerLevel",
	Storage = "StorageLevel",
	WorkSlots = "WorkSlotsLevel",
})

local upgradeOrder = table.freeze({
	"ProcessorSpeed",
	"AssemblerSpeed",
	"Storage",
	"WorkSlots",
})

local function getRemote(name: string): RemoteEvent
	return Remotes:WaitForChild(name) :: RemoteEvent
end

local function formatNumber(value: number): string
	if value >= 1_000_000_000 then
		return ("%.1fB"):format(value / 1_000_000_000)
	elseif value >= 1_000_000 then
		return ("%.1fM"):format(value / 1_000_000)
	elseif value >= 1_000 then
		return ("%.1fK"):format(value / 1_000)
	end
	return tostring(math.floor(value))
end

local function readableCode(code: string): string
	local text = string.gsub(code, "_", " ")
	return string.lower(text):gsub("^%l", string.upper)
end

local function mergeProductionDelta(currentSnapshot: any, delta: any): any
	if typeof(currentSnapshot) ~= "table" or typeof(delta) ~= "table" then
		return currentSnapshot
	end

	local currentRevision = currentSnapshot.Revision
	local deltaRevision = delta.Revision
	if
		typeof(currentRevision) == "number"
		and typeof(deltaRevision) == "number"
		and deltaRevision < currentRevision
	then
		return currentSnapshot
	end

	local nextSnapshot = table.clone(currentSnapshot)
	if typeof(deltaRevision) == "number" then
		nextSnapshot.Revision = deltaRevision
	end

	if typeof(delta.Currencies) == "table" and typeof(delta.Currencies.Credits) == "number" then
		local currencies = table.clone(currentSnapshot.Currencies)
		currencies.Credits = delta.Currencies.Credits
		nextSnapshot.Currencies = currencies
	end

	if typeof(delta.Stats) == "table" and typeof(delta.Stats.LifetimeCredits) == "number" then
		local stats = table.clone(currentSnapshot.Stats)
		stats.LifetimeCredits = delta.Stats.LifetimeCredits
		nextSnapshot.Stats = stats
	end

	if typeof(delta.Tutorial) == "table" and typeof(delta.Tutorial.Milestones) == "table" then
		local tutorial = table.clone(currentSnapshot.Tutorial)
		local milestones = table.clone(currentSnapshot.Tutorial.Milestones)
		if typeof(delta.Tutorial.Milestones.FirstIncomeEarned) == "boolean" then
			milestones.FirstIncomeEarned = delta.Tutorial.Milestones.FirstIncomeEarned
		end
		tutorial.Milestones = milestones
		nextSnapshot.Tutorial = tutorial
	end

	return nextSnapshot
end

local function corner(radius: number): any
	return React.createElement("UICorner", {
		CornerRadius = UDim.new(0, radius),
	})
end

local function padding(all: number): any
	return React.createElement("UIPadding", {
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
		PaddingTop = UDim.new(0, all),
	})
end

local function textLabel(text: string, size: number, color: Color3?, bold: boolean?): any
	return React.createElement("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham,
		Size = UDim2.fromScale(1, 0),
		Text = text,
		TextColor3 = color or COLORS.Text,
		TextSize = size,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

local function button(text: string, enabled: boolean, callback: (() -> ())?): any
	local props: any = {
		AutoButtonColor = enabled,
		BackgroundColor3 = if enabled then COLORS.AccentDark else COLORS.PanelSoft,
		Font = Enum.Font.GothamBold,
		Size = UDim2.fromOffset(92, 32),
		Text = text,
		TextColor3 = if enabled then COLORS.Text else COLORS.Muted,
		TextSize = 13,
	}
	if enabled and callback ~= nil then
		props[React.Event.Activated] = callback
	end
	return React.createElement("TextButton", props, {
		Corner = corner(7),
	})
end

local function statCard(title: string, value: string): any
	return React.createElement("Frame", {
		BackgroundColor3 = COLORS.PanelAlt,
		BorderSizePixel = 0,
		Size = UDim2.new(0.25, -6, 1, 0),
	}, {
		Corner = corner(8),
		Title = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Position = UDim2.fromOffset(9, 4),
			Size = UDim2.new(1, -18, 0, 14),
			Text = title,
			TextColor3 = COLORS.Muted,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Value = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(9, 17),
			Size = UDim2.new(1, -18, 0, 20),
			Text = value,
			TextColor3 = COLORS.Text,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

local function plotId(snapshot: any): number?
	if typeof(snapshot.Plot) ~= "table" or typeof(snapshot.Plot.Id) ~= "number" then
		return nil
	end
	return snapshot.Plot.Id
end

local function getObjective(snapshot: any): (string, string)
	local milestones = snapshot.Tutorial.Milestones
	local ownedPlotId = plotId(snapshot)
	local plotText = if ownedPlotId then (" at Plot %d"):format(ownedPlotId) else ""
	if milestones.FirstScrap ~= true then
		return "Collect scrap", "Walk to a scrap pile and use its Collect prompt."
	elseif milestones.FirstProcess ~= true then
		return "Process materials",
			("Use your processor%s to make wiring or recover a core."):format(plotText)
	elseif milestones.FirstBotReveal ~= true then
		return "Build your first bot",
			("Use your assembler%s once you have enough materials."):format(plotText)
	elseif milestones.FirstBotAssigned ~= true then
		return "Put your bot to work",
			"Use the BOT CONTROL terminal and assign the bot to a work pad."
	elseif milestones.FirstIncomeEarned ~= true then
		return "Earn your first credits", "Your assigned bot produces credits automatically."
	elseif milestones.FirstUpgrade ~= true then
		return "Buy an upgrade", "Use the UPGRADES terminal at your factory."
	elseif snapshot.Progression.Zone < 2 then
		local zone = Zones[2]
		return "Unlock Circuit Yard",
			("Gate progress: %s/%s Credits • %d/%d bots built."):format(
				formatNumber(snapshot.Currencies.Credits),
				formatNumber(zone.UnlockCredits),
				math.min(snapshot.Stats.LifetimeRobotsBuilt, zone.RequiredLifetimeRobots),
				zone.RequiredLifetimeRobots
			)
	end
	return "Explore Circuit Yard", "Its salvage piles have better wiring and core-fragment yields."
end

local function getAssignedPad(snapshot: any, robotUid: string): string?
	for padId, assignedUid in snapshot.Assignments.WorkPads do
		if assignedUid == robotUid then
			return padId
		end
	end
	return nil
end

local function firstFreePad(snapshot: any, extraWorkSlots: number): string?
	local slots = math.min(
		GameConfig.Factory.MaxWorkSlots + 2,
		FactoryRules.GetWorkSlots(snapshot.Machines.WorkSlotsLevel) + extraWorkSlots
	)
	for index = 1, slots do
		local padId = ("Pad%d"):format(index)
		if snapshot.Assignments.WorkPads[padId] == nil then
			return padId
		end
	end
	return nil
end

local function countOwnedRobots(snapshot: any): number
	local count = 0
	for _ in snapshot.Robots.OwnedByUid do
		count += 1
	end
	return count
end

local function countOwnedRobotId(snapshot: any, robotId: string): number
	local count = 0
	for _, owned in snapshot.Robots.OwnedByUid do
		if owned.RobotId == robotId then
			count += 1
		end
	end
	return count
end

local function countRobotDefinitions(): number
	local count = 0
	for _ in Robots.Definitions do
		count += 1
	end
	return count
end

local function countDiscovered(snapshot: any): number
	local count = 0
	for robotId in Robots.Definitions do
		if snapshot.Collection.RobotSeen[robotId] == true then
			count += 1
		end
	end
	return count
end

local function machineStatus(snapshot: any, now: number): string
	local processor = snapshot.Machines.ProcessorJob
	local assembler = snapshot.Machines.AssemblerJob
	local lines = {}
	local ownedPlotId = plotId(snapshot)

	table.insert(
		lines,
		if ownedPlotId then ("Plot %d"):format(ownedPlotId) else "Assigning plot..."
	)
	if processor.Active then
		local remaining = math.max(0, processor.CompletesAt - now)
		table.insert(lines, ("Processor: %s (%ds)"):format(processor.RecipeId, remaining))
	else
		table.insert(lines, "Processor: Ready")
	end
	if assembler.Active then
		local remaining = math.max(0, assembler.CompletesAt - now)
		table.insert(lines, ("Assembler: Building (%ds)"):format(remaining))
	else
		table.insert(lines, "Assembler: Ready")
	end
	return table.concat(lines, "\n")
end

local function buildRobotRows(snapshot: any, extraWorkSlots: number): any
	local rows: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local ids = {}
	for uid in snapshot.Robots.OwnedByUid do
		table.insert(ids, uid)
	end
	table.sort(ids)
	if #ids == 0 then
		rows.Empty = textLabel("No bots yet. Build one at the assembler.", 13, COLORS.Muted)
		return rows
	end

	for index, uid in ids do
		local owned = snapshot.Robots.OwnedByUid[uid]
		local definition = Robots.Definitions[owned.RobotId]
		if definition ~= nil then
			local assignedPad = getAssignedPad(snapshot, uid)
			local freePad = firstFreePad(snapshot, extraWorkSlots)
			local canRecycle = assignedPad == nil
			local assignmentText = "No Slot"
			local assignmentCallback: (() -> ())? = nil
			if assignedPad ~= nil then
				assignmentText = "Unassign"
				assignmentCallback = function()
					getRemote(RemoteNames.RequestUnassignRobot):FireServer(uid)
				end
			elseif freePad ~= nil then
				assignmentText = "Assign"
				assignmentCallback = function()
					getRemote(RemoteNames.RequestAssignRobot):FireServer(uid, freePad)
				end
			end

			rows[("Robot_%s"):format(uid)] = React.createElement("Frame", {
				BackgroundColor3 = COLORS.PanelSoft,
				BorderSizePixel = 0,
				LayoutOrder = index,
				Size = UDim2.new(1, 0, 0, 58),
			}, {
				Corner = corner(8),
				Name = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Position = UDim2.fromOffset(10, 7),
					Size = UDim2.new(1, -210, 0, 20),
					Text = definition.DisplayName,
					TextColor3 = COLORS.Text,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Meta = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.Gotham,
					Position = UDim2.fromOffset(10, 30),
					Size = UDim2.new(1, -210, 0, 18),
					Text = ("%s • %.1f credits/s • %s"):format(
						definition.Rarity,
						definition.ProductionPerSecond,
						assignedPad or "Idle"
					),
					TextColor3 = COLORS.Muted,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Assign = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.new(1, -198, 0.5, -16),
					Size = UDim2.fromOffset(92, 32),
				}, {
					Button = button(assignmentText, assignmentCallback ~= nil, assignmentCallback),
				}),
				Recycle = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.new(1, -100, 0.5, -16),
					Size = UDim2.fromOffset(92, 32),
				}, {
					Button = button(
						("Recycle +%s"):format(formatNumber(definition.RecycleCredits)),
						canRecycle,
						if canRecycle
							then function()
								getRemote(RemoteNames.RequestSellRobot):FireServer(uid)
							end
							else nil
					),
				}),
			})
		end
	end
	return rows
end

local function buildUpgradeRows(snapshot: any): any
	local rows: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, upgradeId in upgradeOrder do
		local definition = Upgrades[upgradeId]
		local field = upgradeFields[upgradeId]
		local currentLevel = snapshot.Machines[field]
		local nextLevel = FactoryRules.GetNextUpgrade(upgradeId, currentLevel)
		local enabled = nextLevel ~= nil and snapshot.Currencies.Credits >= nextLevel.CostCredits
		local valueText = if nextLevel
			then ("Next: %s • %s credits"):format(
				tostring(nextLevel.Value),
				formatNumber(nextLevel.CostCredits)
			)
			else "Maximum level reached"

		rows[("Upgrade_%s"):format(upgradeId)] = React.createElement("Frame", {
			BackgroundColor3 = COLORS.PanelSoft,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 62),
		}, {
			Corner = corner(8),
			Name = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromOffset(10, 8),
				Size = UDim2.new(1, -116, 0, 20),
				Text = ("%s • Lv.%d"):format(definition.DisplayName, currentLevel),
				TextColor3 = COLORS.Text,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Meta = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				Position = UDim2.fromOffset(10, 31),
				Size = UDim2.new(1, -116, 0, 18),
				Text = valueText,
				TextColor3 = COLORS.Muted,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Buy = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.new(1, -102, 0.5, -16),
				Size = UDim2.fromOffset(92, 32),
			}, {
				Button = button(
					nextLevel and "Upgrade" or "Max",
					enabled,
					if nextLevel
						then function()
							getRemote(RemoteNames.RequestUpgrade):FireServer(upgradeId)
						end
						else nil
				),
			}),
		})
	end
	return rows
end

local function buildIndexRows(snapshot: any): any
	local rows: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local robotIds = {}
	for robotId in Robots.Definitions do
		table.insert(robotIds, robotId)
	end
	table.sort(robotIds, function(leftId, rightId)
		local left = Robots.Definitions[leftId]
		local right = Robots.Definitions[rightId]
		local leftRank = rarityOrder[left.Rarity] or 99
		local rightRank = rarityOrder[right.Rarity] or 99
		if leftRank ~= rightRank then
			return leftRank < rightRank
		end
		return left.DisplayName < right.DisplayName
	end)

	for index, robotId in robotIds do
		local definition = Robots.Definitions[robotId]
		local seen = snapshot.Collection.RobotSeen[robotId] == true
		local ownedCount = countOwnedRobotId(snapshot, robotId)
		local title = if seen then definition.DisplayName else "???"
		local meta = if seen
			then ("%s • %s • %.1f credits/s • Owned %d"):format(
				definition.Rarity,
				definition.Family,
				definition.ProductionPerSecond,
				ownedCount
			)
			else ("%s • Undiscovered"):format(definition.Rarity)

		rows[("Index_%s"):format(robotId)] = React.createElement("Frame", {
			BackgroundColor3 = COLORS.PanelSoft,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 58),
		}, {
			Corner = corner(8),
			Rarity = React.createElement("Frame", {
				BackgroundColor3 = rarityColors[definition.Rarity] or COLORS.Muted,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(5, 58),
			}),
			Name = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromOffset(14, 8),
				Size = UDim2.new(1, -24, 0, 20),
				Text = title,
				TextColor3 = if seen then COLORS.Text else COLORS.Muted,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Meta = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				Position = UDim2.fromOffset(14, 31),
				Size = UDim2.new(1, -24, 0, 17),
				Text = meta,
				TextColor3 = COLORS.Muted,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		})
	end
	return rows
end

local function panelTitle(panelName: string, snapshot: any): string
	if panelName == "Bots" then
		return ("Bot Control (%d)"):format(countOwnedRobots(snapshot))
	elseif panelName == "Upgrades" then
		return "Factory Upgrades"
	end
	return ("Robot Index (%d/%d)"):format(countDiscovered(snapshot), countRobotDefinitions())
end

local function panelHint(panelName: string): string
	if panelName == "Bots" then
		return "Assign or unassign bots from unlocked work pads. Idle bots can be recycled."
	elseif panelName == "Upgrades" then
		return "Upgrade prices, ownership, and currency spending are validated by the server."
	end
	return "Discover robot outcomes by assembling them. Undiscovered names remain hidden."
end

local function panelContent(panelName: string, snapshot: any, extraWorkSlots: number): any
	if panelName == "Bots" then
		return buildRobotRows(snapshot, extraWorkSlots)
	elseif panelName == "Upgrades" then
		return buildUpgradeRows(snapshot)
	end
	return buildIndexRows(snapshot)
end

local function App()
	local snapshot, setSnapshot = React.useState(nil :: any?)
	local openPanel, setOpenPanel = React.useState(nil :: string?)
	local actionMessage, setActionMessage = React.useState("")
	local actionSuccess, setActionSuccess = React.useState(true)
	local now, setNow = React.useState(os.time())
	local compact, setCompact = React.useState(false)
	local extraWorkSlots, setExtraWorkSlots =
		React.useState(if LocalPlayer:GetAttribute("PassBotWorkSlots2") == true then 2 else 0)

	React.useEffect(function()
		local stateRemote = getRemote(RemoteNames.StateSnapshot)
		local deltaRemote = getRemote(RemoteNames.StateDelta)
		local actionRemote = getRemote(RemoteNames.ActionResult)
		local requestState = getRemote(RemoteNames.RequestState)
		local stateConnection = stateRemote.OnClientEvent:Connect(function(nextSnapshot)
			setSnapshot(nextSnapshot)
		end)
		local deltaConnection = deltaRemote.OnClientEvent:Connect(function(delta)
			setSnapshot(function(currentSnapshot)
				return mergeProductionDelta(currentSnapshot, delta)
			end)
		end)
		local actionConnection = actionRemote.OnClientEvent:Connect(function(actionResult)
			if typeof(actionResult) ~= "table" then
				return
			end
			setActionSuccess(actionResult.Success == true)
			setActionMessage(readableCode(tostring(actionResult.Code)))
		end)
		requestState:FireServer()
		return function()
			stateConnection:Disconnect()
			deltaConnection:Disconnect()
			actionConnection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local function refreshExtraWorkSlots()
			setExtraWorkSlots(
				if LocalPlayer:GetAttribute("PassBotWorkSlots2") == true then 2 else 0
			)
		end
		refreshExtraWorkSlots()
		local connection = LocalPlayer:GetAttributeChangedSignal("PassBotWorkSlots2")
			:Connect(refreshExtraWorkSlots)
		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local connection = UIBus.PanelRequested:Connect(function(panelName: string)
			setOpenPanel(panelName)
		end)
		return function()
			connection:Disconnect()
		end
	end, {})

	React.useEffect(function()
		local alive = true
		task.spawn(function()
			while alive do
				task.wait(0.25)
				if alive then
					setNow(os.time())
				end
			end
		end)
		return function()
			alive = false
		end
	end, {})

	React.useEffect(function()
		local camera = Workspace.CurrentCamera
		if camera == nil then
			return nil
		end
		local function refreshCompact()
			setCompact(camera.ViewportSize.X < 760)
		end
		refreshCompact()
		local connection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refreshCompact)
		return function()
			connection:Disconnect()
		end
	end, {})

	if snapshot == nil then
		return React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			Loading = React.createElement("TextLabel", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = COLORS.Panel,
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromOffset(240, 54),
				Text = "Loading factory data...",
				TextColor3 = COLORS.Text,
				TextSize = 15,
			}, {
				Corner = corner(10),
			}),
		})
	end

	local objectiveTitle, objectiveBody = getObjective(snapshot)
	local objectiveWidth = if compact then UDim2.new(1, -24, 0, 70) else UDim2.fromOffset(330, 70)
	local modalSize = if compact then UDim2.new(1, -24, 0.72, 0) else UDim2.fromOffset(560, 520)

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		TopBar = React.createElement("Frame", {
			BackgroundColor3 = COLORS.Panel,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.new(1, -24, 0, 46),
		}, {
			Corner = corner(9),
			Padding = padding(5),
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Credits = statCard("CREDITS", formatNumber(snapshot.Currencies.Credits)),
			Scrap = statCard("SCRAP", formatNumber(snapshot.Materials.ScrapMetal)),
			Wiring = statCard("WIRING", formatNumber(snapshot.Materials.Wiring)),
			Cores = statCard("CORES", formatNumber(snapshot.Materials.PowerCoreFragments)),
		}),

		Objective = React.createElement("Frame", {
			BackgroundColor3 = COLORS.Panel,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, 68),
			Size = objectiveWidth,
		}, {
			Corner = corner(9),
			Title = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromOffset(12, 8),
				Size = UDim2.new(1, -24, 0, 18),
				Text = objectiveTitle,
				TextColor3 = COLORS.Accent,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Body = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				Position = UDim2.fromOffset(12, 28),
				Size = UDim2.new(1, -24, 0, 34),
				Text = objectiveBody,
				TextColor3 = COLORS.Text,
				TextSize = 11,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
		}),

		MachineStatus = React.createElement("Frame", {
			BackgroundColor3 = COLORS.Panel,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, 146),
			Size = if compact then UDim2.new(1, -24, 0, 66) else UDim2.fromOffset(330, 66),
		}, {
			Corner = corner(9),
			Text = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				Position = UDim2.fromOffset(12, 7),
				Size = UDim2.new(1, -24, 1, -14),
				Text = machineStatus(snapshot, now),
				TextColor3 = COLORS.Text,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		}),

		Overlay = if openPanel ~= nil
			then React.createElement("Frame", {
				BackgroundColor3 = Color3.new(0, 0, 0),
				BackgroundTransparency = 0.45,
				BorderSizePixel = 0,
				Size = UDim2.fromScale(1, 1),
				ZIndex = 20,
			}, {
				Panel = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = COLORS.Panel,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = modalSize,
					ZIndex = 21,
				}, {
					Corner = corner(12),
					Title = React.createElement("TextLabel", {
						BackgroundTransparency = 1,
						Font = Enum.Font.GothamBold,
						Position = UDim2.fromOffset(16, 14),
						Size = UDim2.new(1, -100, 0, 24),
						Text = panelTitle(openPanel :: string, snapshot),
						TextColor3 = COLORS.Text,
						TextSize = 18,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 22,
					}),
					Close = React.createElement("TextButton", {
						BackgroundColor3 = COLORS.PanelSoft,
						Font = Enum.Font.GothamBold,
						Position = UDim2.new(1, -82, 0, 12),
						Size = UDim2.fromOffset(66, 30),
						Text = "Close",
						TextColor3 = COLORS.Text,
						TextSize = 12,
						ZIndex = 22,
						[React.Event.Activated] = function()
							setOpenPanel(nil)
						end,
					}, {
						Corner = corner(7),
					}),
					Hint = React.createElement("TextLabel", {
						BackgroundTransparency = 1,
						Font = Enum.Font.Gotham,
						Position = UDim2.fromOffset(16, 48),
						Size = UDim2.new(1, -32, 0, 34),
						Text = panelHint(openPanel :: string),
						TextColor3 = COLORS.Muted,
						TextSize = 11,
						TextWrapped = true,
						TextXAlignment = Enum.TextXAlignment.Left,
						ZIndex = 22,
					}),
					Content = React.createElement("ScrollingFrame", {
						AutomaticCanvasSize = Enum.AutomaticSize.Y,
						BackgroundTransparency = 1,
						BorderSizePixel = 0,
						CanvasSize = UDim2.fromOffset(0, 0),
						Position = UDim2.fromOffset(16, 88),
						ScrollBarThickness = 4,
						Size = UDim2.new(1, -32, 1, -104),
						ZIndex = 22,
					}, panelContent(openPanel :: string, snapshot, extraWorkSlots)),
				}),
			})
			else nil,

		Toast = if actionMessage ~= ""
			then React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = if actionSuccess then COLORS.AccentDark else COLORS.Danger,
				BorderSizePixel = 0,
				Position = UDim2.new(0.5, 0, 1, -16),
				Size = UDim2.fromOffset(300, 38),
				ZIndex = 30,
			}, {
				Corner = corner(9),
				Text = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Size = UDim2.fromScale(1, 1),
					Text = actionMessage,
					TextColor3 = COLORS.Text,
					TextSize = 13,
					ZIndex = 31,
				}),
			})
			else nil,
	})
end

return App
