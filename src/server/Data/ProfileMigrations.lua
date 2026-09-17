--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local ProfileMigrations = {}

local migrations: { [number]: (any) -> () } = {
	[2] = function(data)
		if typeof(data.Machines) ~= "table" then
			data.Machines = {}
		end

		if typeof(data.Machines.ProcessorJob) ~= "table" then
			data.Machines.ProcessorJob = {
				Active = false,
				RecipeId = "",
				StartedAt = 0,
				CompletesAt = 0,
			}
		end

		if typeof(data.Machines.AssemblerJob) ~= "table" then
			data.Machines.AssemblerJob = {
				Active = false,
				StartedAt = 0,
				CompletesAt = 0,
			}
		end
	end,
	[3] = function(data)
		if typeof(data.Consumables) ~= "table" then
			data.Consumables = {}
		end
		if typeof(data.Consumables.InstantProcessTokens) ~= "number" then
			data.Consumables.InstantProcessTokens = 0
		end

		if typeof(data.Entitlements) ~= "table" then
			data.Entitlements = {}
		end
		if typeof(data.Entitlements.CachedPassFlags) ~= "table" then
			data.Entitlements.CachedPassFlags = {}
		end
		if typeof(data.Entitlements.StarterPackClaimed) ~= "boolean" then
			data.Entitlements.StarterPackClaimed = false
		end
		if typeof(data.Entitlements.PersonalOverclockUntil) ~= "number" then
			data.Entitlements.PersonalOverclockUntil = 0
		end
		if typeof(data.Entitlements.FactoryClubActiveCached) ~= "boolean" then
			data.Entitlements.FactoryClubActiveCached = false
		end
		if typeof(data.Entitlements.FactoryClubLastGrantedCycle) ~= "string" then
			data.Entitlements.FactoryClubLastGrantedCycle = ""
		end
		if typeof(data.Entitlements.FactoryClubCosmetics) ~= "table" then
			data.Entitlements.FactoryClubCosmetics = {}
		end
		if typeof(data.Entitlements.EquippedFactoryClubCosmetic) ~= "string" then
			data.Entitlements.EquippedFactoryClubCosmetic = ""
		end

		if typeof(data.Referrals) ~= "table" then
			data.Referrals = {
				PendingInviterUserId = 0,
				PendingStartedAt = 0,
				QualifiedRewardCount = 0,
			}
		end

		if typeof(data.Stats) ~= "table" then
			data.Stats = {}
		end
		if typeof(data.Stats.LifetimePlaySeconds) ~= "number" then
			data.Stats.LifetimePlaySeconds = 0
		end

		if typeof(data.Timestamps) ~= "table" then
			data.Timestamps = {}
		end
		if typeof(data.Timestamps.LastLeave) ~= "number" then
			data.Timestamps.LastLeave = 0
		end
	end,
	[4] = function(data)
		if typeof(data.Referrals) ~= "table" then
			data.Referrals = {}
		end
		if typeof(data.Referrals.PendingPlaySeconds) ~= "number" then
			data.Referrals.PendingPlaySeconds = 0
		end
	end,
}

local function readVersion(data: any): number
	if typeof(data.Version) ~= "number" or data.Version % 1 ~= 0 or data.Version < 1 then
		return 1
	end
	return data.Version
end

function ProfileMigrations.Apply(data: any)
	assert(typeof(data) == "table", "Profile data must be a table")

	local version = readVersion(data)
	assert(
		version <= GameConfig.ProfileSchemaVersion,
		("Profile version %d is newer than server schema %d"):format(
			version,
			GameConfig.ProfileSchemaVersion
		)
	)

	while version < GameConfig.ProfileSchemaVersion do
		local nextVersion = version + 1
		local migrate = migrations[nextVersion]
		assert(migrate ~= nil, ("Missing profile migration for version %d"):format(nextVersion))
		migrate(data)
		version = nextVersion
		data.Version = version
	end

	data.Version = GameConfig.ProfileSchemaVersion
end

return table.freeze(ProfileMigrations)
