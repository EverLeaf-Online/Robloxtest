--!strict

local RemoteService = require(script.Parent.Services.RemoteService)

local function start()
	RemoteService.Init()
	print("[ScrapToBotFactory] Server foundation initialized")
end

start()
