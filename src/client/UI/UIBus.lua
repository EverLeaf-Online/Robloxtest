--!strict

local panelRequested = Instance.new("BindableEvent")

local UIBus = {}
UIBus.PanelRequested = panelRequested.Event

function UIBus.OpenPanel(panelName: string)
	if panelName ~= "Bots" and panelName ~= "Upgrades" and panelName ~= "Index" and panelName ~= "Storage" and panelName ~= "Recycle" then
		return
	end
	panelRequested:Fire(panelName)
end

return table.freeze(UIBus)
