--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Robots = require(ReplicatedStorage.Shared.Config.Robots)
local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)

local ProfileTypes = require(script.Parent.Parent.Data.ProfileTypes)
local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local RateLimiter = require(script.Parent.RateLimiter)
local WorldService = require(script.Parent.WorldService)

local StudioSecurityTestService = {}
local initialized = false

local REMOTE_NAME = "StudioSecurityTest"
local CLIENT_TIMEOUT_SECONDS = 4
local RACE_SETTLE_SECONDS = 1.25
local TEMP_ROBOT_ID = "TinScout"

local suiteRunning: { [Player]: boolean } = {}
local pendingByToken: {
	[string]: {
		Event: BindableEvent,
		Player: Player,
		Response: any?,
	},
} =
	{}
local tokenSequence = 0
local testRemote: RemoteEvent? = nil

type ProfileData = ProfileTypes.ProfileData

type CharacterState = {
	Character: Model,
	Pivot: CFrame,
}

type Fingerprint = {
	Credits: number,
	MaterialTotal: number,
	RobotCount: number,
	AssignmentCount: number,
	StorageLevel: number,
	Zone: number,
	Tokens: number,
	ReceiptCount: number,
	StarterPackClaimed: boolean,
	PersonalOverclockUntil: number,
	ServerOverclockUntil: number,
	ServerOverclockLeaseId: string,
	FirstScrap: boolean,
}

local function getRemote(): RemoteEvent
	assert(testRemote ~= nil, "Studio security test remote is not initialized")
	return testRemote :: RemoteEvent
end

local function report(player: Player, name: string, passed: boolean, detail: string)
	getRemote():FireClient(player, "CaseResult", name, passed, detail)
end

local function suiteStatus(player: Player, text: string)
	getRemote():FireClient(player, "SuiteStatus", text)
end

local function countEntries(dictionary: { [any]: any }): number
	local count = 0
	for _ in dictionary do
		count += 1
	end
	return count
end

local function materialTotal(data: ProfileData): number
	local total = 0
	for _, amount in data.Materials do
		total += amount
	end
	return total
end

local function fingerprint(player: Player): Fingerprint?
	local data = DataService.GetData(player)
	if data == nil then
		return nil
	end
	return {
		Credits = data.Currencies.Credits,
		MaterialTotal = materialTotal(data),
		RobotCount = countEntries(data.Robots.OwnedByUid),
		AssignmentCount = countEntries(data.Assignments.WorkPads),
		StorageLevel = data.Machines.StorageLevel,
		Zone = data.Progression.Zone,
		Tokens = data.Consumables.InstantProcessTokens,
		ReceiptCount = #data.Receipts.RecentPurchaseIds,
		StarterPackClaimed = data.Entitlements.StarterPackClaimed,
		PersonalOverclockUntil = data.Entitlements.PersonalOverclockUntil,
		ServerOverclockUntil = data.Entitlements.ServerOverclockUntil,
		ServerOverclockLeaseId = data.Entitlements.ServerOverclockLeaseId,
		FirstScrap = data.Tutorial.Milestones.FirstScrap,
	}
end

local function sameFingerprint(left: Fingerprint?, right: Fingerprint?): boolean
	if left == nil or right == nil then
		return false
	end
	return left.Credits == right.Credits
		and left.MaterialTotal == right.MaterialTotal
		and left.RobotCount == right.RobotCount
		and left.AssignmentCount == right.AssignmentCount
		and left.StorageLevel == right.StorageLevel
		and left.Zone == right.Zone
		and left.Tokens == right.Tokens
		and left.ReceiptCount == right.ReceiptCount
		and left.StarterPackClaimed == right.StarterPackClaimed
		and left.PersonalOverclockUntil == right.PersonalOverclockUntil
		and left.ServerOverclockUntil == right.ServerOverclockUntil
		and left.ServerOverclockLeaseId == right.ServerOverclockLeaseId
		and left.FirstScrap == right.FirstScrap
end

local function saveCharacter(player: Player): CharacterState?
	local character = player.Character
	if character == nil then
		return nil
	end
	return {
		Character = character,
		Pivot = character:GetPivot(),
	}
end

local function restoreCharacter(state: CharacterState?)
	if state == nil or state.Character.Parent == nil then
		return
	end
	state.Character:PivotTo(state.Pivot)
end

local function moveNear(player: Player, part: BasePart): boolean
	local character = player.Character
	if character == nil then
		return false
	end
	character:PivotTo(CFrame.new(part.Position + Vector3.new(0, 4, 0)))
	return true
end

local function moveFar(player: Player, part: BasePart): boolean
	local character = player.Character
	if character == nil then
		return false
	end
	local offset = GameConfig.World.SalvageCollectDistance + 80
	character:PivotTo(CFrame.new(part.Position + Vector3.new(0, 4, offset)))
	return true
end

local function findActiveSalvageNode(plotId: number?): (string?, BasePart?)
	for nodeId, node in WorldService.GetSalvageNodes() do
		local nodePlotId = node:GetAttribute("PlotId")
		local prompt = node:FindFirstChildOfClass("ProximityPrompt")
		if
			node.CanCollide
			and prompt ~= nil
			and prompt.Enabled
			and (plotId == nil or nodePlotId == plotId)
		then
			return nodeId, node
		end
	end
	return nil, nil
end

local function findOtherReadyPlayer(player: Player): Player?
	for _, candidate in Players:GetPlayers() do
		if candidate ~= player and DataService.IsReady(candidate) then
			return candidate
		end
	end
	return nil
end

local function nextToken(player: Player, caseName: string): string
	tokenSequence += 1
	return ("%d:%s:%d"):format(player.UserId, caseName, tokenSequence)
end

local function dispatchClient(player: Player, caseName: string, payload: any?): any?
	local token = nextToken(player, caseName)
	local event = Instance.new("BindableEvent")
	local pending = {
		Event = event,
		Player = player,
		Response = nil,
	}
	pendingByToken[token] = pending
	getRemote():FireClient(player, "Execute", token, caseName, payload)

	task.delay(CLIENT_TIMEOUT_SECONDS, function()
		if pendingByToken[token] == pending then
			pending.Response = { TimedOut = true }
			event:Fire()
		end
	end)

	event.Event:Wait()
	pendingByToken[token] = nil
	event:Destroy()
	return pending.Response
end

local function responseTimedOut(response: any?): boolean
	return typeof(response) == "table" and response.TimedOut == true
end

local function countCapturedResults(
	response: any?,
	action: string,
	success: boolean,
	code: string
): number
	if typeof(response) ~= "table" or typeof(response.Results) ~= "table" then
		return 0
	end

	local count = 0
	for _, result in response.Results do
		if
			typeof(result) == "table"
			and result.Action == action
			and result.Success == success
			and result.Code == code
		then
			count += 1
		end
	end
	return count
end

local function hasAssignedRobot(data: ProfileData, robotUid: string): boolean
	for _, assignedUid in data.Assignments.WorkPads do
		if assignedUid == robotUid then
			return true
		end
	end
	return false
end

local function mutateProfile(player: Player, callback: (ProfileData) -> ())
	DataService.Transaction(player, function(data)
		callback(data)
		return true, true
	end)
end

local function runInvalidPayloadCase(player: Player)
	RateLimiter.Forget(player)
	local before = fingerprint(player)
	local response = dispatchClient(player, "InvalidPayloads", nil)
	task.wait(0.2)
	local passed = sameFingerprint(before, fingerprint(player)) and not responseTimedOut(response)
	report(
		player,
		"Malformed / forged payloads",
		passed,
		if passed
			then "NaN/inf/huge IDs and fake purchase-like payloads were rejected"
			else "Authoritative profile changed or client timed out"
	)
end

local function runDistantSalvageCase(player: Player)
	local nodeId, node = findActiveSalvageNode(PlotService.GetPlotId(player))
	if nodeId == nil or node == nil then
		report(player, "Distant salvage", false, "No active salvage node available")
		return
	end

	local characterState = saveCharacter(player)
	if not moveFar(player, node) then
		report(player, "Distant salvage", false, "Character unavailable")
		return
	end

	RateLimiter.Forget(player)
	local before = fingerprint(player)
	local response = dispatchClient(player, "CollectNode", { NodeId = nodeId })
	task.wait(0.15)
	local passed = sameFingerprint(before, fingerprint(player)) and not responseTimedOut(response)
	restoreCharacter(characterState)
	report(
		player,
		"Distant salvage",
		passed,
		if passed then "Out-of-range collection was rejected" else "Unexpected mutation or timeout"
	)
end

local function runForgedRobotCase(player: Player)
	local victim = findOtherReadyPlayer(player)
	local console = PlotService.GetBotConsole(player)
	if victim == nil then
		report(player, "Cross-player robot ownership", false, "Requires a second local client")
		return
	end
	if console == nil then
		report(player, "Cross-player robot ownership", false, "Attacker plot is unavailable")
		return
	end

	local attackerData = DataService.GetData(player)
	local victimData = DataService.GetData(victim)
	if attackerData == nil or victimData == nil then
		report(player, "Cross-player robot ownership", false, "Profiles unavailable")
		return
	end

	local characterState = saveCharacter(player)
	if not moveNear(player, console) then
		report(player, "Cross-player robot ownership", false, "Character unavailable")
		return
	end

	local tempUid = ("StudioVictim%d"):format(victim.UserId)
	while
		attackerData.Robots.OwnedByUid[tempUid] ~= nil
		or victimData.Robots.OwnedByUid[tempUid] ~= nil
	do
		tempUid ..= "X"
	end

	mutateProfile(victim, function(data)
		data.Robots.OwnedByUid[tempUid] = {
			RobotId = TEMP_ROBOT_ID,
			AcquiredAt = os.time(),
		}
	end)

	RateLimiter.Forget(player)
	local response = dispatchClient(player, "ForgeVictimRobot", { RobotUid = tempUid })
	local currentAttackerData = DataService.GetData(player)
	local currentVictimData = DataService.GetData(victim)
	local victimStillOwns = currentVictimData ~= nil
		and currentVictimData.Robots.OwnedByUid[tempUid] ~= nil
	local attackerDoesNotOwn = currentAttackerData ~= nil
		and currentAttackerData.Robots.OwnedByUid[tempUid] == nil
	local attackerDidNotAssign = currentAttackerData ~= nil
		and not hasAssignedRobot(currentAttackerData, tempUid)
	local assignRejected = countCapturedResults(
		response,
		RemoteNames.RequestAssignRobot,
		false,
		"ROBOT_NOT_OWNED"
	) == 1
	local sellRejected = countCapturedResults(
		response,
		RemoteNames.RequestSellRobot,
		false,
		"ROBOT_NOT_OWNED"
	) == 1

	mutateProfile(victim, function(data)
		data.Robots.OwnedByUid[tempUid] = nil
	end)
	restoreCharacter(characterState)

	local passed = victimStillOwns
		and attackerDoesNotOwn
		and attackerDidNotAssign
		and assignRejected
		and sellRejected
		and not responseTimedOut(response)
	report(
		player,
		"Cross-player robot ownership",
		passed,
		if passed
			then "Victim kept robot; forged assign/sell both returned ROBOT_NOT_OWNED"
			else ("victimOwns=%s attackerOwns=%s attackerAssigned=%s assignRejected=%s sellRejected=%s timeout=%s"):format(
				tostring(victimStillOwns),
				tostring(not attackerDoesNotOwn),
				tostring(not attackerDidNotAssign),
				tostring(assignRejected),
				tostring(sellRejected),
				tostring(responseTimedOut(response))
			)
	)
end

local function runDuplicateSellCase(player: Player)
	local console = PlotService.GetBotConsole(player)
	local data = DataService.GetData(player)
	local definition = Robots.Definitions[TEMP_ROBOT_ID]
	if console == nil or data == nil or definition == nil then
		report(player, "Duplicate robot sell", false, "Required test state unavailable")
		return
	end

	local characterState = saveCharacter(player)
	if not moveNear(player, console) then
		report(player, "Duplicate robot sell", false, "Character unavailable")
		return
	end

	local tempUid = ("StudioSell%d"):format(player.UserId)
	local originalRobot = data.Robots.OwnedByUid[tempUid]

	mutateProfile(player, function(profile)
		profile.Robots.OwnedByUid[tempUid] = {
			RobotId = TEMP_ROBOT_ID,
			AcquiredAt = os.time(),
		}
	end)

	RateLimiter.Forget(player)
	local response = dispatchClient(player, "DuplicateSell", { RobotUid = tempUid })
	local after = DataService.GetData(player)
	local robotRemoved = after ~= nil and after.Robots.OwnedByUid[tempUid] == nil
	local recycleSuccesses =
		countCapturedResults(response, RemoteNames.RequestSellRobot, true, "ROBOT_RECYCLED")
	local duplicateRejections =
		countCapturedResults(response, RemoteNames.RequestSellRobot, false, "ROBOT_NOT_OWNED")
	local passed = robotRemoved
		and recycleSuccesses == 1
		and duplicateRejections == 1
		and not responseTimedOut(response)

	mutateProfile(player, function(profile)
		profile.Robots.OwnedByUid[tempUid] = originalRobot
	end)
	restoreCharacter(characterState)
	report(
		player,
		"Duplicate robot sell",
		passed,
		if passed
			then "One ROBOT_RECYCLED success followed by one ROBOT_NOT_OWNED rejection"
			else ("robotRemoved=%s recycled=%d rejected=%d timeout=%s"):format(
				tostring(robotRemoved),
				recycleSuccesses,
				duplicateRejections,
				tostring(responseTimedOut(response))
			)
	)
end

local function runRepeatedUpgradeCase(player: Player)
	local console = PlotService.GetUpgradeConsole(player)
	local data = DataService.GetData(player)
	local definition = Upgrades.Storage
	if console == nil or data == nil or definition == nil then
		report(player, "Repeated max-edge upgrade", false, "Required test state unavailable")
		return
	end

	local characterState = saveCharacter(player)
	if not moveNear(player, console) then
		report(player, "Repeated max-edge upgrade", false, "Character unavailable")
		return
	end

	local originalLevel = data.Machines.StorageLevel
	local originalCredits = data.Currencies.Credits
	local maxLevel = #definition.Levels
	local priorLevel = maxLevel - 1
	local finalCost = definition.Levels[maxLevel].CostCredits
	local startingCredits = finalCost + 5_000

	mutateProfile(player, function(profile)
		profile.Machines.StorageLevel = priorLevel
		profile.Currencies.Credits = startingCredits
	end)

	RateLimiter.Forget(player)
	local response = dispatchClient(player, "DoubleUpgrade", { UpgradeId = "Storage" })
	task.wait(0.25)
	local after = DataService.GetData(player)
	local passed = after ~= nil
		and after.Machines.StorageLevel == maxLevel
		and after.Currencies.Credits == startingCredits - finalCost
		and not responseTimedOut(response)

	mutateProfile(player, function(profile)
		profile.Machines.StorageLevel = originalLevel
		profile.Currencies.Credits = originalCredits
	end)
	restoreCharacter(characterState)
	report(
		player,
		"Repeated max-edge upgrade",
		passed,
		if passed
			then "Final level and cost applied exactly once"
			else "Upgrade duplicated or client timed out"
	)
end

local function runZoneSkipCase(player: Player)
	local plotId = PlotService.GetPlotId(player)
	local gate = if plotId ~= nil then WorldService.GetPlotZoneGate(plotId, 2) else nil
	local data = DataService.GetData(player)
	if gate == nil or data == nil then
		report(player, "Zone skip", false, "Zone 2 gate or profile unavailable")
		return
	end

	local characterState = saveCharacter(player)
	if not moveNear(player, gate) then
		report(player, "Zone skip", false, "Character unavailable")
		return
	end

	local originalZone = data.Progression.Zone
	local originalCredits = data.Currencies.Credits
	local originalRobotsBuilt = data.Stats.LifetimeRobotsBuilt
	local originalGoalSeen = data.Tutorial.Milestones.FirstZoneGoalSeen
	local originalUnlocked = data.Tutorial.Milestones.FirstZoneUnlock

	mutateProfile(player, function(profile)
		profile.Progression.Zone = 1
		profile.Currencies.Credits = 0
		profile.Stats.LifetimeRobotsBuilt = 0
		profile.Tutorial.Milestones.FirstZoneGoalSeen = false
		profile.Tutorial.Milestones.FirstZoneUnlock = false
	end)

	RateLimiter.Forget(player)
	local response = dispatchClient(player, "ZoneSkip", { TargetZone = 2 })
	task.wait(0.2)
	local after = DataService.GetData(player)
	local passed = after ~= nil
		and after.Progression.Zone == 1
		and after.Currencies.Credits == 0
		and not responseTimedOut(response)

	mutateProfile(player, function(profile)
		profile.Progression.Zone = originalZone
		profile.Currencies.Credits = originalCredits
		profile.Stats.LifetimeRobotsBuilt = originalRobotsBuilt
		profile.Tutorial.Milestones.FirstZoneGoalSeen = originalGoalSeen
		profile.Tutorial.Milestones.FirstZoneUnlock = originalUnlocked
	end)
	restoreCharacter(characterState)
	report(
		player,
		"Zone skip",
		passed,
		if passed then "Unlock requirements were enforced" else "Locked zone advanced or timed out"
	)
end

local function runRateLimitCase(player: Player)
	RateLimiter.Forget(player)
	local response = dispatchClient(player, "SpamCollect", { Count = 32 })
	local responseCount = if typeof(response) == "table"
			and typeof(response.Count) == "number"
		then response.Count
		else -1
	local capacity = GameConfig.Networking.RateLimits.RequestCollect.Capacity
	local passed = responseCount > 0 and responseCount <= capacity + 1
	report(
		player,
		"RemoteEvent collect spam",
		passed,
		("Observed %d responses for 32 requests; burst capacity %d"):format(responseCount, capacity)
	)
end

local function runHostileSuite(player: Player)
	if suiteRunning[player] then
		return
	end
	suiteRunning[player] = true
	suiteStatus(player, "Running hostile-client suite...")

	runInvalidPayloadCase(player)
	runDistantSalvageCase(player)
	runForgedRobotCase(player)
	runDuplicateSellCase(player)
	runRepeatedUpgradeCase(player)
	runZoneSkipCase(player)
	runRateLimitCase(player)

	suiteStatus(player, "Hostile-client suite complete")
	suiteRunning[player] = nil
end

local function copyMaterials(data: ProfileData): { [string]: number }
	return table.clone(data.Materials)
end

local function restoreMaterials(data: ProfileData, values: { [string]: number })
	for materialId in data.Materials do
		data.Materials[materialId] = nil
	end
	for materialId, amount in values do
		data.Materials[materialId] = amount
	end
end

local function zeroMaterials(data: ProfileData)
	for materialId in data.Materials do
		data.Materials[materialId] = 0
	end
end

local function runSalvageRace(player: Player)
	if suiteRunning[player] then
		return
	end

	local secondPlayer = findOtherReadyPlayer(player)
	local ownedPlotId = PlotService.GetPlotId(player)
	local nodeId, node = findActiveSalvageNode(ownedPlotId)
	if secondPlayer == nil then
		report(player, "Private salvage isolation", false, "Start a 2-player local server first")
		return
	end
	if nodeId == nil or node == nil then
		report(player, "Private salvage isolation", false, "No active owned salvage node available")
		return
	end

	local firstData = DataService.GetData(player)
	local secondData = DataService.GetData(secondPlayer)
	if firstData == nil or secondData == nil then
		report(player, "Private salvage isolation", false, "Profiles unavailable")
		return
	end

	suiteRunning[player] = true
	suiteStatus(player, "Running private salvage isolation test...")

	local firstCharacter = saveCharacter(player)
	local secondCharacter = saveCharacter(secondPlayer)
	local firstMaterials = copyMaterials(firstData)
	local secondMaterials = copyMaterials(secondData)
	local firstMilestone = firstData.Tutorial.Milestones.FirstScrap
	local secondMilestone = secondData.Tutorial.Milestones.FirstScrap

	mutateProfile(player, function(data)
		zeroMaterials(data)
		data.Tutorial.Milestones.FirstScrap = false
	end)
	mutateProfile(secondPlayer, function(data)
		zeroMaterials(data)
		data.Tutorial.Milestones.FirstScrap = false
	end)
	moveNear(player, node)
	moveNear(secondPlayer, node)
	RateLimiter.Forget(player)
	RateLimiter.Forget(secondPlayer)

	local targetTime = Workspace:GetServerTimeNow() + 0.75
	getRemote():FireClient(player, "RaceGo", nodeId, targetTime)
	getRemote():FireClient(secondPlayer, "RaceGo", nodeId, targetTime)
	task.wait(RACE_SETTLE_SECONDS)

	local firstAfter = DataService.GetData(player)
	local secondAfter = DataService.GetData(secondPlayer)
	local firstTotal = if firstAfter then materialTotal(firstAfter) else 0
	local secondTotal = if secondAfter then materialTotal(secondAfter) else 0
	local exactlyOneWinner = (firstTotal > 0) ~= (secondTotal > 0)
	local nodeConsumed = not node.CanCollide
	local passed = exactlyOneWinner and nodeConsumed

	mutateProfile(player, function(data)
		restoreMaterials(data, firstMaterials)
		data.Tutorial.Milestones.FirstScrap = firstMilestone
	end)
	mutateProfile(secondPlayer, function(data)
		restoreMaterials(data, secondMaterials)
		data.Tutorial.Milestones.FirstScrap = secondMilestone
	end)
	restoreCharacter(firstCharacter)
	restoreCharacter(secondCharacter)

	report(
		player,
		"Private salvage isolation",
		passed,
		("P1 materials=%d, P2 materials=%d, nodeConsumed=%s"):format(
			firstTotal,
			secondTotal,
			tostring(nodeConsumed)
		)
	)
	suiteStatus(player, "Private salvage isolation complete")
	suiteRunning[player] = nil
end

local function finishPending(player: Player, token: any, response: any?)
	if typeof(token) ~= "string" then
		return
	end
	local pending = pendingByToken[token]
	if pending == nil or pending.Player ~= player then
		return
	end
	pending.Response = response
	pending.Event:Fire()
end

function StudioSecurityTestService.Init()
	if initialized then
		return
	end
	initialized = true
	if not RunService:IsStudio() then
		return
	end

	local remotes = ReplicatedStorage:WaitForChild("Remotes")
	local existing = remotes:FindFirstChild(REMOTE_NAME)
	local remote: RemoteEvent
	if existing ~= nil then
		assert(existing:IsA("RemoteEvent"), ("%s must be a RemoteEvent"):format(REMOTE_NAME))
		remote = existing
	else
		remote = Instance.new("RemoteEvent")
		remote.Name = REMOTE_NAME
		remote.Parent = remotes
	end
	testRemote = remote

	remote.OnServerEvent:Connect(function(player, action, token, response)
		if not RunService:IsStudio() or not DataService.IsReady(player) then
			return
		end
		if action == "ClientDone" then
			finishPending(player, token, response)
			return
		end
		if action == "RunHostileSuite" then
			task.spawn(runHostileSuite, player)
		elseif action == "RunSalvageRace" then
			task.spawn(runSalvageRace, player)
		elseif action == "RunAll" then
			task.spawn(function()
				runHostileSuite(player)
				runSalvageRace(player)
			end)
		end
	end)

	Players.PlayerRemoving:Connect(function(player)
		suiteRunning[player] = nil
		for token, pending in pendingByToken do
			if pending.Player == player then
				pending.Response = { TimedOut = true, PlayerLeft = true }
				pending.Event:Fire()
				pendingByToken[token] = nil
			end
		end
	end)
end

return StudioSecurityTestService
