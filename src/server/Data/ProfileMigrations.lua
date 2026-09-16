--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local GameConfig = require(ReplicatedStorage.Shared.Config.GameConfig)

local ProfileMigrations = {}

local migrations: { [number]: (any) -> () } = {
	-- [2] = function(data)
	--     -- Transform a v1 profile into v2 here before the template is reconciled.
	-- end,
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
