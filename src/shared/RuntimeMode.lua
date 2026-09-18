--!strict

local RunService = game:GetService("RunService")

export type Mode = "Hub" | "Factory"

local RuntimeMode = {}

function RuntimeMode.Resolve(): Mode
	local override = game:GetAttribute("RuntimeModeOverride")
	if override == "Hub" or override == "Factory" then
		return override
	end

	-- Studio stays in Factory mode by default so existing gameplay/OCALE workflows
	-- remain usable without TeleportService, which Roblox does not support in Studio.
	if RunService:IsStudio() then
		return "Factory"
	end

	if game.PrivateServerId ~= "" and game.PrivateServerOwnerId == 0 then
		return "Factory"
	end

	return "Hub"
end

return table.freeze(RuntimeMode)
