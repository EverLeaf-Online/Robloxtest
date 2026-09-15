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
	local finished = Instance.new("BindableEvent")
	for _, player in ipairs(Players:GetPlayers()) do
		if PlanetStateService.IsLoaded(player) then
			pending += 1
			task.spawn(function()
				PlanetStateService.SavePlayer(player)
				pending -= 1
				if pending == 0 then
					finished:Fire()
				end
			end)
		end
	end
	if pending > 0 then
		local done = false
		local connection
		connection = finished.Event:Connect(function()
			done = true
			connection:Disconnect()
		end)
		local deadline = os.clock() + 25
		while not done and os.clock() < deadline do
			task.wait(0.1)
		end
	end
	finished:Destroy()
end)
