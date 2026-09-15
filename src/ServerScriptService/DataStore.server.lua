local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Config = require(ReplicatedStorage.Shared.Config)
local PlanetStateService = require(script.Parent.PlanetStateService)

local shuttingDown = false

task.spawn(function()
	while not shuttingDown do
		task.wait(Config.AUTOSAVE_SECONDS)
		if shuttingDown then
			break
		end
		for _, player in ipairs(PlanetStateService.GetLoadedPlayers()) do
			PlanetStateService.QueueSave(player)
		end
	end
end)

game:BindToClose(function()
	shuttingDown = true
	local pending = 0

	for _, player in ipairs(Players:GetPlayers()) do
		if PlanetStateService.IsLoaded(player) and PlanetStateService.CanSave(player) then
			pending += 1
			task.spawn(function()
				PlanetStateService.SavePlayer(player)
				pending -= 1
			end)
		end
	end

	-- BindToClose has a limited shutdown window. Polling the counter avoids the
	-- event-listener race where every save can finish before a completion event
	-- is connected, which would otherwise waste almost the entire close window.
	local deadline = os.clock() + 25
	while pending > 0 and os.clock() < deadline do
		task.wait(0.1)
	end

	if pending > 0 then
		warn(string.format("[DataStore] Shutdown deadline reached with %d save(s) still pending", pending))
	end
end)
