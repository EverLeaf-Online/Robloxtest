--!strict

local HttpService = game:GetService("HttpService")
local RunService = game:GetService("RunService")

local DiscordWebhookService = {}

local SECRET_NAME = "SCRAPBOT_DISCORD_WEBHOOK_SECRET"
local ENDPOINT_URL = "https://everleafms.online/roblox/events"
local MAX_TITLE_CHARACTERS = 256
local MAX_DESCRIPTION_CHARACTERS = 4000

local function normalizeText(value: string, maxCharacters: number): string?
	local trimmed = string.match(value, "^%s*(.-)%s*$") or ""
	if trimmed == "" then
		return nil
	end

	local length = utf8.len(trimmed)
	if length == nil then
		return nil
	end
	if length <= maxCharacters then
		return trimmed
	end

	local byteIndex = utf8.offset(trimmed, maxCharacters + 1)
	if byteIndex == nil then
		return trimmed
	end
	return string.sub(trimmed, 1, byteIndex - 1)
end

function DiscordWebhookService.SendAnnouncement(title: string, description: string): boolean
	if RunService:IsStudio() then
		return false
	end

	local safeTitle = normalizeText(title, MAX_TITLE_CHARACTERS)
	local safeDescription = normalizeText(description, MAX_DESCRIPTION_CHARACTERS)
	if safeTitle == nil or safeDescription == nil then
		warn("[DiscordWebhookService] Refused empty or invalid announcement payload")
		return false
	end

	local secretOk, secretOrError = pcall(HttpService.GetSecret, HttpService, SECRET_NAME)
	if not secretOk then
		warn(
			("[DiscordWebhookService] Failed to load secret %s: %s"):format(
				SECRET_NAME,
				tostring(secretOrError)
			)
		)
		return false
	end

	local body = HttpService:JSONEncode({
		title = safeTitle,
		description = safeDescription,
	})

	local requestOk, responseOrError = pcall(HttpService.RequestAsync, HttpService, {
		Url = ENDPOINT_URL,
		Method = "POST",
		Headers = {
			["Content-Type"] = "application/json",
			["x-roblox-webhook-secret"] = secretOrError,
		},
		Body = body,
	})

	if not requestOk then
		warn(("[DiscordWebhookService] Request failed: %s"):format(tostring(responseOrError)))
		return false
	end

	local response = responseOrError
	if not response.Success then
		warn(
			("[DiscordWebhookService] Endpoint returned HTTP %d (%s)"):format(
				response.StatusCode,
				response.StatusMessage
			)
		)
		return false
	end

	return true
end

return DiscordWebhookService
