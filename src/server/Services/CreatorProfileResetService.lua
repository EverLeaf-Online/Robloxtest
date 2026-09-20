--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)

local DataService = require(script.Parent.DataService)
local RemoteService = require(script.Parent.RemoteService)
local StateService = require(script.Parent.StateService)

local CreatorProfileResetService = {}
local initialized = false

local function isCreator(player: Player): boolean
	if game.CreatorType == Enum.CreatorType.User then
		return player.UserId == game.CreatorId
	end

	if game.CreatorType == Enum.CreatorType.Group then
		local ok, rankOrError = pcall(player.GetRankInGroup, player, game.CreatorId)
		if not ok then
			warn(
				("[CreatorProfileResetService] Failed creator group-rank check for %d: %s"):format(
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

function CreatorProfileResetService.Init()
	if initialized then
		return
	end
	initialized = true

	RemoteService.BindRequest(
		RemoteNames.RequestAdminFreshProfileReset,
		function(player: Player, confirmation: any)
			if not isCreator(player) then
				StateService.ActionResult(player, "AdminFreshProfileReset", false, "NOT_AUTHORIZED")
				return
			end
			if confirmation ~= "RESET" then
				StateService.ActionResult(
					player,
					"AdminFreshProfileReset",
					false,
					"INVALID_CONFIRMATION"
				)
				return
			end

			local ok, code = DataService.ResetToFreshProfile(player)
			StateService.ActionResult(player, "AdminFreshProfileReset", ok, code)
			if not ok then
				return
			end

			task.delay(0.75, function()
				if player.Parent == Players then
					player:Kick(
						"Fresh test profile created. Rejoin to test the first-time player flow."
					)
				end
			end)
		end
	)
end

return CreatorProfileResetService
