--!strict

local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RobloxIds = require(ReplicatedStorage.Shared.Config.RobloxIds)

local NotificationService = {}
local initialized = false
local openCloudNotification: any? = nil
local warnedMissingPackage = false

local function resolveOpenCloudNotification(): any?
	if openCloudNotification ~= nil then
		return openCloudNotification
	end

	local openCloud = ServerScriptService:FindFirstChild("OpenCloud")
	local v2 = openCloud and openCloud:FindFirstChild("V2")
	local module = v2 and v2:FindFirstChild("UserNotification")
	if module == nil or not module:IsA("ModuleScript") then
		if not warnedMissingPackage and not RunService:IsStudio() then
			warn("[NotificationService] ServerScriptService.OpenCloud.V2.UserNotification is not installed; experience notifications are disabled")
			warnedMissingPackage = true
		end
		return nil
	end

	local ok, result = pcall(require, module)
	if not ok then
		warn(("[NotificationService] Failed requiring OpenCloud notification package: %s"):format(tostring(result)))
		return nil
	end
	openCloudNotification = result
	return result
end

local function messageIdFor(notificationName: string): string?
	local id = RobloxIds.Notifications[notificationName]
	if typeof(id) ~= "string" or id == "" then
		return nil
	end
	return id
end

function NotificationService.SendToUser(
	userId: number,
	notificationName: string,
	launchData: string?
): (boolean, string)
	if userId <= 0 or userId % 1 ~= 0 then
		return false, "INVALID_USER_ID"
	end

	local messageId = messageIdFor(notificationName)
	if messageId == nil then
		return false, "UNKNOWN_NOTIFICATION"
	end

	if RunService:IsStudio() then
		return true, "STUDIO_SKIPPED"
	end

	local api = resolveOpenCloudNotification()
	if api == nil then
		return false, "OPEN_CLOUD_PACKAGE_MISSING"
	end

	local request: any = {
		payload = {
			messageId = messageId,
			type = "MOMENT",
			analyticsData = {
				category = notificationName,
			},
		},
	}
	if launchData ~= nil and launchData ~= "" then
		request.payload.joinExperience = {
			launchData = string.sub(launchData, 1, 200),
		}
	end

	local ok, result = pcall(function()
		return api.createUserNotification(userId, request)
	end)
	if not ok then
		warn(("[NotificationService] %s send failed for %d: %s"):format(notificationName, userId, tostring(result)))
		return false, "SEND_FAILED"
	end

	if typeof(result) ~= "table" then
		return false, "INVALID_RESULT"
	end
	if result.statusCode ~= 200 then
		local message = "unknown"
		if typeof(result.error) == "table" and result.error.message ~= nil then
			message = tostring(result.error.message)
		end
		warn(("[NotificationService] %s rejected for %d (%s): %s"):format(
			notificationName,
			userId,
			tostring(result.statusCode),
			message
		))
		return false, "NOT_DELIVERED"
	end

	return true, "SENT"
end

function NotificationService.Init()
	if initialized then
		return
	end
	initialized = true
	resolveOpenCloudNotification()
end

return NotificationService
