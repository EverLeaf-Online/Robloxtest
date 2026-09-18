--!strict

local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local WorldLabelController = {}
local initialized = false

local tracked: { [BillboardGui]: boolean } = {}

local function isTrackedBillboard(instance: Instance): boolean
	if not instance:IsA("BillboardGui") then
		return false
	end
	return instance.Name == "StationLabel"
		or instance.Name == "WorldLabel"
		or instance.Name == "LocalFactoryMarker"
		or instance.Name == "FactoryEntitlementNameplate"
end

local function getWorldPosition(billboard: BillboardGui): Vector3?
	local adornee = billboard.Adornee
	if adornee ~= nil and adornee:IsA("BasePart") then
		return adornee.Position
	end
	local parent = billboard.Parent
	if parent ~= nil and parent:IsA("BasePart") then
		return parent.Position
	end
	return nil
end

local function setEnabled(billboard: BillboardGui, enabled: boolean)
	if billboard.Enabled ~= enabled then
		billboard.Enabled = enabled
	end
end

local function refresh()
	local player = Players.LocalPlayer
	local character = player.Character
	local root = if character then character:FindFirstChild("HumanoidRootPart") else nil
	if root == nil or not root:IsA("BasePart") then
		for billboard in tracked do
			setEnabled(billboard, false)
		end
		return
	end

	local camera = Workspace.CurrentCamera
	local phone = camera ~= nil and camera.ViewportSize.X <= 760
	local stationLimit = if phone then 1 else 2
	local stationDistance = if phone then 18 else 28
	local worldDistance = if phone then 22 else 38
	local localMarkerDistance = if phone then 24 else 34
	local entitlementDistance = if phone then 20 else 32

	local stations: { { Gui: BillboardGui, Distance: number } } = {}
	local worldLabels: { { Gui: BillboardGui, Distance: number } } = {}

	for billboard in tracked do
		if billboard.Parent == nil then
			tracked[billboard] = nil
			continue
		end

		local position = getWorldPosition(billboard)
		if position == nil then
			setEnabled(billboard, false)
			continue
		end

		local distance = (position - root.Position).Magnitude
		if billboard.Name == "LocalFactoryMarker" then
			setEnabled(billboard, distance <= localMarkerDistance)
		elseif billboard.Name == "FactoryEntitlementNameplate" then
			setEnabled(billboard, distance <= entitlementDistance)
		elseif billboard.Name == "StationLabel" then
			setEnabled(billboard, false)
			if distance <= stationDistance then
				table.insert(stations, { Gui = billboard, Distance = distance })
			end
		elseif billboard.Name == "WorldLabel" then
			setEnabled(billboard, false)
			if distance <= worldDistance then
				table.insert(worldLabels, { Gui = billboard, Distance = distance })
			end
		end
	end

	table.sort(stations, function(left, right)
		return left.Distance < right.Distance
	end)
	for index = 1, math.min(stationLimit, #stations) do
		setEnabled(stations[index].Gui, true)
	end

	table.sort(worldLabels, function(left, right)
		return left.Distance < right.Distance
	end)
	if worldLabels[1] ~= nil then
		setEnabled(worldLabels[1].Gui, true)
	end
end

function WorldLabelController.Init()
	if initialized then
		return
	end
	initialized = true

	for _, descendant in Workspace:GetDescendants() do
		if isTrackedBillboard(descendant) then
			tracked[descendant :: BillboardGui] = true
		end
	end

	Workspace.DescendantAdded:Connect(function(descendant)
		if isTrackedBillboard(descendant) then
			tracked[descendant :: BillboardGui] = true
		end
	end)
	Workspace.DescendantRemoving:Connect(function(descendant)
		if descendant:IsA("BillboardGui") then
			tracked[descendant] = nil
		end
	end)

	task.spawn(function()
		while initialized do
			refresh()
			task.wait(0.2)
		end
	end)
end

return table.freeze(WorldLabelController)
