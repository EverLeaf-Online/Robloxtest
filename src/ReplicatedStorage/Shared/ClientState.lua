-- ReplicatedStorage/Shared/ClientState.module.lua
-- Small client-only shared state module.

local ClientState = {
	SelectedTile = -1,
	Energy = 0,
	Stats = nil,
	Ownership = {},
}

local changed = Instance.new("BindableEvent")
ClientState.Changed = changed.Event

function ClientState:SetSelectedTile(index)
	self.SelectedTile = index
	changed:Fire("SelectedTile", index)
end

function ClientState:SetEnergy(value)
	self.Energy = value
	changed:Fire("Energy", value)
end

function ClientState:SetStats(stats)
	self.Stats = stats

	if typeof(stats) == "table" and typeof(stats.Ownership) == "table" then
		self.Ownership = stats.Ownership
	end

	changed:Fire("Stats", stats)
end

function ClientState:SetOwnership(ownership)
	self.Ownership = ownership
	changed:Fire("Ownership", ownership)
end

return ClientState
