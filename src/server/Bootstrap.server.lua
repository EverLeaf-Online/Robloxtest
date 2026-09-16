--!strict

local DataService = require(script.Parent.Services.DataService)
local RemoteService = require(script.Parent.Services.RemoteService)

local function start()
	DataService.Init()
	RemoteService.Init()
	print("[ScrapToBotFactory] Server foundation initialized")
end

start()
