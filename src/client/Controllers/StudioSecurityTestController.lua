--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)

local StudioSecurityTestController = {}
local initialized = false

local REMOTE_NAME = "StudioSecurityTest"
local REMOTE_WAIT_TIMEOUT_SECONDS = 10
local LOG_LINE_LIMIT = 12

local function makeButton(parent: Instance, label: string, order: number, callback: () -> ())
	local button = Instance.new("TextButton")
	button.Name = ("SecurityAction%d"):format(order)
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 34)
	button.BackgroundColor3 = Color3.fromRGB(124, 76, 170)
	button.BorderSizePixel = 0
	button.Font = Enum.Font.GothamBold
	button.Text = label
	button.TextColor3 = Color3.fromRGB(245, 247, 250)
	button.TextSize = 12
	button.AutoButtonColor = true
	button.Parent = parent

	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 7)
	corner.Parent = button

	button.Activated:Connect(callback)
end

local function fireClientDone(remote: RemoteEvent, token: string, response: any?)
	remote:FireServer("ClientDone", token, response)
end

function StudioSecurityTestController.Init()
	if initialized then
		return
	end
	initialized = true

	if not RunService:IsStudio() then
		return
	end

	local player = Players.LocalPlayer
	local remotesInstance = ReplicatedStorage:WaitForChild("Remotes", REMOTE_WAIT_TIMEOUT_SECONDS)
	if remotesInstance == nil or not remotesInstance:IsA("Folder") then
		warn("[StudioSecurityTestController] Remotes folder was not created by the server")
		return
	end
	local remotes = remotesInstance
	local remoteInstance = remotes:WaitForChild(REMOTE_NAME, REMOTE_WAIT_TIMEOUT_SECONDS)
	if remoteInstance == nil or not remoteInstance:IsA("RemoteEvent") then
		warn(
			("[StudioSecurityTestController] %s was not created by the server"):format(REMOTE_NAME)
		)
		return
	end
	local testRemote = remoteInstance

	local requestCollect = remotes:WaitForChild(RemoteNames.RequestCollect) :: RemoteEvent
	local requestAssignRobot = remotes:WaitForChild(RemoteNames.RequestAssignRobot) :: RemoteEvent
	local requestSellRobot = remotes:WaitForChild(RemoteNames.RequestSellRobot) :: RemoteEvent
	local requestUpgrade = remotes:WaitForChild(RemoteNames.RequestUpgrade) :: RemoteEvent
	local requestUnlockZone = remotes:WaitForChild(RemoteNames.RequestUnlockZone) :: RemoteEvent
	local actionResult = remotes:WaitForChild(RemoteNames.ActionResult) :: RemoteEvent

	local gui = Instance.new("ScreenGui")
	gui.Name = "StudioSecurityTestUI"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 1001
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(1, 0)
	panel.Position = UDim2.new(1, -565, 0, 72)
	panel.Size = UDim2.fromOffset(255, 405)
	panel.BackgroundColor3 = Color3.fromRGB(24, 27, 34)
	panel.BorderSizePixel = 0
	panel.Parent = gui

	local panelCorner = Instance.new("UICorner")
	panelCorner.CornerRadius = UDim.new(0, 10)
	panelCorner.Parent = panel

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 10)
	padding.PaddingBottom = UDim.new(0, 10)
	padding.PaddingLeft = UDim.new(0, 10)
	padding.PaddingRight = UDim.new(0, 10)
	padding.Parent = panel

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 6)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = panel

	local title = Instance.new("TextLabel")
	title.LayoutOrder = 0
	title.Size = UDim2.new(1, 0, 0, 24)
	title.BackgroundTransparency = 1
	title.Font = Enum.Font.GothamBold
	title.Text = "STUDIO SECURITY QA"
	title.TextColor3 = Color3.fromRGB(245, 247, 250)
	title.TextSize = 12
	title.Parent = panel

	local status = Instance.new("TextLabel")
	status.LayoutOrder = 1
	status.Size = UDim2.new(1, 0, 0, 24)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.Text = "Ready — use 2 local clients for Run All"
	status.TextColor3 = Color3.fromRGB(170, 178, 190)
	status.TextSize = 10
	status.TextWrapped = true
	status.Parent = panel

	makeButton(panel, "RUN ALL SECURITY QA", 2, function()
		status.Text = "Running full security QA..."
		testRemote:FireServer("RunAll")
	end)
	makeButton(panel, "RUN HOSTILE CLIENT", 3, function()
		status.Text = "Running hostile-client suite..."
		testRemote:FireServer("RunHostileSuite")
	end)
	makeButton(panel, "RUN SALVAGE RACE", 4, function()
		status.Text = "Running synchronized salvage race..."
		testRemote:FireServer("RunSalvageRace")
	end)

	local output = Instance.new("TextLabel")
	output.Name = "Results"
	output.LayoutOrder = 5
	output.Size = UDim2.new(1, 0, 0, 235)
	output.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	output.BorderSizePixel = 0
	output.Font = Enum.Font.Code
	output.Text = "No results yet."
	output.TextColor3 = Color3.fromRGB(190, 197, 207)
	output.TextSize = 10
	output.TextWrapped = true
	output.TextXAlignment = Enum.TextXAlignment.Left
	output.TextYAlignment = Enum.TextYAlignment.Top
	output.Parent = panel

	local outputCorner = Instance.new("UICorner")
	outputCorner.CornerRadius = UDim.new(0, 7)
	outputCorner.Parent = output
	local outputPadding = Instance.new("UIPadding")
	outputPadding.PaddingTop = UDim.new(0, 8)
	outputPadding.PaddingBottom = UDim.new(0, 8)
	outputPadding.PaddingLeft = UDim.new(0, 8)
	outputPadding.PaddingRight = UDim.new(0, 8)
	outputPadding.Parent = output

	local logLines: { string } = {}
	local function appendLog(line: string)
		table.insert(logLines, line)
		while #logLines > LOG_LINE_LIMIT do
			table.remove(logLines, 1)
		end
		output.Text = table.concat(logLines, "\n")
	end

	testRemote.OnClientEvent:Connect(function(kind, first, second, third)
		if kind == "SuiteStatus" then
			status.Text = tostring(first)
			return
		end
		if kind == "CaseResult" then
			local name = tostring(first)
			local passed = second == true
			local detail = tostring(third)
			appendLog(("[%s] %s\n  %s"):format(if passed then "PASS" else "FAIL", name, detail))
			return
		end
		if kind == "RaceGo" then
			local nodeId = first
			local targetTime = second
			if typeof(nodeId) ~= "string" or typeof(targetTime) ~= "number" then
				return
			end
			task.spawn(function()
				while Workspace:GetServerTimeNow() < targetTime do
					RunService.Heartbeat:Wait()
				end
				requestCollect:FireServer(nodeId)
			end)
			return
		end
		if kind ~= "Execute" then
			return
		end

		local token = first
		local caseName = second
		local payload = third
		if typeof(token) ~= "string" or typeof(caseName) ~= "string" then
			return
		end

		task.spawn(function()
			if caseName == "InvalidPayloads" then
				requestCollect:FireServer({ Forged = true })
				requestCollect:FireServer(string.rep("X", 65))
				requestCollect:FireServer("__missing_salvage__")
				requestUpgrade:FireServer({ ProductId = 3713191213, PurchaseId = "forged" })
				requestUnlockZone:FireServer(0 / 0)
				requestUnlockZone:FireServer(math.huge)
				requestUnlockZone:FireServer(1e100)
				task.wait(0.2)
				fireClientDone(testRemote, token, { Completed = true })
			elseif caseName == "CollectNode" then
				if typeof(payload) == "table" then
					requestCollect:FireServer(payload.NodeId)
				end
				task.wait(0.15)
				fireClientDone(testRemote, token, { Completed = true })
			elseif caseName == "ForgeVictimRobot" then
				if typeof(payload) == "table" and typeof(payload.RobotUid) == "string" then
					requestAssignRobot:FireServer(payload.RobotUid, "Pad1")
					requestSellRobot:FireServer(payload.RobotUid)
				end
				task.wait(0.2)
				fireClientDone(testRemote, token, { Completed = true })
			elseif caseName == "DuplicateSell" then
				if typeof(payload) == "table" and typeof(payload.RobotUid) == "string" then
					requestSellRobot:FireServer(payload.RobotUid)
					requestSellRobot:FireServer(payload.RobotUid)
				end
				task.wait(0.2)
				fireClientDone(testRemote, token, { Completed = true })
			elseif caseName == "DoubleUpgrade" then
				if typeof(payload) == "table" and typeof(payload.UpgradeId) == "string" then
					requestUpgrade:FireServer(payload.UpgradeId)
					requestUpgrade:FireServer(payload.UpgradeId)
				end
				task.wait(0.2)
				fireClientDone(testRemote, token, { Completed = true })
			elseif caseName == "ZoneSkip" then
				if typeof(payload) == "table" then
					requestUnlockZone:FireServer(payload.TargetZone)
				end
				task.wait(0.15)
				fireClientDone(testRemote, token, { Completed = true })
			elseif caseName == "SpamCollect" then
				local count = 32
				if typeof(payload) == "table" and typeof(payload.Count) == "number" then
					count = math.clamp(math.floor(payload.Count), 1, 64)
				end
				local responseCount = 0
				local connection = actionResult.OnClientEvent:Connect(function(result)
					if
						typeof(result) == "table"
						and result.Action == RemoteNames.RequestCollect
					then
						responseCount += 1
					end
				end)
				for _ = 1, count do
					requestCollect:FireServer("__security_spam_missing__")
				end
				task.wait(0.35)
				connection:Disconnect()
				fireClientDone(testRemote, token, { Count = responseCount })
			else
				fireClientDone(testRemote, token, { UnknownCase = true })
			end
		end)
	end)
end

return StudioSecurityTestController
