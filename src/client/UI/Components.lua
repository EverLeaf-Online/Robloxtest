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

function Components.ResourceChip(
	icon: string,
	title: string,
	value: string,
	accent: Color3,
	compact: boolean
): any
	local iconSize = if compact then 30 else 36
	local titleVisible = not compact

	return React.createElement("Frame", {
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.08,
		BorderSizePixel = 0,
		Size = UDim2.new(0.25, -6, 1, 0),
	}, {
		Corner = Components.Corner(12),
		Stroke = React.createElement("UIStroke", {
			Color = accent,
			Transparency = 0.35,
			Thickness = 1.5,
		}),
		IconPlate = React.createElement("Frame", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundColor3 = accent,
			BorderSizePixel = 0,
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(iconSize, iconSize),
		}, {
			Corner = React.createElement("UICorner", {
				CornerRadius = UDim.new(1, 0),
			}),
			Icon = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Size = UDim2.fromScale(1, 1),
				Text = icon,
				TextColor3 = Color3.fromRGB(255, 255, 255),
				TextSize = if compact then 16 else 19,
			}),
		}),
		Title = titleVisible and React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(iconSize + 12, 5),
			Size = UDim2.new(1, -(iconSize + 17), 0, 12),
			Text = title,
			TextColor3 = COLORS.Muted,
			TextSize = 8,
			TextXAlignment = Enum.TextXAlignment.Left,
		}) or nil,
		Value = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = if compact
				then UDim2.fromOffset(iconSize + 11, 0)
				else UDim2.fromOffset(iconSize + 12, 15),
			Size = if compact
				then UDim2.new(1, -(iconSize + 15), 1, 0)
				else UDim2.new(1, -(iconSize + 17), 0, 22),
			Text = value,
			TextColor3 = COLORS.Text,
			TextSize = if compact then 13 else 16,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
		}),
	})
end

return table.freeze(Components)
