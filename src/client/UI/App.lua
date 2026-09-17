--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)

local Components = require(script.Parent.Components)
local PanelContent = require(script.Parent.PanelContent)
local StateHelpers = require(script.Parent.StateHelpers)
local Theme = require(script.Parent.Theme)
local UIBus = require(script.Parent.UIBus)

local COLORS = Theme.Colors
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LocalPlayer = Players.LocalPlayer

local function getRemote(name: string): RemoteEvent
	return Remotes:WaitForChild(name) :: RemoteEvent
end

local function App()
	local snapshot, setSnapshot = React.useState(nil :: any?)
	local snapshotRef = React.useRef(nil :: any?)
	local openPanel, setOpenPanel = React.useState(nil :: string?)
	local actionMessage, setActionMessage = React.useState("")
	local actionSuccess, setActionSuccess = React.useState(true)
	local now, setNow = React.useState(Workspace:GetServerTimeNow())
	local compact, setCompact = React.useState(false)
	local extraWorkSlots, setExtraWorkSlots =
		React.useState(if LocalPlayer:GetAttribute("PassBotWorkSlots2") == true then 2 else 0)

	React.useEffect(function()
		local stateRemote = getRemote(RemoteNames.StateSnapshot)
		local deltaRemote = getRemote(RemoteNames.StateDelta)
		local actionRemote = getRemote(RemoteNames.ActionResult)
		local requestState = getRemote(RemoteNames.RequestState)
		local lastResyncRequest = -math.huge

		local stateConnection = stateRemote.OnClientEvent:Connect(function(nextSnapshot)
			if typeof(nextSnapshot) ~= "table" then
				return
			end

			local currentSnapshot = snapshotRef.current
			if typeof(currentSnapshot) == "table" then
				local currentRevision = currentSnapshot.Revision
				local nextRevision = nextSnapshot.Revision
				if
					typeof(currentRevision) == "number"
					and typeof(nextRevision) == "number"
					and nextRevision < currentRevision
				then
					return
				end
			end

			snapshotRef.current = nextSnapshot
			setSnapshot(nextSnapshot)
		end)
		local deltaConnection = deltaRemote.OnClientEvent:Connect(function(delta)
			local currentSnapshot = snapshotRef.current
			if typeof(currentSnapshot) ~= "table" then
				local nowClock = os.clock()
				if nowClock - lastResyncRequest >= 1 then
					lastResyncRequest = nowClock
					requestState:FireServer()
				end
				return
			end

			local nextSnapshot = StateHelpers.MergeProductionDelta(currentSnapshot, delta)
			if nextSnapshot ~= currentSnapshot then
				snapshotRef.current = nextSnapshot
				setSnapshot(nextSnapshot)
			end
		end)
		local actionConnection = actionRemote.OnClientEvent:Connect(function(actionResult)
			if typeof(actionResult) ~= "table" then
				return
			end
			setActionSuccess(actionResult.Success == true)
			setActionMessage(StateHelpers.ReadableCode(tostring(actionResult.Code)))
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
				task.wait(1)
				if alive then
					setNow(Workspace:GetServerTimeNow())
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
				Corner = Components.Corner(10),
			}),
		})
	end

	local objectiveTitle, objectiveBody = StateHelpers.GetObjective(snapshot)
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
			Corner = Components.Corner(9),
			Padding = Components.Padding(5),
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				Padding = UDim.new(0, 6),
				SortOrder = Enum.SortOrder.LayoutOrder,
			}),
			Credits = Components.StatCard(
				"CREDITS",
				StateHelpers.FormatNumber(snapshot.Currencies.Credits)
			),
			Scrap = Components.StatCard(
				"SCRAP",
				StateHelpers.FormatNumber(snapshot.Materials.ScrapMetal)
			),
			Wiring = Components.StatCard(
				"WIRING",
				StateHelpers.FormatNumber(snapshot.Materials.Wiring)
			),
			Cores = Components.StatCard(
				"CORES",
				StateHelpers.FormatNumber(snapshot.Materials.PowerCoreFragments)
			),
		}),

		Objective = React.createElement("Frame", {
			BackgroundColor3 = COLORS.Panel,
			BorderSizePixel = 0,
			Position = UDim2.fromOffset(12, 68),
			Size = objectiveWidth,
		}, {
			Corner = Components.Corner(9),
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
			Corner = Components.Corner(9),
			Text = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamMedium,
				Position = UDim2.fromOffset(12, 7),
				Size = UDim2.new(1, -24, 1, -14),
				Text = StateHelpers.MachineStatus(snapshot, now),
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
					Corner = Components.Corner(12),
					Title = React.createElement("TextLabel", {
						BackgroundTransparency = 1,
						Font = Enum.Font.GothamBold,
						Position = UDim2.fromOffset(16, 14),
						Size = UDim2.new(1, -100, 0, 24),
						Text = PanelContent.Title(openPanel :: string, snapshot),
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
						Corner = Components.Corner(7),
					}),
					Hint = React.createElement("TextLabel", {
						BackgroundTransparency = 1,
						Font = Enum.Font.Gotham,
						Position = UDim2.fromOffset(16, 48),
						Size = UDim2.new(1, -32, 0, 34),
						Text = PanelContent.Hint(openPanel :: string),
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
					}, PanelContent.Content(openPanel :: string, snapshot, extraWorkSlots)),
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
				Corner = Components.Corner(9),
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
