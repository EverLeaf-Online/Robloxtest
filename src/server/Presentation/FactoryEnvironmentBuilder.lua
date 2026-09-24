--!strict

local Kit = require(script.Parent.Parent.Content.ScrapyardWorkshopKit)
local FactoryAssetLibrary = require(script.Parent.FactoryAssetLibrary)
local ScrapProcessAssetBuilder = require(script.Parent.ScrapProcessAssetBuilder)

local FactoryEnvironmentBuilder = {}

local function addSign(part: BasePart, text: string)
	local surface = Instance.new("SurfaceGui")
	surface.Name = "IndustrialSign"
	surface.Face = Enum.NormalId.Front
	surface.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surface.PixelsPerStud = 24
	surface.LightInfluence = 0.25
	surface.Parent = part
	local label = Instance.new("TextLabel")
	label.Size = UDim2.fromScale(1, 1)
	label.BackgroundTransparency = 1
	label.Text = text
	label.TextColor3 = Color3.fromRGB(246, 236, 202)
	label.Font = Enum.Font.GothamBold
	label.TextScaled = true
	label.TextWrapped = true
	label.Parent = surface
	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0.06, 0)
	padding.PaddingRight = UDim.new(0.06, 0)
	padding.Parent = label
end

function FactoryEnvironmentBuilder.Build(plot: Model, plotId: number, center: Vector3): Model
	local existing = plot:FindFirstChild("FactoryEnvironment")
	if existing ~= nil then
		assert(existing:IsA("Model"), "FactoryEnvironment must be a Model")
		return existing
	end

	FactoryAssetLibrary.Preload({
		"IndustrialScrapShredder",
		"HydraulicScrapBaler",
		"MagneticSortingConveyor",
		"InfeedConveyor",
		"OutfeedConveyor",
		"ScrapPileMedium",
		"MaterialBin",
		"SalvageTruck",
	})
	local root = Instance.new("Model")
	root.Name = "FactoryEnvironment"
	root:SetAttribute("FactoryEnvironmentAsset", true)
	root:SetAttribute("ArtRevision", "ScrapyardWorkshop2")
	-- Build off-tree to avoid showing a partially assembled kit.
	local groups: { [string]: Model } = {}

	-- Prefer the authored hard-surface truck, while retaining the native
	-- WorkshopKit collision shell as an invisible server-owned proxy/fallback.
	local salvageTruckGroup = Instance.new("Model")
	salvageTruckGroup.Name = "SalvageTruck"
	salvageTruckGroup:SetAttribute("FactoryEnvironmentAsset", true)
	salvageTruckGroup.Parent = root
	groups.SalvageTruck = salvageTruckGroup
	local importedSalvageTruck = FactoryAssetLibrary.TryPlace(
		"SalvageTruck",
		salvageTruckGroup,
		CFrame.new(center + Vector3.new(-50.725, 0, -70.325)),
		plotId,
		36
	)
	local hasImportedSalvageTruck = importedSalvageTruck ~= nil
	if importedSalvageTruck ~= nil then
		importedSalvageTruck.Name = "SalvageTruckVisual"
	end

	for _, spec in Kit do
		if hasImportedSalvageTruck and spec.group == "SalvageTruck" and not spec.collision then
			continue
		end
		local group = groups[spec.group]
		if group == nil then
			group = Instance.new("Model")
			group.Name = spec.group
			group:SetAttribute("FactoryEnvironmentAsset", true)
			group.Parent = root
			groups[spec.group] = group
		end
		local piece = Instance.new("Part")
		piece.Name = spec.name
		piece.Size = Vector3.new(spec.size[1], spec.size[2], spec.size[3])
		piece.CFrame = CFrame.new(center + Vector3.new(spec.pos[1], spec.pos[2], spec.pos[3]))
			* CFrame.Angles(
				math.rad(spec.rotation[1]),
				math.rad(spec.rotation[2]),
				math.rad(spec.rotation[3])
			)
		piece.Color = Color3.fromRGB(spec.color[1], spec.color[2], spec.color[3])
		piece.Material = (Enum.Material :: any)[spec.material]
		piece.Shape = (Enum.PartType :: any)[spec.shape]
		piece.Anchored = true
		piece.CanCollide = spec.collision
		piece.CanQuery = spec.collision
		piece.CanTouch = false
		piece.CastShadow = spec.material ~= "Neon" and spec.size[2] > 0.15
		piece.TopSurface = Enum.SurfaceType.Smooth
		piece.BottomSurface = Enum.SurfaceType.Smooth
		piece:SetAttribute("PlotId", plotId)
		piece:SetAttribute("PresentationPart", true)
		piece.Parent = group
		if hasImportedSalvageTruck and spec.group == "SalvageTruck" then
			piece.Transparency = 1
			piece.CastShadow = false
		end
		if spec.text ~= nil then
			addSign(piece, spec.text)
		end
	end

	-- Retain the real salvage/sorting machinery and its authored collision.
	ScrapProcessAssetBuilder.Build(root, plotId, center)
	root.Parent = plot
	return root
end

return table.freeze(FactoryEnvironmentBuilder)
