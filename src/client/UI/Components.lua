--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)

local COLORS = Theme.Colors
local Components = {}

function Components.Corner(radius: number): any
	return React.createElement("UICorner", {
		CornerRadius = UDim.new(0, radius),
	})
end

function Components.Padding(all: number): any
	return React.createElement("UIPadding", {
		PaddingBottom = UDim.new(0, all),
		PaddingLeft = UDim.new(0, all),
		PaddingRight = UDim.new(0, all),
		PaddingTop = UDim.new(0, all),
	})
end

function Components.TextLabel(text: string, size: number, color: Color3?, bold: boolean?): any
	return React.createElement("TextLabel", {
		AutomaticSize = Enum.AutomaticSize.Y,
		BackgroundTransparency = 1,
		Font = if bold then Enum.Font.GothamBold else Enum.Font.Gotham,
		Size = UDim2.fromScale(1, 0),
		Text = text,
		TextColor3 = color or COLORS.Text,
		TextSize = size,
		TextWrapped = true,
		TextXAlignment = Enum.TextXAlignment.Left,
	})
end

function Components.Button(text: string, enabled: boolean, callback: (() -> ())?): any
	local props: any = {
		AutoButtonColor = enabled,
		BackgroundColor3 = if enabled then COLORS.AccentDark else COLORS.PanelSoft,
		Font = Enum.Font.GothamBold,
		Size = UDim2.fromOffset(92, 32),
		Text = text,
		TextColor3 = if enabled then COLORS.Text else COLORS.Muted,
		TextSize = 13,
	}
	if enabled and callback ~= nil then
		props[React.Event.Activated] = callback
	end
	return React.createElement("TextButton", props, {
		Corner = Components.Corner(7),
	})
end

function Components.StatCard(title: string, value: string): any
	return React.createElement("Frame", {
		BackgroundColor3 = COLORS.PanelAlt,
		BorderSizePixel = 0,
		Size = UDim2.new(0.25, -6, 1, 0),
	}, {
		Corner = Components.Corner(8),
		Title = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.Gotham,
			Position = UDim2.fromOffset(9, 4),
			Size = UDim2.new(1, -18, 0, 14),
			Text = title,
			TextColor3 = COLORS.Muted,
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
		Value = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(9, 17),
			Size = UDim2.new(1, -18, 0, 20),
			Text = value,
			TextColor3 = COLORS.Text,
			TextSize = 15,
			TextXAlignment = Enum.TextXAlignment.Left,
		}),
	})
end

return table.freeze(Components)
