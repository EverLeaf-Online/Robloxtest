--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local React = require(ReplicatedStorage.Packages.React)
local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)

local Components = require(script.Parent.Components)
local IconAssets = require(script.Parent.IconAssets)
local PanelContent = require(script.Parent.PanelContent)
local StateHelpers = require(script.Parent.StateHelpers)
local Theme = require(script.Parent.Theme)
local UIBus = require(script.Parent.UIBus)

local COLORS = Theme.Colors
local Remotes = ReplicatedStorage:WaitForChild("Remotes")
local LocalPlayer = Players.LocalPlayer

type LayoutMode = "Desktop" | "Tablet" | "Phone"

local function getRemote(name: string): RemoteEvent
	return Remotes:WaitForChild(name) :: RemoteEvent
end

local function layoutModeForWidth(width: number): LayoutMode
	if width <= 760 then
		return "Phone"
	elseif width <= 1120 then
		return "Tablet"
	end
	return "Desktop"
end

local function resourceClusterSize(mode: LayoutMode): UDim2
	if mode == "Phone" then
		return UDim2.fromOffset(360, 44)
	elseif mode == "Tablet" then
		return UDim2.fromOffset(570, 52)
	end
	return UDim2.fromOffset(700, 58)
end

local function resourceClusterPosition(mode: LayoutMode): UDim2
	if mode == "Phone" then
		return UDim2.new(0.61, 0, 0, 8)
	elseif mode == "Tablet" then
		return UDim2.new(0.55, 0, 0, 9)
	end
	return UDim2.new(0.5, 0, 0, 10)
end

local function objectiveSize(mode: LayoutMode): UDim2
	if mode == "Phone" then
		return UDim2.new(0.62, 0, 0, 58)
	elseif mode == "Tablet" then
		return UDim2.fromOffset(480, 62)
	end
	return UDim2.fromOffset(520, 64)
end

local function modalSize(mode: LayoutMode): UDim2
	if mode == "Phone" then
		return UDim2.fromScale(0.92, 0.78)
	elseif mode == "Tablet" then
		return UDim2.fromScale(0.76, 0.78)
	end
	return UDim2.fromOffset(560, 520)
end

local function App()
	local snapshot, setSnapshot = React.useState(nil :: any?)
	local snapshotRef = React.useRef(nil :: any?)
	local openPanel, setOpenPanel = React.useState(nil :: string?)
	local actionMessage, setActionMessage = React.useState("")
	local actionSuccess, setActionSuccess = React.useState(true)
	local now, setNow = React.useState(Workspace:GetServerTimeNow())
	local layoutMode, setLayoutMode = React.useState("Desktop" :: LayoutMode)
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
		local viewportConnection: RBXScriptConnection? = nil
		local cameraConnection: RBXScriptConnection? = nil

		local function bindCamera()
			if viewportConnection ~= nil then
				viewportConnection:Disconnect()
				viewportConnection = nil
			end

			local camera = Workspace.CurrentCamera
			if camera == nil then
				return
			end

			local function refresh()
				setLayoutMode(layoutModeForWidth(camera.ViewportSize.X))
			end
			refresh()
			viewportConnection = camera:GetPropertyChangedSignal("ViewportSize"):Connect(refresh)
		end

		bindCamera()
		cameraConnection = Workspace:GetPropertyChangedSignal("CurrentCamera"):Connect(bindCamera)
		return function()
			if viewportConnection ~= nil then
				viewportConnection:Disconnect()
			end
			if cameraConnection ~= nil then
				cameraConnection:Disconnect()
			end
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
	local isPhone = layoutMode == "Phone"
	local objectiveHeight = if isPhone then 58 else 64
	local processorJob = snapshot.Machines.ProcessorJob
	local assemblerJob = snapshot.Machines.AssemblerJob
	local processorStatus = if processorJob.Active
		then ("%ds"):format(math.ceil(math.max(0, processorJob.CompletesAt - now)))
		else "READY"
	local assemblerStatus = if assemblerJob.Active
		then ("%ds"):format(math.ceil(math.max(0, assemblerJob.CompletesAt - now)))
		else "READY"

	return React.createElement("Frame", {
		BackgroundTransparency = 1,
		Size = UDim2.fromScale(1, 1),
	}, {
		ResourceCluster = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 0),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = resourceClusterPosition(layoutMode),
			Size = resourceClusterSize(layoutMode),
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Horizontal,
				HorizontalAlignment = Enum.HorizontalAlignment.Center,
				Padding = UDim.new(0, if isPhone then 6 else 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Credits = Components.ResourceChip(
				"Credits",
				"CREDITS",
				StateHelpers.FormatNumber(snapshot.Currencies.Credits),
				Color3.fromRGB(86, 190, 103),
				isPhone
			),
			Scrap = Components.ResourceChip(
				"Scrap",
				"SCRAP",
				StateHelpers.FormatNumber(snapshot.Materials.ScrapMetal),
				Color3.fromRGB(190, 132, 77),
				isPhone
			),
			Wiring = Components.ResourceChip(
				"Wiring",
				"WIRING",
				StateHelpers.FormatNumber(snapshot.Materials.Wiring),
				Color3.fromRGB(235, 192, 75),
				isPhone
			),
			Cores = Components.ResourceChip(
				"Cores",
				"CORES",
				StateHelpers.FormatNumber(snapshot.Materials.PowerCoreFragments),
				Color3.fromRGB(82, 169, 232),
				isPhone
			),
		}),

		MachineStatus = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = if isPhone
				then UDim2.new(0, 10, 0.46, 0)
				else UDim2.new(0, 18, 0.5, 0),
			Size = if isPhone then UDim2.fromOffset(132, 98) else UDim2.fromOffset(158, 114),
		}, {
			Layout = React.createElement("UIListLayout", {
				FillDirection = Enum.FillDirection.Vertical,
				Padding = UDim.new(0, if isPhone then 8 else 12),
				SortOrder = Enum.SortOrder.LayoutOrder,
				VerticalAlignment = Enum.VerticalAlignment.Center,
			}),
			Processor = Components.MachineIndicator(
				IconAssets.Processor,
				"PROCESSOR",
				processorStatus,
				isPhone
			),
			Assembler = Components.MachineIndicator(
				IconAssets.Assembler,
				"ASSEMBLER",
				assemblerStatus,
				isPhone
			),
		}),

		Objective = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0.5, 1),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Position = UDim2.new(0.5, 0, 1, -18),
			Size = objectiveSize(layoutMode),
		}, {
			Corner = Components.Corner(11),
			Accent = React.createElement("Frame", {
				BackgroundColor3 = COLORS.Accent,
				BorderSizePixel = 0,
				Position = UDim2.fromOffset(0, 0),
				Size = UDim2.fromOffset(5, objectiveHeight),
			}, {
				Corner = Components.Corner(11),
			}),
			Title = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromOffset(16, 7),
				Size = UDim2.new(1, -30, 0, 18),
				Text = objectiveTitle,
				TextColor3 = COLORS.Accent,
				TextSize = if isPhone then 12 else 14,
				TextStrokeColor3 = Color3.new(0, 0, 0),
				TextStrokeTransparency = 0.3,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Body = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				Position = UDim2.fromOffset(16, 27),
				Size = UDim2.new(1, -30, 1, -32),
				Text = objectiveBody,
				TextColor3 = COLORS.Text,
				TextSize = if isPhone then 10 else 11,
				TextStrokeColor3 = Color3.new(0, 0, 0),
				TextStrokeTransparency = 0.35,
				TextWrapped = true,
				TextXAlignment = Enum.TextXAlignment.Left,
				TextYAlignment = Enum.TextYAlignment.Top,
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
					Size = modalSize(layoutMode),
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
						TextSize = if isPhone then 16 else 18,
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
				Position = UDim2.new(0.5, 0, 1, if isPhone then -86 else -94),
				Size = if isPhone then UDim2.fromOffset(250, 34) else UDim2.fromOffset(300, 38),
				ZIndex = 30,
			}, {
				Corner = Components.Corner(9),
				Text = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Size = UDim2.fromScale(1, 1),
					Text = actionMessage,
					TextColor3 = COLORS.Text,
					TextSize = if isPhone then 11 else 13,
					ZIndex = 31,
				}),
			})
			else nil,
	})
end

return App
