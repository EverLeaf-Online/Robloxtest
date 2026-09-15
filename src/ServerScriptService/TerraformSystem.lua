local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlanetStateService = require(script.Parent.PlanetStateService)
local PlanetRenderer = require(script.Parent.PlanetRenderer)
local EnergySystem = require(script.Parent.EnergySystem)

local TerraformSystem = {}

function TerraformSystem.Apply(player)
	local state = PlanetStateService.GetState(player)
	if not state then
		return false, "Planet data is not ready."
	end
	if PlanetStateService.GetDevelopedCount(player) < Config.ACTION_UNLOCKS.TerraformBurst then
		return false, "Develop 50 tiles to unlock Terraform Burst."
	end

	local candidates = {}
	for index, tileType in ipairs(state.Tiles) do
		if tileType == "Land" then
			table.insert(candidates, index)
		end
	end
	if #candidates == 0 then
		return false, "Your planet is already fully developed."
	end

	local cost = Config.ACTION_COSTS.TerraformBurst
	if not EnergySystem.TrySpend(player, cost) then
		return false, string.format("Terraform Burst needs %d Energy.", cost)
	end

	local updates = {}
	local amount = math.min(3, #candidates)
	for step = 1, amount do
		local pick = math.random(1, #candidates)
		local tileIndex = table.remove(candidates, pick)
		local tileType = step % 2 == 1 and "Plant" or "Water"
		state.Tiles[tileIndex] = tileType
		table.insert(updates, { TileIndex = tileIndex, TileType = tileType })
		PlanetRenderer.UpdateTile(player, tileIndex)
	end
	PlanetStateService.MarkChanged(player)
	return true, string.format("Terraform Burst developed %d tiles.", amount), updates
end

return TerraformSystem
