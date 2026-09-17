--!strict

local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local NotificationOptInController = {}
local initialized = false

local player = Players.LocalPlayer

local function setStatus(status: string)
	player:SetAttribute("NotificationOptInStatus", status)
	player:SetAttribute("NotificationOptInStatusAt", os.time())
	print(("[NotificationOptIn] %s"):format(status))
end

local function promptIfEligible()
	setStatus("WAITING_FOR_DELAY")
	task.wait(GameConfig.Engagement.NotificationOptInDelaySeconds)
	setStatus("CHECKING_ELIGIBILITY")

	local ok, canPromptOrError = pcall(function()
		return ExperienceNotificationService:CanPromptOptInAsync()
	end)
	if not ok then
		setStatus("ELIGIBILITY_API_ERROR")
		warn(("[NotificationOptIn] Eligibility check failed: %s"):format(tostring(canPromptOrError)))
		return
	end
	if canPromptOrError ~= true then
		-- Roblox does not expose the exact reason. This includes users who already
		-- opted in, users prompted within the last 30 days, and other ineligible users.
		setStatus("PROMPT_UNAVAILABLE")
		return
	end

	setStatus("ELIGIBLE")
	local promptOk, promptError = pcall(function()
		ExperienceNotificationService:PromptOptIn()
	end)
	if not promptOk then
		setStatus("PROMPT_API_ERROR")
		warn(("[NotificationOptIn] Prompt failed: %s"):format(tostring(promptError)))
		return
	end

	setStatus("PROMPT_REQUESTED")
end

function NotificationOptInController.Init()
	if initialized then
		return
	end
	initialized = true

	ExperienceNotificationService.OptInPromptClosed:Connect(function()
		-- The engine event has no accepted/declined result payload, so do not infer one.
		setStatus("PROMPT_CLOSED")
	end)

	task.spawn(promptIfEligible)
end

return NotificationOptInController
