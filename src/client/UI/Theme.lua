--!strict

local Theme = {}

Theme.Colors = table.freeze({
	Panel = Color3.fromRGB(24, 27, 34),
	PanelAlt = Color3.fromRGB(34, 38, 47),
	PanelSoft = Color3.fromRGB(43, 48, 59),
	Text = Color3.fromRGB(245, 247, 250),
	Muted = Color3.fromRGB(170, 178, 190),
	Accent = Color3.fromRGB(104, 214, 156),
	AccentDark = Color3.fromRGB(48, 132, 88),
	Danger = Color3.fromRGB(228, 101, 101),
})

Theme.RarityColors = table.freeze({
	Common = Color3.fromRGB(182, 188, 199),
	Uncommon = Color3.fromRGB(91, 199, 121),
	Rare = Color3.fromRGB(83, 151, 232),
	Epic = Color3.fromRGB(186, 95, 229),
})

Theme.RarityOrder = table.freeze({
	Common = 1,
	Uncommon = 2,
	Rare = 3,
	Epic = 4,
})

Theme.UpgradeFields = table.freeze({
	ProcessorSpeed = "ProcessorLevel",
	AssemblerSpeed = "AssemblerLevel",
	Storage = "StorageLevel",
	WorkSlots = "WorkSlotsLevel",
})

Theme.UpgradeOrder = table.freeze({
	"ProcessorSpeed",
	"AssemblerSpeed",
	"Storage",
	"WorkSlots",
})

return table.freeze(Theme)
