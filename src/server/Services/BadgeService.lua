--!strict

local BadgeService = game:GetService("BadgeService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local RobloxIds = require(ReplicatedStorage.Shared.Config.RobloxIds)
local Robots = require(ReplicatedStorage.Shared.Config.Robots)

local DataService = require(script.Parent.DataService)

local EngagementBadgeService = {}
local initialized = false

local attemptedByPlayer: { [Player]: { [string]: boolean } } = {}

local BADGES = RobloxIds.Badges

local function hasRareDiscovery(data: any): boolean
	for robotId in data.Collection.RobotSeen do
		local definition = Robots.Definitions[robotId]
		if definition ~= nil and (definition.Rarity == "Rare" or definition.Rarity == "Epic") then
			return true
		end
	end
	return false
end

local function isEligible(data: any, badgeName: string): boolean
	if badgeName == "FirstScrap" then
		return data.Tutorial.Milestones.FirstScrap == true
	elseif badgeName == "FirstBotBuilt" then
		return data.Stats.LifetimeRobotsBuilt > 0
	elseif badgeName == "FactoryOnline" then
		return data.Tutorial.Milestones.FirstIncomeEarned == true
	elseif badgeName == "RareDiscovery" then
		return hasRareDiscovery(data)
	elseif badgeName == "ZoneTwoUnlocked" then
		return data.Progression.Zone >= 2
	end
	return false
end

local function award(player: Player, badgeName: string, badgeId: number)
	local attempted = attemptedByPlayer[player]
	if attempted == nil or attempted[badgeName] == true then
		return
	end
	attempted[badgeName] = true

	if RunService:IsStudio() then
		player:SetAttribute("StudioBadge_" .. badgeName, true)
		return
	end

	local ownsOk, ownsOrError =
		pcall(BadgeService.UserHasBadgeAsync, BadgeService, player.UserId, badgeId)
	if not ownsOk then
		attempted[badgeName] = nil
		warn(
			("[BadgeService] Failed to check %s ownership for %d: %s"):format(
				badgeName,
				player.UserId,
				tostring(ownsOrError)
			)
		)
		return
	end
	if ownsOrError == true then
		return
	end

	local ok, awardedOrError =
		pcall(BadgeService.AwardBadgeAsync, BadgeService, player.UserId, badgeId)
	if not ok then
		attempted[badgeName] = nil
		warn(
			("[BadgeService] Failed to award %s to %d: %s"):format(
				badgeName,
				player.UserId,
				tostring(awardedOrError)
			)
		)
	end
end

function EngagementBadgeService.SyncPlayer(player: Player)
	local data = DataService.GetData(player)
	if data == nil then
		return
	end

	for badgeName, badgeId in BADGES do
		if isEligible(data, badgeName) then
			award(player, badgeName, badgeId)
		end
	end
end

function EngagementBadgeService.Init()
	if initialized then
		return
	end
	initialized = true

	DataService.ProfileLoaded:Connect(function(player)
		attemptedByPlayer[player] = {}
		EngagementBadgeService.SyncPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		attemptedByPlayer[player] = nil
	end)

	task.spawn(function()
		while true do
			task.wait(1)
			for _, player in Players:GetPlayers() do
				if DataService.IsReady(player) then
					EngagementBadgeService.SyncPlayer(player)
				end
			end
		end
	end)
end

return EngagementBadgeService
