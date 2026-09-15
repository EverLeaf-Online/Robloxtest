local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlanetStateService = require(script.Parent.PlanetStateService)

local EnergySystem = {}
local runningTokens = {}
local updateEnergy = ReplicatedFirst:WaitForChild("Remotes"):WaitForChild("UpdateEnergy")

function EnergySystem.CanAfford(player, amount)
	local state = PlanetStateService.GetState(player)
	return state ~= nil and state.Energy >= amount
end

function EnergySystem.TrySpend(player, amount)
	local state = PlanetStateService.GetState(player)
	if not state or type(amount) ~= "number" or amount < 0 then
		return false
	end
	if state.Energy < amount then
		return false
	end
	state.Energy -= amount
	PlanetStateService.MarkChanged(player)
	return true
end

function EnergySystem.Add(player, amount)
	local state = PlanetStateService.GetState(player)
	if not state then
		return 0
	end
	state.Energy = math.clamp(state.Energy + math.floor(amount), 0, Config.ENERGY_MAX)
	PlanetStateService.MarkChanged(player)
	updateEnergy:FireClient(player, state.Energy)
	return state.Energy
end

function EnergySystem.Start(player)
	EnergySystem.Stop(player)
	local token = {}
	runningTokens[player.UserId] = token
	task.spawn(function()
		while runningTokens[player.UserId] == token and player.Parent do
			local flags = PlanetStateService.GetPassFlags(player)
			local interval = Config.ENERGY_REGEN_INTERVAL
			if flags.FastGrowth then
				interval /= 2
			end
			task.wait(interval)
			if runningTokens[player.UserId] ~= token or not player.Parent then
				break
			end
			local state = PlanetStateService.GetState(player)
			if state and state.Energy < Config.ENERGY_MAX then
				state.Energy = math.min(Config.ENERGY_MAX, state.Energy + Config.ENERGY_REGEN_AMOUNT)
				PlanetStateService.MarkChanged(player)
				updateEnergy:FireClient(player, state.Energy)
			end
		end
	end)
end

function EnergySystem.Stop(player)
	runningTokens[player.UserId] = nil
end

return EnergySystem
