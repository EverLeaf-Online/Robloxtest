--!strict

local RecipeDisplay = {}

local MATERIAL_ORDER = table.freeze({
	"ScrapMetal",
	"Wiring",
	"PowerCoreFragments",
})

local MATERIAL_LABELS = table.freeze({
	ScrapMetal = "Scrap",
	Wiring = "Wiring",
	PowerCoreFragments = "Core",
})

function RecipeDisplay.FormatMaterials(materials: { [string]: number }): string
	local parts = {}

	for _, materialId in MATERIAL_ORDER do
		local amount = materials[materialId]
		if typeof(amount) == "number" and amount > 0 then
			local label = MATERIAL_LABELS[materialId] or materialId
			table.insert(parts, ("%d %s"):format(math.floor(amount), label))
		end
	end

	return if #parts > 0 then table.concat(parts, " + ") else "Nothing"
end

return table.freeze(RecipeDisplay)
