--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)
local Robots = require(ReplicatedStorage.Shared.Config.Robots)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)

local DataService = require(script.Parent.DataService)
local PlotService = require(script.Parent.PlotService)
local RateLimiter = require(script.Parent.RateLimiter)
local StateService = require(script.Parent.StateService)
local WorldService = require(script.Parent.WorldService)

local StudioSecurityTestService = {}
local initialized = false

local REMOTE_NAME = "StudioSecurityTest"
local CLIENT_TIMEOUT_SECONDS = 4
local RACE_SETTLE_SECONDS = 1.25
local TEMP_ROBOT_ID = "TinScout"
local suiteRunning: { [Player]: boolean } = {}
local pendingByToken: { [string]: { Event: BindableEvent, Player: Player, Response: any? } } = {}
local tokenSequence = 0
local testRemote: RemoteEvent? = nil

type ProfileData = any

type CharacterState = {
	Character: Model,
	Pivot: CFrame,
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

local function deepEqual(left: any, right: any): boolean
	if typeof(left) ~= typeof(right) then
		return false
	end
	if typeof(left) ~= "table" then
		if typeof(left) == "number" and left ~= left and right ~= right then
			return true
		end
		return left == right
	end
	for key, value in left do
		if not deepEqual(value, right[key]) then
			return false
		end
	end
	for key in right do
		if left[key] == nil then
			return false
		end
	end
	return true
end

local function profileSnapshot(player: Player): any?
	local data = DataService.GetData(player)
	if data == nil then
		return nil
	end
	local snapshot = StateService.BuildSnapshot(data)
	snapshot.Security = {
		RecentPurchaseIds = table.clone(data.Receipts.RecentPurchaseIds),
		ServerOverclockUntil = data.Entitlements.ServerOverclockUntil,
		ServerOverclockLeaseId = data.Entitlements.ServerOverclockLeaseId,
	}
	return snapshot
end

local function totalMaterials(data: ProfileData): number
	local total = 0
	for _, amount in data.Materials do
		if typeof(amount) == "number" then
			total += amount
		end
	end
	return total
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

local function movePlayerNear(player: Player, part: BasePart): boolean
	local character = player.Character
	if character == nil then
		return false
	end
	character:PivotTo(CFrame.new(part.Position + Vector3.new(0, 4, 0)))
	return true
end

local function movePlayerFar(player: Player, part: BasePart): boolean
	local character = player.Character
	if character == nil then
		return false
	end
	character:PivotTo(
		CFrame.new(
			part.Position
				+ Vector3.new(0, 4, GameConfig.World.SalvageCollectDistance + 80)
		)
	)
	return true
end

local function findActiveSalvageNode(): (string?, BasePart?)
	for nodeId, node in WorldService.GetSalvageNodes() do
		if node.CanCollide and node.Transparency < 0.7 then
			return nodeId, node
		end
	end
	return nil, nil
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

local function restoreProfileFields(player: Player, callback: (ProfileData) -> ())
	DataService.Transaction(player, function(data)
		callback(data)
		return true, true
	end)
end

local function runInvalidPayloadCase(player: Player)
	RateLimiter.Forget(player)
	local before = profileSnapshot(player)
	local response = dispatchClient(player, "InvalidPayloads", nil)
	task.wait(0.2)
	local after = profileSnapshot(player)
	local passed = before ~= nil
		and after ~= nil
		and deepEqual(before, after)
		and not (typeof(response) == "table" and response.TimedOut == true)
	report(
		player,
		"Malformed / forged payloads",
		passed,
		if passed then "No authoritative profile mutation" else "Profile changed or client timed out"
	)
end

local function runDistantSalvageCase(player: Player)
	local nodeId, node = findActiveSalvageNode()
	if nodeId == nil or node == nil then
		report(player, "Distant salvage", false, "No active salvage node available")
		return
	end
	local characterState = saveCharacter(player)
	if not movePlayerFar(player, node) then
		report(player, "Distant salvage", false, "Character unavailable")
		return
	end
	RateLimiter.Forget(player)
	local before = profileSnapshot(player)
	local response = dispatchClient(player, "CollectNode", { NodeId = nodeId })
	task.wait(0.15)
	local after = profileSnapshot(player)
	restoreCharacter(characterState)
	local passed = before ~= nil
		and after ~= nil
		and deepEqual(before, after)
		and not (typeof(response) == "table" and response.TimedOut == true)
	report(
		player,
		"Distant salvage",
		passed,
		if passed then "Server rejected out-of-range collection" else "Unexpected mutation or timeout"
	)
end

local function findOtherReadyPlayer(player: Player): Player?
	for _, candidate in Players:GetPlayers() do
		if candidate ~= player and DataService.IsReady(candidate) then
			return candidate
		end
	end
	return nil
end

local function runForgedRobotCase(player: Player)
	local victim = findOtherReadyPlayer(player)
	if victim == nil then
		report(player, "Cross-player robot ownership", false, "Requires a second local client")
		return
	end
	local console = PlotService.GetBotConsole(player)
	if console == nil then
		report(player, "Cross-player robot ownership", false, "Attacker plot is unavailable")
		return
	end
	local characterState = saveCharacter(player)
	if not movePlayerNear(player, console) then
		report(player, "Cross-player robot ownership", false, "Attacker character unavailable")
		return
	end

	local tempUid = ("StudioVictim%d"):format(victim.UserId)
	local victimData = DataService.GetData(victim)
	local attackerData = DataService.GetData(player)
	if victimData == nil or attackerData == nil then
		restoreCharacter(characterState)
		report(player, "Cross-player robot ownership", false, "Profiles unavailable")
		return
	end
	while victimData.Robots.OwnedByUid[tempUid] ~= nil or attackerData.Robots.OwnedByUid[tempUid] ~= nil do
		tempUid ..= "X"
	end

	DataService.Transaction(victim, function(data)
		data.Robots.OwnedByUid[tempUid] = {
			RobotId = TEMP_ROBOT_ID,
			AcquiredAt = os.time(),
		}
		return true, true
	end)
	local attackerBefore = profileSnapshot(player)
	RateLimiter.Forget(player)
	local response = dispatchClient(player, "ForgeVictimRobot", { RobotUid = tempUid })
	task.wait(0.2)
	local attackerAfter = profileSnapshot(player)
	local victimAfter = DataService.GetData(victim)
	local victimStillOwns = victimAfter ~= nil and victimAfter.Robots.OwnedByUid[tempUid] ~= nil

	restoreProfileFields(victim, function(data)
		data.Robots.OwnedByUid[tempUid] = nil
	end)
	restoreCharacter(characterState)

	local passed = attackerBefore ~= nil
		and attackerAfter ~= nil
		and deepEqual(attackerBefore, attackerAfter)
		and victimStillOwns
		and not (typeof(response) == "table" and response.TimedOut == true)
	report(
		player,
		"Cross-player robot ownership",
		passed,
		if passed then "Forged assign/sell rejected" else "Ownership boundary failed or timed out"
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
	if not movePlayerNear(player, console) then
		report(player, "Duplicate robot sell", false, "Character unavailable")
		return
	end
	local originalCredits = data.Currencies.Credits
	local originalLifetimeCredits = data.Stats.LifetimeCredits
	local tempUid = ("StudioSell%d"):format(player.UserId)
	local originalRobot = data.Robots.OwnedByUid[tempUid]

	DataService.Transaction(player, function(profile)
		profile.Currencies.Credits = 0
		profile.Robots.OwnedByUid[tempUid] = {
			RobotId = TEMP_ROBOT_ID,
			AcquiredAt = os.time(),
		}
		return true, true
	end)
	RateLimiter.Forget(player)
	local response = dispatchClient(player, "DuplicateSell", { RobotUid = tempUid })
	task.wait(0.25)
	local after = DataService.GetData(player)
	local passed = after ~= nil
		and after.Robots.OwnedByUid[tempUid] == nil
		and after.Currencies.Credits == definition.RecycleCredits
		and not (typeof(response) == "table" and response.TimedOut == true)

	restoreProfileFields(player, function(profile)
		profile.Currencies.Credits = originalCredits
		profile.Stats.LifetimeCredits = originalLifetimeCredits
		profile.Robots.OwnedByUid[tempUid] = originalRobot
	end)
	restoreCharacter(characterState)
	report(
		player,
		"Duplicate robot sell",
		passed,
		if passed then "Exactly one recycle grant applied" else "Duplicate grant detected or timeout"
	)
end

local function runConcurrentUpgradeCase(player: Player)
	local console = PlotService.GetUpgradeConsole(player)
	local data = DataService.GetData(player)
	local definition = Upgrades.Storage
	if console == nil or data == nil or definition == nil then
		report(player, "Repeated max-edge upgrade", false, "Required test state unavailable")
		return
	end
	local characterState = saveCharacter(player)
	if not movePlayerNear(player, console) then
		report(player, "Repeated max-edge upgrade", false, "Character unavailable")
		return
	end
	local originalLevel = data.Machines.StorageLevel
	local originalCredits = data.Currencies.Credits
	local maxLevel = #definition.Levels
	local priorLevel = maxLevel - 1
	local finalCost = definition.Levels[maxLevel].CostCredits
	local startingCredits = finalCost + 5_000

	DataService.Transaction(player, function(profile)
		profile.Machines.StorageLevel = priorLevel
		profile.Currencies.Credits = startingCredits
		return true, true
	end)
	RateLimiter.Forget(player)
	local response = dispatchClient(player, "DoubleUpgrade", { UpgradeId = "Storage" })
	task.wait(0.25)
	local after = DataService.GetData(player)
	local passed = after ~= nil
		and after.Machines.StorageLevel == maxLevel
		and after.Currencies.Credits == startingCredits - finalCost
		and not (typeof(response) == "table" and response.TimedOut == true)

	restoreProfileFields(player, function(profile)
		profile.Machines.StorageLevel = originalLevel
		profile.Currencies.Credits = originalCredits
	end)
	restoreCharacter(characterState)
	report(
		player,
		"Repeated max-edge upgrade",
		passed,
		if passed then "Level and cost applied exactly once" else "Upgrade duplicated or timed out"
	)
end

local function runZoneSkipCase(player: Player)
	local gate = WorldService.GetZoneGate(2)
	local data = DataService.GetData(player)
	if gate == nil or data == nil then
		report(player, "Zone skip", false, "Zone 2 gate or profile unavailable")
		return
	end
	local characterState = saveCharacter(player)
	if not movePlayerNear(player, gate) then
		report(player, "Zone skip", false, "Character unavailable")
		return
	end
	local originalZone = data.Progression.Zone
	local originalCredits = data.Currencies.Credits
	local originalRobotsBuilt = data.Stats.LifetimeRobotsBuilt
	local originalGoalSeen = data.Tutorial.Milestones.FirstZoneGoalSeen
	local originalUnlocked = data.Tutorial.Milestones.FirstZoneUnlock

	DataService.Transaction(player, function(profile)
		profile.Progression.Zone = 1
		profile.Currencies.Credits = 0
		profile.Stats.LifetimeRobotsBuilt = 0
		profile.Tutorial.Milestones.FirstZoneGoalSeen = false
		profile.Tutorial.Milestones.FirstZoneUnlock = false
		return true, true
	end)
	RateLimiter.Forget(player)
	local response = dispatchClient(player, "ZoneSkip", { TargetZone = 2 })
	task.wait(0.2)
	local after = DataService.GetData(player)
	local passed = after ~= nil
		and after.Progression.Zone == 1
		and after.Currencies.Credits == 0
		and not (typeof(response) == "table" and response.TimedOut == true)

	restoreProfileFields(player, function(profile)
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
		if passed then "Unlock requirements enforced" else "Locked zone advanced or timed out"
	)
end

local function runRateLimitCase(player: Player)
	RateLimiter.Forget(player)
	local response = dispatchClient(player, "SpamCollect", { Count = 32 })
	local responseCount = if typeof(response) == "table" and typeof(response.Count) == "number"
		then response.Count
		else -1
	local capacity = GameConfig.Networking.RateLimits.RequestCollect.Capacity
	local passed = responseCount > 0 and responseCount <= capacity + 1
	report(
		player,
		"RemoteEvent collect spam",
		passed,
		("Observed %d server responses for 32 requests; burst capacity %d"):format(
			responseCount,
			capacity
		)
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
	runConcurrentUpgradeCase(player)
	runZoneSkipCase(player)
	runRateLimitCase(player)

	suiteStatus(player, "Hostile-client suite complete")
	suiteRunning[player] = nil
end

local function cloneMaterials(data: ProfileData): { [string]: number }
	local result: { [string]: number } = {}
	for materialId, amount in data.Materials do
		result[materialId] = amount
	end
	return result
end

local function restoreMaterials(data: ProfileData, materials: { [string]: number })
	for materialId in data.Materials do
		data.Materials[materialId] = nil
	end
	for materialId, amount in materials do
		data.Materials[materialId] = amount
	end
end

local function runSalvageRace(player: Player)
	if suiteRunning[player] then
		return
	end
	local secondPlayer = findOtherReadyPlayer(player)
	if secondPlayer == nil then
		report(player, "Same-node salvage race", false, "Start a 2-player local server first")
		return
	end
	local nodeId, node = findActiveSalvageNode()
	if nodeId == nil or node == nil then
		report(player, "Same-node salvage race", false, "No active salvage node available")
		return
	end
	local firstData = DataService.GetData(player)
	local secondData = DataService.GetData(secondPlayer)
	if firstData == nil or secondData == nil then
		report(player, "Same-node salvage race", false, "Profiles unavailable")
		return
	end

	suiteRunning[player] = true
	suiteStatus(player, "Running synchronized salvage race...")
	local firstCharacter = saveCharacter(player)
	local secondCharacter = saveCharacter(secondPlayer)
	local firstMaterials = cloneMaterials(firstData)
	local secondMaterials = cloneMaterials(secondData)
	local firstMilestone = firstData.Tutorial.Milestones.FirstScrap
	local secondMilestone = secondData.Tutorial.Milestones.FirstScrap

	restoreProfileFields(player, function(data)
		for materialId in data.Materials do
			data.Materials[materialId] = 0
		end
		data.Tutorial.Milestones.FirstScrap = false
	end)
	restoreProfileFields(secondPlayer, function(data)
		for materialId in data.Materials do
			data.Materials[materialId] = 0
		end
		data.Tutorial.Milestones.FirstScrap = false
	end)
	movePlayerNear(player, node)
	movePlayerNear(secondPlayer, node)
	RateLimiter.Forget(player)
	RateLimiter.Forget(secondPlayer)

	local targetTime = Workspace:GetServerTimeNow() + 0.75
	getRemote():FireClient(player, "RaceGo", nodeId, targetTime)
	getRemote():FireClient(secondPlayer, "RaceGo", nodeId, targetTime)
	task.wait(RACE_SETTLE_SECONDS)

	local firstAfter = DataService.GetData(player)
	local secondAfter = DataService.GetData(secondPlayer)
	local firstTotal = if firstAfter then totalMaterials(firstAfter) else 0
	local secondTotal = if secondAfter then totalMaterials(secondAfter) else 0
	local exactlyOneWinner = (firstTotal > 0) ~= (secondTotal > 0)
	local nodeConsumed = not node.CanCollide
	local passed = exactlyOneWinner and nodeConsumed

	restoreProfileFields(player, function(data)
		restoreMaterials(data, firstMaterials)
		data.Tutorial.Milestones.FirstScrap = firstMilestone
	end)
	restoreProfileFields(secondPlayer, function(data)
		restoreMaterials(data, secondMaterials)
		data.Tutorial.Milestones.FirstScrap = secondMilestone
	end)
	restoreCharacter(firstCharacter)
	restoreCharacter(secondCharacter)

	report(
		player,
		"Same-node salvage race",
		passed,
		("P1 material delta=%d, P2 material delta=%d, nodeConsumed=%s"):format(
			firstTotal,
			secondTotal,
			tostring(nodeConsumed)
		)
	)
	suiteStatus(player, "Salvage race complete")
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
				while suiteRunning[player] do
					task.wait()
				end
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
