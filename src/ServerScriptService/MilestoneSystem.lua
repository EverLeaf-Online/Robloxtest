local ReplicatedFirst = game:GetService("ReplicatedFirst")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlanetStateService = require(script.Parent.PlanetStateService)

local MilestoneSystem = {}
local milestoneRemote = ReplicatedFirst:WaitForChild("Remotes"):WaitForChild("MilestoneReached")

function MilestoneSystem.Check(player)
	local state = PlanetStateService.GetState(player)
	if not state then
		return {}
	end

	local developed = PlanetStateService.GetDevelopedCount(player)
	local reachedNow = {}

	for _, milestone in ipairs(Config.MILESTONES) do
		local key = tostring(milestone)
		if developed >= milestone and state.Milestones[key] ~= true then
			state.Milestones[key] = true

			local rewardEnergy = Config.MILESTONE_ENERGY_REWARDS[milestone] or 0
			if rewardEnergy > 0 then
				state.Energy = math.min(Config.ENERGY_MAX, state.Energy + rewardEnergy)
			end

			PlanetStateService.MarkChanged(player)

			local unlockName = Config.MILESTONE_UNLOCK_NAMES[milestone] or "New growth"
			local info = {
				Milestone = milestone,
				Title = string.format("%d Tiles Developed!", milestone),
				Message = string.format("Unlocked: %s  •  +%d Energy", unlockName, rewardEnergy),
				UnlockedAction = unlockName,
				RewardEnergy = rewardEnergy,
			}

			table.insert(reachedNow, info)
			milestoneRemote:FireClient(player, info)
		end
	end

	return reachedNow
end

return MilestoneSystem
