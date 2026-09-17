--!strict

local HttpService = game:GetService("HttpService")
local MessagingService = game:GetService("MessagingService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TextService = game:GetService("TextService")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)

local NotificationService = require(script.Parent.NotificationService)
local RemoteService = require(script.Parent.RemoteService)
local StateService = require(script.Parent.StateService)

local AdminBroadcastService = {}
local initialized = false

local TOPIC = "ScrapToBot_NewContent_v1"
local MAX_MESSAGE_CHARACTERS = 120
local SEEN_BROADCAST_CAP = 100

local seenBroadcasts: { [string]: boolean } = {}
local seenOrder: { string } = {}

local function rememberBroadcast(id: string): boolean
	if seenBroadcasts[id] == true then
		return false
	end

	seenBroadcasts[id] = true
	table.insert(seenOrder, id)
	while #seenOrder > SEEN_BROADCAST_CAP do
		local expired = table.remove(seenOrder, 1)
		seenBroadcasts[expired] = nil
	end
	return true
end

local function isCreator(player: Player): boolean
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end

	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rankOrError = pcall(player.GetRankInGroup, player, game.CreatorId)
		if not ok then
			warn(
				("[AdminBroadcastService] Failed creator group-rank check for %d: %s"):format(
					player.UserId,
					tostring(rankOrError)
				)
			)
			return false
		end
		return rankOrError >= 255
	end

	return false
end

local function normalizeMessage(text: string): string?
	local trimmed = string.match(text, "^%s*(.-)%s*$") or ""
	if trimmed == "" then
		return nil
	end

	local characterCount = utf8.len(trimmed)
	if characterCount == nil or characterCount > MAX_MESSAGE_CHARACTERS then
		return nil
	end
	return trimmed
end

local function filterForBroadcast(player: Player, text: string): (string?, string)
	if RunService:IsStudio() then
		return text, "STUDIO_UNFILTERED"
	end

	local filterOk, filterResultOrError = pcall(
		TextService.FilterStringAsync,
		TextService,
		text,
		player.UserId,
		Enum.TextFilterContext.PublicChat
	)
	if not filterOk then
		warn(
			("[AdminBroadcastService] Text filtering failed for %d: %s"):format(
				player.UserId,
				tostring(filterResultOrError)
			)
		)
		return nil, "FILTER_FAILED"
	end

	local broadcastOk, filteredOrError = pcall(
		(filterResultOrError :: TextFilterResult).GetNonChatStringForBroadcastAsync,
		filterResultOrError
	)
	if not broadcastOk or typeof(filteredOrError) ~= "string" or filteredOrError == "" then
		warn(
			("[AdminBroadcastService] Broadcast filtering failed for %d: %s"):format(
				player.UserId,
				tostring(filteredOrError)
			)
		)
		return nil, "FILTER_FAILED"
	end

	return filteredOrError, "FILTERED"
end

local function handleBroadcast(payload: any)
	if typeof(payload) ~= "table" then
		return
	end

	local id = payload.Id
	local text = payload.Text
	if typeof(id) ~= "string" or id == "" or typeof(text) ~= "string" or text == "" then
		return
	end
	if not rememberBroadcast(id) then
		return
	end

	RemoteService.Get(RemoteNames.Announcement):FireAllClients(text)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			NotificationService.SendToUser(player.UserId, "NewContent", "new-content")
		end)
	end
end

function AdminBroadcastService.Init()
	if initialized then
		return
	end
	initialized = true

	local subscribeOk, subscriptionOrError = pcall(
		MessagingService.SubscribeAsync,
		MessagingService,
		TOPIC,
		function(message)
			handleBroadcast(message.Data)
		end
	)
	if not subscribeOk then
		warn(
			("[AdminBroadcastService] MessagingService subscription failed: %s"):format(
				tostring(subscriptionOrError)
			)
		)
	end

	RemoteService.BindRequest(RemoteNames.RequestAdminBroadcast, function(player: Player, text: any)
		if not isCreator(player) then
			StateService.ActionResult(player, "AdminBroadcast", false, "NOT_AUTHORIZED")
			return
		end
		if typeof(text) ~= "string" then
			StateService.ActionResult(player, "AdminBroadcast", false, "INVALID_MESSAGE")
			return
		end

		local normalized = normalizeMessage(text)
		if normalized == nil then
			StateService.ActionResult(player, "AdminBroadcast", false, "INVALID_MESSAGE")
			return
		end

		local filtered, filterCode = filterForBroadcast(player, normalized)
		if filtered == nil then
			StateService.ActionResult(player, "AdminBroadcast", false, filterCode)
			return
		end

		local payload = {
			Id = HttpService:GenerateGUID(false),
			Text = filtered,
			At = os.time(),
		}

		if RunService:IsStudio() then
			handleBroadcast(payload)
			StateService.ActionResult(player, "AdminBroadcast", true, "STUDIO_BROADCASTED")
			return
		end

		local publishOk, publishError =
			pcall(MessagingService.PublishAsync, MessagingService, TOPIC, payload)
		if not publishOk then
			warn(
				("[AdminBroadcastService] MessagingService publish failed: %s"):format(
					tostring(publishError)
				)
			)
			StateService.ActionResult(player, "AdminBroadcast", false, "PUBLISH_FAILED")
			return
		end

		StateService.ActionResult(player, "AdminBroadcast", true, "PUBLISHED")
	end)
end

return AdminBroadcastService
