--!strict

local AssetService = game:GetService("AssetService")

local FactoryAssetRegistry = require(script.Parent.Parent.Content.FactoryAssetRegistry)

local FactoryAssetLibrary = {}

local BLOCKED_CLASSES: { [string]: boolean } = {
	Script = true,
	LocalScript = true,
	ModuleScript = true,
	RemoteEvent = true,
	RemoteFunction = true,
	BindableEvent = true,
	BindableFunction = true,
	ClickDetector = true,
	ProximityPrompt = true,
	Sound = true,
	Animation = true,
	Tool = true,
	Humanoid = true,
	AnimationController = true,
	Animator = true,
	Seat = true,
	VehicleSeat = true,
	BillboardGui = true,
	SurfaceGui = true,
	ScreenGui = true,
	ParticleEmitter = true,
	Beam = true,
	Trail = true,
	Smoke = true,
	Fire = true,
	Sparkles = true,
	Highlight = true,
}

local templateCache: { [string]: Model } = {}
local warnedFailures: { [string]: boolean } = {}

local function sanitizeStaticModel(model: Model, plotId: number?)
	for _, descendant in model:GetDescendants() do
		local blocked = BLOCKED_CLASSES[descendant.ClassName]
			or descendant:IsA("LuaSourceContainer")
			or descendant:IsA("Constraint")
			or descendant:IsA("JointInstance")
			or descendant:IsA("PackageLink")
			or descendant:IsA("LayerCollector")
			or descendant:IsA("GuiObject")

		if blocked then
			descendant:Destroy()
		elseif descendant:IsA("BasePart") then
			descendant.Anchored = true
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.CastShadow = true
			descendant:SetAttribute("PresentationPart", true)
			if plotId ~= nil then
				descendant:SetAttribute("PlotId", plotId)
			end
		end
	end
	model.PrimaryPart = nil
	model:SetAttribute("FactoryImportedAsset", true)
end

local function loadTemplate(assetKey: string): Model?
	local cached = templateCache[assetKey]
	if cached ~= nil then
		return cached
	end

	local spec = FactoryAssetRegistry[assetKey]
	if spec == nil then
		if not warnedFailures[assetKey] then
			warnedFailures[assetKey] = true
			warn(("[FactoryAssetLibrary] Unknown asset key %s"):format(assetKey))
		end
		return nil
	end

	local ok, containerOrError = pcall(function()
		return AssetService:LoadAssetAsync(spec.AssetId)
	end)
	if not ok or not containerOrError:IsA("Model") then
		if not warnedFailures[assetKey] then
			warnedFailures[assetKey] = true
			warn(
				("[FactoryAssetLibrary] Could not load %s (%d): %s"):format(
					assetKey,
					spec.AssetId,
					tostring(containerOrError)
				)
			)
		end
		return nil
	end

	local template = containerOrError :: Model
	template.Name = spec.DisplayName
	sanitizeStaticModel(template, nil)
	template.Parent = nil
	templateCache[assetKey] = template
	return template
end

local function scaleToTarget(model: Model, targetMaxDimension: number)
	local _, size = model:GetBoundingBox()
	local maxDimension = math.max(size.X, size.Y, size.Z)
	if maxDimension <= 0 or targetMaxDimension <= 0 then
		return
	end

	local scaleFactor = targetMaxDimension / maxDimension
	model:ScaleTo(model:GetScale() * scaleFactor)
end

local function groundAndCenter(model: Model, targetCFrame: CFrame)
	local currentPivot = model:GetPivot()
	model:PivotTo(CFrame.new(currentPivot.Position) * targetCFrame.Rotation)

	local boundsCFrame, boundsSize = model:GetBoundingBox()
	local boundsBottomY = boundsCFrame.Position.Y - (boundsSize.Y / 2)
	local offset = Vector3.new(
		targetCFrame.Position.X - boundsCFrame.Position.X,
		targetCFrame.Position.Y - boundsBottomY,
		targetCFrame.Position.Z - boundsCFrame.Position.Z
	)
	model:PivotTo(model:GetPivot() + offset)
end

function FactoryAssetLibrary.Preload(assetKeys: { string })
	local pending: { string } = {}
	local scheduled: { [string]: boolean } = {}

	for _, assetKey in assetKeys do
		if
			not scheduled[assetKey]
			and templateCache[assetKey] == nil
			and FactoryAssetRegistry[assetKey] ~= nil
		then
			scheduled[assetKey] = true
			table.insert(pending, assetKey)
		end
	end

	if #pending == 0 then
		return
	end

	local completed = 0
	for _, assetKey in pending do
		task.spawn(function()
			loadTemplate(assetKey)
			completed += 1
		end)
	end

	while completed < #pending do
		task.wait()
	end
end

function FactoryAssetLibrary.TryPlace(
	assetKey: string,
	parent: Instance,
	targetCFrame: CFrame,
	plotId: number,
	targetMaxDimensionOverride: number?
): Model?
	local spec = FactoryAssetRegistry[assetKey]
	local template = loadTemplate(assetKey)
	if spec == nil or template == nil then
		return nil
	end

	local clone = template:Clone()
	sanitizeStaticModel(clone, plotId)
	local targetMaxDimension = targetMaxDimensionOverride or spec.TargetMaxDimension
	if targetMaxDimension <= 0 or targetMaxDimension ~= targetMaxDimension then
		clone:Destroy()
		return nil
	end
	scaleToTarget(clone, targetMaxDimension)
	groundAndCenter(clone, targetCFrame)
	clone.Parent = parent
	return clone
end

return table.freeze(FactoryAssetLibrary)
