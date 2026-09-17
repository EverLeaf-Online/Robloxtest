--!strict

local ExperienceNotificationService = game:GetService("ExperienceNotificationService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local NotificationOptInController = {}
local initialized = false

local function promptIfEligible()
	task.wait(GameConfig.Engagement.NotificationOptInDelaySeconds)

	local ok, canPromptOrError = pcall(function()
		return ExperienceNotificationService:CanPromptOptInAsync()
	end)
	if not ok then
		warn(("[NotificationOptIn] Eligibility check failed: %s"):format(tostring(canPromptOrError)))
		return
	end
	if canPromptOrError ~= true then
		return
	end

	local promptOk, promptError = pcall(function()
		ExperienceNotificationService:PromptOptIn()
	end)
	if not promptOk then
		warn(("[NotificationOptIn] Prompt failed: %s"):format(tostring(promptError)))
	end
end

function NotificationOptInController.Init()
	if initialized then
		return
	end
	initialized = true
	task.spawn(promptIfEligible)
end

return NotificationOptInController
