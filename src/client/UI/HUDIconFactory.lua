--!strict

local HUDIconFactory = {}

local function round(instance: GuiObject, radius: number)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, radius)
	corner.Parent = instance
end

local function circle(instance: GuiObject)
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(1, 0)
	corner.Parent = instance
end

local function makeRoot(parent: Instance, size: number, background: Color3): Frame
	local root = Instance.new("Frame")
	root.Name = "Icon"
	root.AnchorPoint = Vector2.new(0.5, 0)
	root.Position = UDim2.fromScale(0.5, 0)
	root.Size = UDim2.fromOffset(size, size)
	root.BackgroundColor3 = background
	root.BorderSizePixel = 0
	root.Parent = parent
	circle(root)

	local stroke = Instance.new("UIStroke")
	stroke.Color = Color3.new(1, 1, 1)
	stroke.Transparency = 0.78
	stroke.Thickness = 1
	stroke.Parent = root

	return root
end

function HUDIconFactory.CreateShop(parent: Instance, size: number): Frame
	local root = makeRoot(parent, size, Color3.fromRGB(38, 126, 91))
	local scale = size / 48

	local basket = Instance.new("Frame")
	basket.Name = "Basket"
	basket.Position = UDim2.fromOffset(math.floor(11 * scale), math.floor(15 * scale))
	basket.Size = UDim2.fromOffset(math.floor(24 * scale), math.floor(15 * scale))
	basket.BackgroundColor3 = Color3.fromRGB(245, 247, 250)
	basket.BorderSizePixel = 0
	basket.Rotation = -4
	basket.Parent = root
	round(basket, math.max(2, math.floor(3 * scale)))

	local handle = Instance.new("Frame")
	handle.Name = "Handle"
	handle.Position = UDim2.fromOffset(math.floor(8 * scale), math.floor(10 * scale))
	handle.Size = UDim2.fromOffset(math.floor(9 * scale), math.floor(4 * scale))
	handle.BackgroundColor3 = Color3.fromRGB(245, 247, 250)
	handle.BorderSizePixel = 0
	handle.Rotation = 28
	handle.Parent = root
	round(handle, math.max(1, math.floor(2 * scale)))

	for index, x in { 15, 31 } do
		local wheel = Instance.new("Frame")
		wheel.Name = ("Wheel%d"):format(index)
		wheel.Position = UDim2.fromOffset(math.floor(x * scale), math.floor(33 * scale))
		wheel.Size = UDim2.fromOffset(math.floor(6 * scale), math.floor(6 * scale))
		wheel.BackgroundColor3 = Color3.fromRGB(245, 247, 250)
		wheel.BorderSizePixel = 0
		wheel.Parent = root
		circle(wheel)
	end

	return root
end

function HUDIconFactory.CreateAdmin(parent: Instance, size: number): Frame
	local root = makeRoot(parent, size, Color3.fromRGB(45, 112, 205))
	local scale = size / 48

	local center = Instance.new("Frame")
	center.Name = "Emitter"
	center.AnchorPoint = Vector2.new(0.5, 0.5)
	center.Position = UDim2.fromScale(0.5, 0.43)
	center.Size = UDim2.fromOffset(math.floor(7 * scale), math.floor(7 * scale))
	center.BackgroundColor3 = Color3.fromRGB(245, 247, 250)
	center.BorderSizePixel = 0
	center.Parent = root
	circle(center)

	for index, diameter in { 20, 31 } do
		local ring = Instance.new("Frame")
		ring.Name = ("Ring%d"):format(index)
		ring.AnchorPoint = Vector2.new(0.5, 0.5)
		ring.Position = UDim2.fromScale(0.5, 0.43)
		ring.Size = UDim2.fromOffset(math.floor(diameter * scale), math.floor(diameter * scale))
		ring.BackgroundTransparency = 1
		ring.Parent = root
		circle(ring)

		local stroke = Instance.new("UIStroke")
		stroke.Color = Color3.fromRGB(245, 247, 250)
		stroke.Thickness = math.max(1, math.floor(2 * scale))
		stroke.Transparency = if index == 1 then 0.12 else 0.3
		stroke.Parent = ring
	end

	local stem = Instance.new("Frame")
	stem.Name = "Stem"
	stem.AnchorPoint = Vector2.new(0.5, 0)
	stem.Position = UDim2.fromScale(0.5, 0.55)
	stem.Size = UDim2.fromOffset(math.floor(4 * scale), math.floor(13 * scale))
	stem.BackgroundColor3 = Color3.fromRGB(245, 247, 250)
	stem.BorderSizePixel = 0
	stem.Parent = root
	round(stem, math.max(1, math.floor(2 * scale)))

	local base = Instance.new("Frame")
	base.Name = "Base"
	base.AnchorPoint = Vector2.new(0.5, 0)
	base.Position = UDim2.fromScale(0.5, 0.76)
	base.Size = UDim2.fromOffset(math.floor(18 * scale), math.floor(4 * scale))
	base.BackgroundColor3 = Color3.fromRGB(245, 247, 250)
	base.BorderSizePixel = 0
	base.Parent = root
	round(base, math.max(1, math.floor(2 * scale)))

	return root
end

function HUDIconFactory.CreateTools(parent: Instance, size: number): Frame
	local root = makeRoot(parent, size, Color3.fromRGB(45, 52, 64))
	local scale = size / 48

	local wrench = Instance.new("Frame")
	wrench.Name = "Wrench"
	wrench.AnchorPoint = Vector2.new(0.5, 0.5)
	wrench.Position = UDim2.fromScale(0.49, 0.5)
	wrench.Size = UDim2.fromOffset(math.floor(6 * scale), math.floor(29 * scale))
	wrench.BackgroundColor3 = Color3.fromRGB(245, 247, 250)
	wrench.BorderSizePixel = 0
	wrench.Rotation = 43
	wrench.Parent = root
	round(wrench, math.max(1, math.floor(3 * scale)))

	local wrenchHead = Instance.new("Frame")
	wrenchHead.Name = "WrenchHead"
	wrenchHead.AnchorPoint = Vector2.new(0.5, 0.5)
	wrenchHead.Position = UDim2.fromScale(0.31, 0.31)
	wrenchHead.Size = UDim2.fromOffset(math.floor(12 * scale), math.floor(12 * scale))
	wrenchHead.BackgroundColor3 = Color3.fromRGB(245, 247, 250)
	wrenchHead.BorderSizePixel = 0
	wrenchHead.Parent = root
	circle(wrenchHead)

	local wrenchCutout = Instance.new("Frame")
	wrenchCutout.Name = "WrenchCutout"
	wrenchCutout.AnchorPoint = Vector2.new(0.5, 0.5)
	wrenchCutout.Position = UDim2.fromScale(0.31, 0.31)
	wrenchCutout.Size = UDim2.fromOffset(math.floor(5 * scale), math.floor(5 * scale))
	wrenchCutout.BackgroundColor3 = root.BackgroundColor3
	wrenchCutout.BorderSizePixel = 0
	wrenchCutout.Parent = root
	circle(wrenchCutout)

	local driver = Instance.new("Frame")
	driver.Name = "Driver"
	driver.AnchorPoint = Vector2.new(0.5, 0.5)
	driver.Position = UDim2.fromScale(0.55, 0.53)
	driver.Size = UDim2.fromOffset(math.floor(5 * scale), math.floor(27 * scale))
	driver.BackgroundColor3 = Color3.fromRGB(104, 214, 156)
	driver.BorderSizePixel = 0
	driver.Rotation = -43
	driver.Parent = root
	round(driver, math.max(1, math.floor(2 * scale)))

	local driverHandle = Instance.new("Frame")
	driverHandle.Name = "DriverHandle"
	driverHandle.AnchorPoint = Vector2.new(0.5, 0.5)
	driverHandle.Position = UDim2.fromScale(0.72, 0.72)
	driverHandle.Size = UDim2.fromOffset(math.floor(9 * scale), math.floor(13 * scale))
	driverHandle.BackgroundColor3 = Color3.fromRGB(104, 214, 156)
	driverHandle.BorderSizePixel = 0
	driverHandle.Rotation = -43
	driverHandle.Parent = root
	round(driverHandle, math.max(2, math.floor(3 * scale)))

	return root
end

return table.freeze(HUDIconFactory)
