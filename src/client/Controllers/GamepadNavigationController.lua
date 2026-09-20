--!strict

local ContextActionService = game:GetService("ContextActionService")
local GuiService = game:GetService("GuiService")
local Players = game:GetService("Players")
local UserInputService = game:GetService("UserInputService")

local UIBus = require(script.Parent.Parent.UI.UIBus)

local GamepadNavigationController = {}

local ACTION_BACK = "ScrapToBot_GamepadBack"
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

local function isSelectable(button: GuiButton, playerGui: PlayerGui): boolean
	return button.Active
		and button.Selectable
		and button.AbsoluteSize.X >= 24
		and button.AbsoluteSize.Y >= 24
		and isVisibleThroughAncestors(button, playerGui)
end

local function compareCandidates(a: GuiButton, b: GuiButton): boolean
	local aOrder = screenDisplayOrder(a)
	local bOrder = screenDisplayOrder(b)
	if aOrder ~= bOrder then
		return aOrder > bOrder
	end

	if a.ZIndex ~= b.ZIndex then
		return a.ZIndex > b.ZIndex
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
end

local function bestCandidate(playerGui: PlayerGui): GuiButton?
	local candidates: { GuiButton } = {}
	for _, descendant in playerGui:GetDescendants() do
		if descendant:IsA("GuiButton") and isSelectable(descendant, playerGui) then
			table.insert(candidates, descendant)
		end
	end

	table.sort(candidates, compareCandidates)
	return candidates[1]
end

local function selectedObjectIsUsable(playerGui: PlayerGui): boolean
	local selected = GuiService.SelectedObject
	return selected ~= nil
		and selected:IsA("GuiButton")
		and selected:IsDescendantOf(playerGui)
		and isSelectable(selected, playerGui)
end

local function selectBestAvailable(playerGui: PlayerGui, allowPriorityOverride: boolean)
	if not gamepadMode then
		return
	end

	local candidate = bestCandidate(playerGui)
	if candidate == nil then
		GuiService.SelectedObject = nil
		return
	end

	local selected = GuiService.SelectedObject
	if selectedObjectIsUsable(playerGui) and not allowPriorityOverride then
		return
	end

	if
		selected ~= nil
		and selected:IsA("GuiButton")
		and selectedObjectIsUsable(playerGui)
		and allowPriorityOverride
	then
		local selectedOrder = screenDisplayOrder(selected)
		local candidateOrder = screenDisplayOrder(candidate)
		if
			candidateOrder < selectedOrder
			or (candidateOrder == selectedOrder and candidate.ZIndex <= selected.ZIndex)
		then
			return
		end
	end

	GuiService.SelectedObject = candidate
end

local function configureButton(button: GuiButton, playerGui: PlayerGui)
	button.Selectable = button.Active

	button:GetPropertyChangedSignal("Active"):Connect(function()
		button.Selectable = button.Active
		if gamepadMode and GuiService.SelectedObject == button and not button.Active then
			GuiService.SelectedObject = nil
			task.defer(selectBestAvailable, playerGui, false)
		end
	end)

	if gamepadMode then
		task.defer(selectBestAvailable, playerGui, true)
	end
end

function GamepadNavigationController.Init()
	if initialized then
		return
	end
	initialized = true

	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui") :: PlayerGui

	for _, descendant in playerGui:GetDescendants() do
		if descendant:IsA("GuiButton") then
			configureButton(descendant, playerGui)
		end
	end

	playerGui.DescendantAdded:Connect(function(descendant)
		if descendant:IsA("GuiButton") then
			configureButton(descendant, playerGui)
		end
	end)

	playerGui.DescendantRemoving:Connect(function(descendant)
		local selected = GuiService.SelectedObject
		if selected == descendant or (selected ~= nil and selected:IsDescendantOf(descendant)) then
			GuiService.SelectedObject = nil
			task.defer(selectBestAvailable, playerGui, false)
		end
	end)

	GuiService:GetPropertyChangedSignal("SelectedObject"):Connect(function()
		if gamepadMode and not selectedObjectIsUsable(playerGui) then
			task.defer(selectBestAvailable, playerGui, false)
		end
	end)

	UIBus.BackRequested:Connect(function()
		if not gamepadMode then
			return
		end
		GuiService.SelectedObject = nil
		task.defer(selectBestAvailable, playerGui, false)
	end)

	local function updateInputMode(inputType: Enum.UserInputType)
		local nextGamepadMode = isGamepadInput(inputType)
		if nextGamepadMode == gamepadMode then
			return
		end

		gamepadMode = nextGamepadMode
		if gamepadMode then
			task.defer(selectBestAvailable, playerGui, false)
		else
			GuiService.SelectedObject = nil
		end
	end

	ContextActionService:BindAction(
		ACTION_BACK,
		function(
			_actionName: string,
			inputState: Enum.UserInputState,
			_inputObject: InputObject
		): Enum.ContextActionResult
			if inputState == Enum.UserInputState.Begin and gamepadMode then
				UIBus.RequestBack()
			end
			return Enum.ContextActionResult.Pass
		end,
		false,
		Enum.KeyCode.ButtonB
	)

	UserInputService.LastInputTypeChanged:Connect(updateInputMode)
	updateInputMode(UserInputService:GetLastInputType())
end

return table.freeze(GamepadNavigationController)
