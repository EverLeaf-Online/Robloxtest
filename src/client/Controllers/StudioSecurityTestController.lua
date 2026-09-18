--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)

local StudioSecurityTestController = {}
local mountedPage: Frame? = nil

local REMOTE_NAME = "StudioSecurityTest"
local REMOTE_WAIT_TIMEOUT_SECONDS = 10
local LOG_LINE_LIMIT = 12

local function makeButton(parent: Instance, label: string, order: number, callback: () -> ())
	local button = Instance.new("TextButton")
	button.Name = ("SecurityAction%d"):format(order)
	button.LayoutOrder = order
	button.Size = UDim2.new(1, 0, 0, 36)
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

type CapturedActionResult = {
	Action: string,
	Success: boolean,
	Code: string,
}

local function fireClientDone(remote: RemoteEvent, token: string, response: any?)
	remote:FireServer("ClientDone", token, response)
end

local function captureActionResults(
	actionResult: RemoteEvent,
	actions: { [string]: boolean },
	fireRequests: () -> ()
): { CapturedActionResult }
	local results: { CapturedActionResult } = {}
	local connection = actionResult.OnClientEvent:Connect(function(result)
		if typeof(result) ~= "table" then
			return
		end
		local action = result.Action
		if typeof(action) ~= "string" or actions[action] ~= true then
			return
		end
		table.insert(results, {
			Action = action,
			Success = result.Success == true,
			Code = tostring(result.Code),
		})
	end)

	fireRequests()
	task.wait(0.35)
	connection:Disconnect()
	return results
end

function StudioSecurityTestController.Mount(parent: Instance): Frame?
	if not RunService:IsStudio() then
		return nil
	end
	if mountedPage ~= nil and mountedPage.Parent ~= nil then
		return mountedPage
	end

	local remotesInstance = ReplicatedStorage:WaitForChild("Remotes", REMOTE_WAIT_TIMEOUT_SECONDS)
	if remotesInstance == nil or not remotesInstance:IsA("Folder") then
		warn("[StudioSecurityTestController] Remotes folder was not created by the server")
		return nil
	end
	local remotes = remotesInstance
	local remoteInstance = remotes:WaitForChild(REMOTE_NAME, REMOTE_WAIT_TIMEOUT_SECONDS)
	if remoteInstance == nil or not remoteInstance:IsA("RemoteEvent") then
		warn(
			("[StudioSecurityTestController] %s was not created by the server"):format(REMOTE_NAME)
		)
		return nil
	end
	local testRemote = remoteInstance

	local requestCollect = remotes:WaitForChild(RemoteNames.RequestCollect) :: RemoteEvent
	local requestAssignRobot = remotes:WaitForChild(RemoteNames.RequestAssignRobot) :: RemoteEvent
	local requestSellRobot = remotes:WaitForChild(RemoteNames.RequestSellRobot) :: RemoteEvent
	local requestUpgrade = remotes:WaitForChild(RemoteNames.RequestUpgrade) :: RemoteEvent
	local requestUnlockZone = remotes:WaitForChild(RemoteNames.RequestUnlockZone) :: RemoteEvent
	local actionResult = remotes:WaitForChild(RemoteNames.ActionResult) :: RemoteEvent

	local page = Instance.new("Frame")
	page.Name = "SecurityPage"
	page.Size = UDim2.fromScale(1, 1)
	page.BackgroundTransparency = 1
	page.Parent = parent
	mountedPage = page

	local scroll = Instance.new("ScrollingFrame")
	scroll.Name = "Scroll"
	scroll.Size = UDim2.fromScale(1, 1)
	scroll.BackgroundTransparency = 1
	scroll.BorderSizePixel = 0
	scroll.ScrollBarThickness = 6
	scroll.AutomaticCanvasSize = Enum.AutomaticSize.Y
	scroll.CanvasSize = UDim2.new()
	scroll.Parent = page

	local padding = Instance.new("UIPadding")
	padding.PaddingTop = UDim.new(0, 4)
	padding.PaddingBottom = UDim.new(0, 8)
	padding.PaddingLeft = UDim.new(0, 4)
	padding.PaddingRight = UDim.new(0, 8)
	padding.Parent = scroll

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 8)
	layout.SortOrder = Enum.SortOrder.LayoutOrder
	layout.Parent = scroll

	local status = Instance.new("TextLabel")
	status.LayoutOrder = 1
	status.Size = UDim2.new(1, 0, 0, 28)
	status.BackgroundTransparency = 1
	status.Font = Enum.Font.Gotham
	status.Text = "Ready — use 2 local clients for Run All"
	status.TextColor3 = Color3.fromRGB(170, 178, 190)
	status.TextSize = 11
	status.TextWrapped = true
	status.Parent = scroll

	makeButton(scroll, "RUN ALL SECURITY QA", 2, function()
		status.Text = "Running full security QA..."
		testRemote:FireServer("RunAll")
	end)
	makeButton(scroll, "RUN HOSTILE CLIENT", 3, function()
		status.Text = "Running hostile-client suite..."
		testRemote:FireServer("RunHostileSuite")
	end)
	makeButton(scroll, "RUN SALVAGE RACE", 4, function()
		status.Text = "Running synchronized salvage race..."
		testRemote:FireServer("RunSalvageRace")
	end)

	local output = Instance.new("TextLabel")
	output.Name = "Results"
	output.LayoutOrder = 5
	output.Size = UDim2.new(1, 0, 0, 300)
	output.BackgroundColor3 = Color3.fromRGB(18, 20, 26)
	output.BorderSizePixel = 0
	output.Font = Enum.Font.Code
	output.Text = "No results yet."
	output.TextColor3 = Color3.fromRGB(190, 197, 207)
	output.TextSize = 10
	output.TextWrapped = true
	output.TextXAlignment = Enum.TextXAlignment.Left
	output.TextYAlignment = Enum.TextYAlignment.Top
	output.Parent = scroll

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
				local results = captureActionResults(
					actionResult,
					{
						[RemoteNames.RequestAssignRobot] = true,
						[RemoteNames.RequestSellRobot] = true,
					},
					function()
						if typeof(payload) == "table" and typeof(payload.RobotUid) == "string" then
							requestAssignRobot:FireServer(payload.RobotUid, "Pad1")
							requestSellRobot:FireServer(payload.RobotUid)
						end
					end
				)
				fireClientDone(testRemote, token, { Results = results })
			elseif caseName == "DuplicateSell" then
				local results = captureActionResults(
					actionResult,
					{ [RemoteNames.RequestSellRobot] = true },
					function()
						if typeof(payload) == "table" and typeof(payload.RobotUid) == "string" then
							requestSellRobot:FireServer(payload.RobotUid)
							requestSellRobot:FireServer(payload.RobotUid)
						end
					end
				)
				fireClientDone(testRemote, token, { Results = results })
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

	return page
end

return StudioSecurityTestController
