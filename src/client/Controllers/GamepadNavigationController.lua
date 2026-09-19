--!strict

local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local GamepadNavigationController = {}

local initialized = false
local gamepadMode = false

local function isGamepadInput(inputType: Enum.UserInputType): boolean
	return string.sub(inputType.Name, 1, 7) == "Gamepad"
end

local function isVisibleThroughAncestors(object: GuiObject, playerGui: PlayerGui): boolean
	local current: Instance? = object
	while current ~= nil and current ~= playerGui do
		if current:IsA("GuiObject") and not current.Visible then
			return false
		end
		if current:IsA("ScreenGui") and not current.Enabled then
			return false
		end
		current = current.Parent
	end
	return current == playerGui
end

local function isSelectable(button: GuiButton, playerGui: PlayerGui): boolean
	return button.Active
		and button.Selectable
		and button.AbsoluteSize.X >= 24
		and button.AbsoluteSize.Y >= 24
		and isVisibleThroughAncestors(button, playerGui)
end

local function screenDisplayOrder(button: GuiButton): number
	local current: Instance? = button
	while current ~= nil do
		if current:IsA("ScreenGui") then
			return current.DisplayOrder
		end
		current = current.Parent
	end
	return 0
end

local function selectFirstAvailable(playerGui: PlayerGui)
	if not gamepadMode or GuiService.SelectedObject ~= nil then
		return
	end

	local candidates: { GuiButton } = {}
	for _, descendant in playerGui:GetDescendants() do
		if descendant:IsA("GuiButton") and isSelectable(descendant, playerGui) then
			table.insert(candidates, descendant)
		end
	end

	table.sort(candidates, function(a, b)
		local aOrder = screenDisplayOrder(a)
		local bOrder = screenDisplayOrder(b)
		if aOrder ~= bOrder then
			return aOrder > bOrder
		end

		local aPosition = a.AbsolutePosition
		local bPosition = b.AbsolutePosition
		if math.abs(aPosition.Y - bPosition.Y) > 2 then
			return aPosition.Y < bPosition.Y
		end
		if math.abs(aPosition.X - bPosition.X) > 2 then
			return aPosition.X < bPosition.X
		end
		return a:GetFullName() < b:GetFullName()
	end)

	GuiService.SelectedObject = candidates[1]
end

local function configureButton(button: GuiButton)
	button.Selectable = button.Active
	button:GetPropertyChangedSignal("Active"):Connect(function()
		button.Selectable = button.Active
	end)
end

function GamepadNavigationController.Init()
	if initialized then
		return
	end
	initialized = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

	for _, descendant in playerGui:GetDescendants() do
		if descendant:IsA("GuiButton") then
			configureButton(descendant)
		end
	end

	playerGui.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("GuiButton") then
			configureButton(descendant)
			task.defer(selectFirstAvailable, playerGui)
		end
	end)

	playerGui.DescendantRemoving:Connect(function(descendant)
		local selected = GuiService.SelectedObject
		if selected == descendant or (selected ~= nil and selected:IsDescendantOf(descendant)) then
			GuiService.SelectedObject = nil
			task.defer(selectFirstAvailable, playerGui)
		end
	end)

	GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		if gamepadMode and GuiService.SelectedObject == nil then
			task.defer(selectFirstAvailable, playerGui)
		end
	end)

	local function updateInputMode(inputType: Enum.UserInputType)
		local nextGamepadMode = isGamepadInput(inputType)
		if nextGamepadMode == gamepadMode then
			return
		end

		gamepadMode = nextGamepadMode
		if gamepadMode then
			task.defer(selectFirstAvailable, playerGui)
		else
			GuiService.SelectedObject = nil
		end
	end

	UserInputService.LastInputTypeChanged:Connect(updateInputMode)
	updateInputMode(UserInputService:GetLastInputType())
end

return table.freeze(GamepadNavigationController)
