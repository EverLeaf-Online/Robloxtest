--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local IconAssets = require(script.Parent.IconAssets)
local Theme = require(script.Parent.Theme)

local COLORS = Theme.Colors
local Components = {}

type ResourceIconKind = "Credits" | "Scrap" | "Wiring" | "Cores"

local RESOURCE_IMAGES: { [ResourceIconKind]: string } = {
	Credits = IconAssets.Credits,
	Scrap = IconAssets.Scrap,
	Wiring = IconAssets.Wiring,
	Cores = IconAssets.Cores,
}

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
	iconKind: ResourceIconKind,
	title: string,
	value: string,
	accent: Color3,
	compact: boolean
): any
	local iconSize = if compact then 38 else 50
	local textLeft = if compact then 39 else 52
	local titleVisible = not compact
	local image = RESOURCE_IMAGES[iconKind]

	return React.createElement("Frame", {
		BackgroundColor3 = COLORS.Panel,
		BackgroundTransparency = 0.04,
		BorderSizePixel = 0,
		ClipsDescendants = false,
		Size = UDim2.new(0.25, -7, 1, 0),
	}, {
		Corner = Components.Corner(if compact then 12 else 16),
		Stroke = React.createElement("UIStroke", {
			Color = accent,
			Transparency = 0.12,
			Thickness = if compact then 1.5 else 2,
		}),
		Gradient = React.createElement("UIGradient", {
			Color = ColorSequence.new({
				ColorSequenceKeypoint.new(0, accent:Lerp(COLORS.Panel, 0.72)),
				ColorSequenceKeypoint.new(0.32, COLORS.Panel),
				ColorSequenceKeypoint.new(1, COLORS.PanelAlt),
			}),
			Rotation = 8,
		}),
		IconShadow = React.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = image,
			ImageColor3 = Color3.new(0, 0, 0),
			ImageTransparency = 0.55,
			Position = UDim2.new(0, if compact then -1 else -4, 0.5, 3),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(iconSize, iconSize),
			ZIndex = 1,
		}),
		Icon = React.createElement("ImageLabel", {
			AnchorPoint = Vector2.new(0, 0.5),
			BackgroundTransparency = 1,
			BorderSizePixel = 0,
			Image = image,
			Position = UDim2.new(0, if compact then -3 else -6, 0.5, 0),
			ScaleType = Enum.ScaleType.Fit,
			Size = UDim2.fromOffset(iconSize, iconSize),
			ZIndex = 3,
		}),
		Title = titleVisible and React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = UDim2.fromOffset(textLeft, 6),
			Size = UDim2.new(1, -(textLeft + 9), 0, 13),
			Text = title,
			TextColor3 = accent:Lerp(Color3.new(1, 1, 1), 0.3),
			TextSize = 9,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextStrokeTransparency = 0.75,
			ZIndex = 2,
		}) or nil,
		Value = React.createElement("TextLabel", {
			BackgroundTransparency = 1,
			Font = Enum.Font.GothamBold,
			Position = if compact
				then UDim2.fromOffset(textLeft, 0)
				else UDim2.fromOffset(textLeft, 20),
			Size = if compact
				then UDim2.new(1, -(textLeft + 7), 1, 0)
				else UDim2.new(1, -(textLeft + 8), 0, 26),
			Text = value,
			TextColor3 = COLORS.Text,
			TextSize = if compact then 15 else 19,
			TextXAlignment = Enum.TextXAlignment.Left,
			TextYAlignment = Enum.TextYAlignment.Center,
			TextStrokeTransparency = 0.62,
			ZIndex = 2,
		}),
	})
end

return table.freeze(Components)
