--!strict

local RunService = game:GetService("RunService")

export type Mode = "Hub" | "Factory"

local RuntimeMode = {}

function RuntimeMode.Resolve(): Mode
	local override = game:GetAttribute("RuntimeModeOverride")
	if override == "Hub" or override == "Factory" then
		return override
	end

	-- Bootstrap.server uses an interactive Hub/Factory selector in Studio when no
	-- override exists. This remains the safe fallback for direct module consumers
	-- and server-only Studio runs that do not create a LocalPlayer.
	if RunService:IsStudio() then
		return "Factory"
	end

	if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then
		return "Factory"
	end

	return "Hub"
end

return table.freeze(RuntimeMode)
