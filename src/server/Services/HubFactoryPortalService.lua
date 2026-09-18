--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local FactoryRouteRegistry = require(script.Parent.FactoryRouteRegistry)
local HubWorldService = require(script.Parent.HubWorldService)

local HubFactoryPortalService = {}
local initialized = false
local busy: { [Player]: boolean } = {}

local function makeOptions(token: string, accessCode: string): TeleportOptions
	local options = Instance.new("TeleportOptions")
	options.ReservedServerAccessCode = accessCode
	options:SetTeleportData({
		FactoryRouteToken = token,
	})
	return options
end

local function reserveFactory(ownerUserId: number): string?
	local ok, accessCodeOrError = pcall(function()
		local accessCode = TeleportService:ReserveServerAsync(game.PlaceId)
		return accessCode
	end)
	if not ok or typeof(accessCodeOrError) ~= "string" or accessCodeOrError == "" then
		warn(
			("[HubFactoryPortalService] ReserveServerAsync failed for %d: %s"):format(
				ownerUserId,
				tostring(accessCodeOrError)
			)
		)
		return nil
	end

	FactoryRouteRegistry.SetFactoryAccessCode(ownerUserId, accessCodeOrError)
	return accessCodeOrError
end

local function getOrReserveFactory(ownerUserId: number): string?
	local existingCode = FactoryRouteRegistry.GetFactoryAccessCode(ownerUserId)
	if existingCode ~= nil then
		return existingCode
	end
	return reserveFactory(ownerUserId)
end

local function tryTeleport(player: Player, accessCode: string, token: string): (boolean, any)
	local options = makeOptions(token, accessCode)
	return pcall(function()
		return TeleportService:TeleportAsync(game.PlaceId, { player }, options)
	end)
end

local function teleportOwner(player: Player)
	if busy[player] then
		return
	end
	busy[player] = true

	if RunService:IsStudio() then
		warn("[HubFactoryPortalService] TeleportService is unavailable in Studio")
		busy[player] = nil
		return
	end

	local ownerUserId = player.UserId
	local accessCode = getOrReserveFactory(ownerUserId)
	if accessCode == nil then
		busy[player] = nil
		return
	end

	local token = FactoryRouteRegistry.CreateRoute(ownerUserId, ownerUserId, "Owner")
	if token == nil then
		busy[player] = nil
		return
	end

	local ok, result = tryTeleport(player, accessCode, token)
	if not ok then
		-- A remembered reserved-server code can become unusable. Replace it once,
		-- then retry with the same short-lived route capability.
		FactoryRouteRegistry.ClearFactoryAccessCode(ownerUserId)
		local replacementCode = reserveFactory(ownerUserId)
		if replacementCode ~= nil then
			ok, result = tryTeleport(player, replacementCode, token)
		end
	end

	if not ok then
		FactoryRouteRegistry.DeleteRoute(token)
		warn(
			("[HubFactoryPortalService] Factory teleport failed for %d: %s"):format(
				ownerUserId,
				tostring(result)
			)
		)
		busy[player] = nil
		return
	end

	task.delay(8, function()
		busy[player] = nil
	end)
end

function HubFactoryPortalService.Init()
	if initialized then
		return
	end
	initialized = true

	local portal = HubWorldService.GetFactoryPortal()
	local prompt = portal:FindFirstChildOfClass("ProximityPrompt")
	assert(prompt ~= nil, "Factory portal prompt missing")

	prompt.Triggered:Connect(teleportOwner)
	TeleportService.TeleportInitFailed:Connect(function(player)
		if busy[player] then
			FactoryRouteRegistry.ClearFactoryAccessCode(player.UserId)
			busy[player] = nil
		end
	end)
	Players.PlayerRemoving:Connect(function(player)
		busy[player] = nil
	end)
end

return HubFactoryPortalService
