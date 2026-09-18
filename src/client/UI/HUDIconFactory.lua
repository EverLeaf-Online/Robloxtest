--!strict

local IconAssets = require(script.Parent.IconAssets)

local HUDIconFactory = {}

local function makeIcon(parent: Instance, size: number, image: string): ImageLabel
	local icon = Instance.new("ImageLabel")
	icon.Name = "Icon"
	icon.AnchorPoint = Vector2.new(0.5, 0)
	icon.Position = UDim2.fromScale(0.5, 0)
	icon.Size = UDim2.fromOffset(size, size)
	icon.BackgroundTransparency = 1
	icon.BorderSizePixel = 0
	icon.Image = image
	icon.ScaleType = Enum.ScaleType.Fit
	icon.Parent = parent

	return icon
end

function HUDIconFactory.CreateShop(parent: Instance, size: number): ImageLabel
	return makeIcon(parent, size, IconAssets.Shop)
end

function HUDIconFactory.CreateAdmin(parent: Instance, size: number): ImageLabel
	return makeIcon(parent, size, IconAssets.Admin)
end

function HUDIconFactory.CreateTools(parent: Instance, size: number): ImageLabel
	return makeIcon(parent, size, IconAssets.Tools)
end

return table.freeze(HUDIconFactory)
