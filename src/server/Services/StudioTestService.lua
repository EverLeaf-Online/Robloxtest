--!strict

local RunService = game:GetService("RunService")

local DataService = require(script.Parent.DataService)

local StudioTestService = {}
local initialized = false

local TEST_TOKEN_GRANT = 3

local function grantTestTokens(player: Player)
	if not RunService:IsStudio() then
		return
	end

	local executed = DataService.Transaction(player, function(data)
		if data.Consumables.InstantProcessTokens > 0 then
			return true, data.Consumables.InstantProcessTokens
		end

		data.Consumables.InstantProcessTokens = TEST_TOKEN_GRANT
		return true, TEST_TOKEN_GRANT
	end)

	if not executed then
		return
	end

	local data = DataService.GetData(player)
	if data ~= nil then
		player:SetAttribute("InstantProcessTokens", data.Consumables.InstantProcessTokens)
	end
end

function StudioTestService.Init()
	if initialized then
		return
	end
	initialized = true

	if not RunService:IsStudio() then
		return
	end

	DataService.ProfileLoaded:Connect(function(player)
		grantTestTokens(player)
	end)
end

return StudioTestService
