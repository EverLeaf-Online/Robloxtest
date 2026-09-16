--!strict

local Players = game:GetService("Players")
local ProximityPromptService = game:GetService("ProximityPromptService")

local UIBus = require(script.Parent.Parent.UI.UIBus)

local WorldInteractionController = {}
local initialized = false
local connection: RBXScriptConnection? = nil

local function isOwnedPlotPrompt(prompt: ProximityPrompt): boolean
	local current: Instance? = prompt.Parent
	while current ~= nil do
		local ownerUserId = current:GetAttribute("OwnerUserId")
		if typeof(ownerUserId) == "number" then
			return ownerUserId == Players.LocalPlayer.UserId
		end
		current = current.Parent
	end
	return false
end

function WorldInteractionController.Init()
	if initialized then
		return
	end
	initialized = true

	connection = ProximityPromptService.PromptTriggered:Connect(function(prompt)
		local panelName = prompt:GetAttribute("LocalUIPanel")
		if typeof(panelName) ~= "string" then
			return
		end
		if not isOwnedPlotPrompt(prompt) then
			return
		end
		UIBus.OpenPanel(panelName)
	end)
end

function WorldInteractionController.Destroy()
	if connection ~= nil then
		connection:Disconnect()
		connection = nil
	end
	initialized = false
end

return table.freeze(WorldInteractionController)
