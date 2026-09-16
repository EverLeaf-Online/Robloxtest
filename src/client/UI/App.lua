--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)

local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local Robots = require(ReplicatedStorage.Shared.Config.Robots)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local COLORS = {
	Panel = Color3.fromRGB(24, 27, 34),
	PanelAlt = Color3.fromRGB(34, 38, 47),
	PanelSoft = Color3.fromRGB(43, 48, 59),
	Text = Color3.fromRGB(245, 247, 250),
	Muted = Color3.fromRGB(170, 178, 190),
	Accent = Color3.fromRGB(104, 214, 156),
	AccentDark = Color3.fromRGB(48, 132, 88),
	Danger = Color3.fromRGB(228, 101, 101),
	Warning = Color3.fromRGB(240, 190, 82),
}

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
		Corner = corner(9),
		Title = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Position = UDim2.fromOffset(10, 8),
			Size = UDim2.new(1, -20, 0, 17),
			Text = title,
			TextColor3 = COLORS.Muted,
			TextSize = 11,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Value = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(10, 25),
			Size = UDim2.new(1, -20, 0, 25),
			Text = value,
			TextColor3 = COLORS.Text,
			TextSize = 18,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

local function getObjective(snapshot: any): (string, string)
	local milestones = snapshot.Tutorial.Milestones
	if milestones.FirstScrap ~= true then
		return "Collect scrap", "Walk to a scrap pile and use its Collect prompt."
	elseif milestones.FirstProcess ~= true then
		return "Process materials", "Use the processor console to make wiring or recover a core."
	elseif milestones.FirstBotReveal ~= true then
		return "Build your first bot", "Use the assembler once you have enough materials."
	elseif milestones.FirstBotAssigned ~= true then
		return "Put your bot to work", "Open Bots and assign your new bot to Pad 1."
	elseif milestones.FirstIncomeEarned ~= true then
		return "Earn your first credits", "Your assigned bot produces credits automatically."
	elseif milestones.FirstUpgrade ~= true then
		return "Buy an upgrade", "Open Upgrades and improve your factory."
	end
	return "Grow the factory", "Collect, build better bots, and expand your production capacity."
end

local function getAssignedPad(snapshot: any, robotUid: string): string?
	for padId, assignedUid in snapshot.Assignments.WorkPads do
		if assignedUid == robotUid then
			return padId
		end
	end
	return nil
end

local function firstFreePad(snapshot: any): string?
	local slots = FactoryRules.GetWorkSlots(snapshot.Machines.WorkSlotsLevel)
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

local function machineStatus(snapshot: any, now: number): string
	local processor = snapshot.Machines.ProcessorJob
	local assembler = snapshot.Machines.AssemblerJob
	local lines = {}

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

local function buildRobotRows(snapshot: any): any
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
			local freePad = firstFreePad(snapshot)
			local canAssign = assignedPad == nil and freePad ~= nil
			local canRecycle = assignedPad == nil
			local rowChildren: { [string]: any } = {
				Corner = corner(8),
				Name = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Position = UDim2.fromOffset(10, 7),
					Size = UDim2.new(1, -200, 0, 20),
					Text = definition.DisplayName,
					TextColor3 = COLORS.Text,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Meta = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.Gotham,
					Position = UDim2.fromOffset(10, 28),
					Size = UDim2.new(1, -200, 0, 18),
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
					Position = UDim2.new(1, -188, 0.5, -16),
					Size = UDim2.fromOffset(92, 32),
				}, {
					Button = button(
						assignedPad or (freePad and "Assign" or "No Slot"),
						canAssign,
						if canAssign
							then function()
								getRemote(RemoteNames.RequestAssignRobot):FireServer(uid, freePad)
							end
							else nil
					),
				}),
				Recycle = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.new(1, -92, 0.5, -16),
					Size = UDim2.fromOffset(92, 32),
				}, {
					Button = button(
						("+%s"):format(formatNumber(definition.RecycleCredits)),
						canRecycle,
						if canRecycle
							then function()
								getRemote(RemoteNames.RequestSellRobot):FireServer(uid)
							end
							else nil
					),
				}),
			}

			rows[("Robot_%s"):format(uid)] = React.createElement("Frame", {
				BackgroundColor3 = COLORS.PanelSoft,
				BorderSizePixel = 0,
				LayoutOrder = index,
				Size = UDim2.new(1, 0, 0, 54),
			}, rowChildren)
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

local function App()
	local snapshot, setSnapshot = React.useState(nil :: any?)
	local activeTab, setActiveTab = React.useState("Bots")
	local actionMessage, setActionMessage = React.useState("" :: string)
	local actionSuccess, setActionSuccess = React.useState(true)
	local now, setNow = React.useState(os.time())
	local compact, setCompact = React.useState(false)

	React.useEffect(function()
		local stateRemote = getRemote(RemoteNames.StateSnapshot)
		local actionRemote = getRemote(RemoteNames.ActionResult)
		local requestState = getRemote(RemoteNames.RequestState)

		local stateConnection = stateRemote.OnClientEvent:Connect(function(nextSnapshot)
			setSnapshot(nextSnapshot)
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
			actionConnection:Disconnect()
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
	local panelSize = if compact then UDim2.new(1, -24, 0.46, 0) else UDim2.new(0, 410, 1, -96)
	local panelPosition = if compact then UDim2.new(0, 12, 1, -12) else UDim2.new(1, -12, 0, 84)
	local panelAnchor = if compact then Vector2.new(0, 1) else Vector2.new(1, 0)
	local objectiveWidth = if compact then UDim2.new(1, -24, 0, 76) else UDim2.fromOffset(380, 76)
	local contentChildren = if activeTab == "Bots"
		then buildRobotRows(snapshot)
		else buildUpgradeRows(snapshot)

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		TopBar = React.createElement("Frame", {
			BackgroundColor3 = COLORS.Panel,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, 12),
			Size = UDim2.new(1, -24, 0, 60),
		}, {
			Corner = corner(10),
			Padding = padding(6),
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 8),
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
			Position = UDim2.fromOffset(12, 84),
			Size = objectiveWidth,
		}, {
			Corner = corner(10),
			Title = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromOffset(12, 10),
				Size = UDim2.new(1, -24, 0, 20),
				Text = objectiveTitle,
				TextColor3 = COLORS.Accent,
				TextSize = 15,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Body = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				Position = UDim2.fromOffset(12, 32),
				Size = UDim2.new(1, -24, 0, 34),
				Text = objectiveBody,
				TextColor3 = COLORS.Text,
				TextSize = 12,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
			}),
		}),

		MachineStatus = React.createElement("Frame", {
			BackgroundColor3 = COLORS.Panel,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, 168),
			Size = if compact then UDim2.new(1, -24, 0, 60) else UDim2.fromOffset(380, 60),
		}, {
			Corner = corner(10),
			Text = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				Position = UDim2.fromOffset(12, 9),
				Size = UDim2.new(1, -24, 1, -18),
				Text = machineStatus(snapshot, now),
				TextColor3 = COLORS.Text,
				TextSize = 12,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Center,
			}),
		}),

		Panel = React.createElement("Frame", {
			AnchorPoint = panelAnchor,
			BackgroundColor3 = COLORS.Panel,
			BorderSizePixel = 0,
			Position = panelPosition,
			Size = panelSize,
		}, {
			Corner = corner(12),
			Header = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.fromOffset(12, 10),
				Size = UDim2.new(1, -24, 0, 40),
			}, {
				Title = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Size = UDim2.new(1, -190, 1, 0),
					Text = if activeTab == "Bots"
						then ("Bots (%d)"):format(countOwnedRobots(snapshot))
						else "Factory Upgrades",
					TextColor3 = COLORS.Text,
					TextSize = 17,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Bots = React.createElement("TextButton", {
					BackgroundColor3 = if activeTab == "Bots"
						then COLORS.AccentDark
						else COLORS.PanelSoft,
					Font = Enum.Font.GothamBold,
					Position = UDim2.new(1, -184, 0.5, -16),
					Size = UDim2.fromOffset(86, 32),
					Text = "Bots",
					TextColor3 = COLORS.Text,
					TextSize = 12,
					[React.Event.Activated] = function()
						setActiveTab("Bots")
					end,
				}, {
					Corner = corner(7),
				}),
				Upgrades = React.createElement("TextButton", {
					BackgroundColor3 = if activeTab == "Upgrades"
						then COLORS.AccentDark
						else COLORS.PanelSoft,
					Font = Enum.Font.GothamBold,
					Position = UDim2.new(1, -92, 0.5, -16),
					Size = UDim2.fromOffset(92, 32),
					Text = "Upgrades",
					TextColor3 = COLORS.Text,
					TextSize = 12,
					[React.Event.Activated] = function()
						setActiveTab("Upgrades")
					end,
				}, {
					Corner = corner(7),
				}),
			}),
			Hint = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				Position = UDim2.fromOffset(12, 52),
				Size = UDim2.new(1, -24, 0, 30),
				Text = if activeTab == "Bots"
					then "Assign idle bots to unlocked pads. Assigned bots generate credits."
					else "Upgrade prices and levels are validated by the server.",
				TextColor3 = COLORS.Muted,
				TextSize = 11,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Content = React.createElement("ScrollingFrame", {
				AutomaticCanvasSize = Enum.AutomaticSize.Y,
				BackgroundTransparency = 1,
				BorderSizePixel = 0,
				CanvasSize = UDim2.fromOffset(0, 0),
				Position = UDim2.fromOffset(12, 88),
				ScrollBarThickness = 4,
				Size = UDim2.new(1, -24, 1, -100),
			}, contentChildren),
		}),

		Toast = if actionMessage ~= ""
			then React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 1),
				BackgroundColor3 = if actionSuccess then COLORS.AccentDark else COLORS.Danger,
				BorderSizePixel = 0,
				Position = if compact
					then UDim2.new(0.5, 0, 0.53, -8)
					else UDim2.new(0.5, 0, 1, -16),
				Size = UDim2.fromOffset(300, 38),
			}, {
				Corner = corner(9),
				Text = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Size = UDim2.fromScale(1, 1),
					Text = actionMessage,
					TextColor3 = COLORS.Text,
					TextSize = 13,
				}),
			})
			else nil,
	})
end

return App
