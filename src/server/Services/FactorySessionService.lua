--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local GameConfig = require(game:GetService("ReplicatedStorage").Shared.Config.GameConfig)

local FactoryRouteRegistry = require(script.Parent.FactoryRouteRegistry)

export type FactoryRole = "Owner" | "Visitor"

local FactorySessionService = {}
local initialized = false
local sessionOwnerUserId: number? = nil
local roleByPlayer: { [Player]: FactoryRole } = {}

local function participantCount(): number
	local count = 0
	for _ in roleByPlayer do
		count += 1
	end
	return count
end

local function reject(player: Player, message: string)
	warn(("[FactorySessionService] Rejecting %d: %s"):format(player.UserId, message))
	task.defer(function()
		if player.Parent == Players then
			player:Kick(message)
		end
	end)
end

local function accept(player: Player, ownerUserId: number, role: FactoryRole)
	if sessionOwnerUserId == nil then
		sessionOwnerUserId = ownerUserId
	elseif sessionOwnerUserId ~= ownerUserId then
		reject(player, "This factory session belongs to another player.")
		return
	end

	if participantCount() >= GameConfig.Session.FactoryMaxPlayers then
		reject(player, "This factory is full.")
		return
	end

	roleByPlayer[player] = role
	player:SetAttribute("FactoryRouteVerified", true)
	player:SetAttribute("FactoryRole", role)
	player:SetAttribute("FactoryOwnerUserId", ownerUserId)
	game:SetAttribute("FactoryOwnerUserId", ownerUserId)
end

local function validateLiveRoute(player: Player)
	if game.PrivateServerId == "" or game.PrivateServerOwnerId ~= 0 then
		reject(player, "Invalid factory server.")
		return
	end

	local joinData = player:GetJoinData()
	local teleportData = joinData.TeleportData
	if typeof(teleportData) ~= "table" then
		reject(player, "Missing factory route.")
		return
	end

	local token = teleportData.FactoryRouteToken
	if typeof(token) ~= "string" or #token < 8 or #token > 128 then
		reject(player, "Invalid factory route.")
		return
	end

	local record = FactoryRouteRegistry.ConsumeRoute(token, player.UserId)
	if record == nil then
		reject(player, "Factory route expired. Return to the hub and try again.")
		return
	end

	accept(player, record.OwnerUserId, record.Role)
end

local function processPlayer(player: Player)
	if roleByPlayer[player] ~= nil then
		return
	end

	if RunService:IsStudio() then
		if sessionOwnerUserId == nil then
			accept(player, player.UserId, "Owner")
		else
			accept(player, sessionOwnerUserId, "Visitor")
		end
		return
	end

	validateLiveRoute(player)
end

function FactorySessionService.GetOwnerUserId(): number?
	return sessionOwnerUserId
end

function FactorySessionService.GetRole(player: Player): FactoryRole?
	return roleByPlayer[player]
end

function FactorySessionService.IsOwner(player: Player): boolean
	return roleByPlayer[player] == "Owner"
end

function FactorySessionService.IsParticipant(player: Player): boolean
	return roleByPlayer[player] ~= nil
end

function FactorySessionService.WaitForVerification(player: Player, timeoutSeconds: number): boolean
	if player:GetAttribute("FactoryRouteVerified") == true then
		return true
	end

	local deadline = os.clock() + timeoutSeconds
	while player.Parent == Players and os.clock() < deadline do
		if player:GetAttribute("FactoryRouteVerified") == true then
			return true
		end
		task.wait(0.05)
	end
	return false
end

function FactorySessionService.Init()
	if initialized then
		return
	end
	initialized = true

	game:SetAttribute("FactoryOwnerUserId", 0)

	Players.PlayerAdded:Connect(processPlayer)
	Players.PlayerRemoving:Connect(function(player)
		roleByPlayer[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		processPlayer(player)
	end
end

return FactorySessionService
