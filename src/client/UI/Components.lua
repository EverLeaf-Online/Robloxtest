--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local Theme = require(script.Parent.Theme)

local COLORS = Theme.Colors
local Components = {}

type ResourceIconKind = "Credits" | "Scrap" | "Wiring" | "Cores"

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

local function circleCorner(): any
	return React.createElement("UICorner", {
		CornerRadius = UDim.new(1, 0),
	})
end

local function resourceIcon(kind: ResourceIconKind, accent: Color3): any
	local white = Color3.fromRGB(247, 249, 252)
	local dark = Color3.fromRGB(34, 39, 47)

	if kind == "Credits" then
		return React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			CoinBack = React.createElement("Frame", {
				BackgroundColor3 = Color3.fromRGB(215, 162, 48),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.18, 0.22),
				Size = UDim2.fromScale(0.48, 0.48),
			}, {
				Corner = circleCorner(),
				Stroke = React.createElement("UIStroke", {
					Color = white,
					Transparency = 0.48,
					Thickness = 1,
				}),
			}),
			CoinFront = React.createElement("Frame", {
				BackgroundColor3 = Color3.fromRGB(242, 194, 67),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.36, 0.36),
				Size = UDim2.fromScale(0.48, 0.48),
			}, {
				Corner = circleCorner(),
				Stroke = React.createElement("UIStroke", {
					Color = white,
					Transparency = 0.2,
					Thickness = 1.25,
				}),
				Inset = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = Color3.fromRGB(255, 221, 105),
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.54, 0.54),
				}, {
					Corner = circleCorner(),
				}),
			}),
		})
	elseif kind == "Scrap" then
		return React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			Plate = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(181, 190, 199),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Rotation = -12,
				Size = UDim2.fromScale(0.62, 0.48),
			}, {
				Corner = Components.Corner(4),
				Stroke = React.createElement("UIStroke", {
					Color = Color3.fromRGB(235, 239, 244),
					Transparency = 0.28,
					Thickness = 1,
				}),
			}),
			Bolt = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = dark,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.24, 0.24),
			}, {
				Corner = circleCorner(),
				Core = React.createElement("Frame", {
					AnchorPoint = Vector2.new(0.5, 0.5),
					BackgroundColor3 = accent,
					BorderSizePixel = 0,
					Position = UDim2.fromScale(0.5, 0.5),
					Size = UDim2.fromScale(0.42, 0.42),
				}, {
					Corner = circleCorner(),
				}),
			}),
			RivetOne = React.createElement("Frame", {
				BackgroundColor3 = white,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.25, 0.32),
				Size = UDim2.fromScale(0.09, 0.09),
			}, {
				Corner = circleCorner(),
			}),
			RivetTwo = React.createElement("Frame", {
				BackgroundColor3 = white,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.66, 0.58),
				Size = UDim2.fromScale(0.09, 0.09),
			}, {
				Corner = circleCorner(),
			}),
		})
	elseif kind == "Wiring" then
		return React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			Cable = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(247, 214, 92),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.52),
				Rotation = -18,
				Size = UDim2.fromScale(0.58, 0.12),
			}, {
				Corner = Components.Corner(3),
			}),
			PlugLeft = React.createElement("Frame", {
				BackgroundColor3 = white,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.16, 0.54),
				Rotation = -18,
				Size = UDim2.fromScale(0.22, 0.24),
			}, {
				Corner = Components.Corner(3),
			}),
			PlugRight = React.createElement("Frame", {
				BackgroundColor3 = white,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.61, 0.22),
				Rotation = -18,
				Size = UDim2.fromScale(0.22, 0.24),
			}, {
				Corner = Components.Corner(3),
			}),
			Node = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = accent,
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Size = UDim2.fromScale(0.2, 0.2),
			}, {
				Corner = circleCorner(),
				Stroke = React.createElement("UIStroke", {
					Color = white,
					Transparency = 0.08,
					Thickness = 1.5,
				}),
			}),
		})
	else
		return React.createElement("Frame", {
			BackgroundTransparency = 1,
			Size = UDim2.fromScale(1, 1),
		}, {
			Outer = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(87, 184, 244),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Rotation = 45,
				Size = UDim2.fromScale(0.58, 0.58),
			}, {
				Corner = Components.Corner(5),
				Stroke = React.createElement("UIStroke", {
					Color = white,
					Transparency = 0.1,
					Thickness = 1.5,
				}),
			}),
			Inner = React.createElement("Frame", {
				AnchorPoint = Vector2.new(0.5, 0.5),
				BackgroundColor3 = Color3.fromRGB(198, 238, 255),
				BorderSizePixel = 0,
				Position = UDim2.fromScale(0.5, 0.5),
				Rotation = 45,
				Size = UDim2.fromScale(0.3, 0.3),
			}, {
				Corner = Components.Corner(3),
			}),
		})
	end
end

function Components.ResourceChip(
	iconKind: ResourceIconKind,
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
			BackgroundColor3 = accent:Lerp(COLORS.Panel, 0.45),
			BorderSizePixel = 0,
			Position = UDim2.new(0, 6, 0.5, 0),
			Size = UDim2.fromOffset(iconSize, iconSize),
		}, {
			Corner = circleCorner(),
			Stroke = React.createElement("UIStroke", {
				Color = accent,
				Transparency = 0.08,
				Thickness = 1.25,
			}),
			Visual = resourceIcon(iconKind, accent),
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
