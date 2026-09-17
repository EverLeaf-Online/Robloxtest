--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)

local PlotController = {}
local initialized = false
local currentPlotId: number? = nil
local currentHighlight: Highlight? = nil
local currentMarker: BillboardGui? = nil
local pendingPlotId: number? = nil
local retryWorkerRunning = false

local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local function clearMarker()
	if currentHighlight ~= nil then
		currentHighlight:Destroy()
		currentHighlight = nil
	end
	if currentMarker ~= nil then
		currentMarker:Destroy()
		currentMarker = nil
	end
	currentPlotId = nil
end

local function findPlot(plotId: number): Model?
	local root = Workspace:FindFirstChild("ScrapToBotGraybox")
	if root == nil then
		return nil
	end
	local plots = root:FindFirstChild("FactoryPlots")
	if plots == nil then
		return nil
	end
	local plot = plots:FindFirstChild(("Plot%02d"):format(plotId))
	return if plot ~= nil and plot:IsA("Model") then plot else nil
end

local function addMarker(plotId: number)
	if currentPlotId == plotId and currentHighlight ~= nil and currentMarker ~= nil then
		return
	end
	clearMarker()

	local plot = findPlot(plotId)
	if plot == nil then
		return
	end
	local sign = plot:FindFirstChild("OwnerSign")
	if sign == nil or not sign:IsA("BasePart") then
		return
	end

	local highlight = Instance.new("Highlight")
	highlight.Name = "LocalFactoryHighlight"
	highlight.Adornee = plot
	highlight.DepthMode = Enum.HighlightDepthMode.AlwaysOnTop
	highlight.FillColor = Color3.fromRGB(104, 214, 156)
	highlight.FillTransparency = 0.9
	highlight.OutlineColor = Color3.fromRGB(104, 214, 156)
	highlight.OutlineTransparency = 0.08
	highlight.Parent = plot

	local marker = Instance.new("BillboardGui")
	marker.Name = "LocalFactoryMarker"
	marker.Adornee = sign
	marker.AlwaysOnTop = true
	marker.Size = UDim2.fromOffset(170, 34)
	marker.StudsOffset = Vector3.new(0, 9, 0)
	marker.MaxDistance = 60
	marker.Parent = plot

	local label = Instance.new("TextLabel")
	label.BackgroundColor3 = Color3.fromRGB(48, 132, 88)
	label.BackgroundTransparency = 0.08
	label.BorderSizePixel = 0
	label.Font = Enum.Font.GothamBold
	label.Size = UDim2.fromScale(1, 1)
	label.Text = ("YOUR FACTORY  •  PLOT %d"):format(plotId)
	label.TextColor3 = Color3.fromRGB(245, 247, 250)
	label.TextScaled = true
	label.Parent = marker

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = label

	currentPlotId = plotId
	currentHighlight = highlight
	currentMarker = marker
end

local function startRetryWorker()
	if retryWorkerRunning then
		return
	end
	retryWorkerRunning = true

	task.spawn(function()
		for _ = 1, 20 do
			local requestedPlotId = pendingPlotId
			if requestedPlotId == nil then
				break
			end
			if findPlot(requestedPlotId) ~= nil then
				pendingPlotId = nil
				addMarker(requestedPlotId)
				break
			end
			task.wait(0.25)
		end

		retryWorkerRunning = false
	end)
end

local function handleSnapshot(snapshot: any)
	if typeof(snapshot) ~= "table" or typeof(snapshot.Plot) ~= "table" then
		return
	end
	local plotId = snapshot.Plot.Id
	if typeof(plotId) ~= "number" or plotId % 1 ~= 0 or plotId < 1 then
		pendingPlotId = nil
		clearMarker()
		return
	end

	if findPlot(plotId) ~= nil then
		pendingPlotId = nil
		addMarker(plotId)
		return
	end

	pendingPlotId = plotId
	startRetryWorker()
end

function PlotController.Init()
	if initialized then
		return
	end
	initialized = true

	local stateRemote = Remotes:WaitForChild(RemoteNames.StateSnapshot)
	assert(stateRemote:IsA("RemoteEvent"), "StateSnapshot must be a RemoteEvent")
	stateRemote.OnClientEvent:Connect(handleSnapshot)
end

return PlotController
