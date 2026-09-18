--!strict

local AssetService = game:GetService("AssetService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local JestGlobals = require(ReplicatedStorage.DevPackages.JestGlobals)
local expect = JestGlobals.expect
local it = JestGlobals.it

local ASSET_ID = 99200681519083

it("inspects Creator Store icon pack", function()
	local success, loadedOrError = pcall(AssetService.LoadAssetAsync, AssetService, ASSET_ID)
	expect(success).toBe(true)

	local model = loadedOrError :: Instance
	print(("ICON_PACK_ROOT|%s|%s"):format(model.ClassName, model.Name))

	local descendants = model:GetDescendants()
	table.sort(descendants, function(a, b)
		return a:GetFullName() < b:GetFullName()
	end)

	local decalCount = 0
	for _, instance in descendants do
		if instance:IsA("Decal") then
			decalCount += 1
			print(("ICON_PACK_DECAL|%s|%s"):format(instance:GetFullName(), instance.Texture))
		elseif instance:IsA("Texture") then
			print(("ICON_PACK_TEXTURE|%s|%s"):format(instance:GetFullName(), instance.Texture))
		elseif instance:IsA("ImageLabel") or instance:IsA("ImageButton") then
			print(("ICON_PACK_IMAGE|%s|%s"):format(instance:GetFullName(), instance.Image))
		end
	end

	print(("ICON_PACK_SUMMARY|descendants=%d|decals=%d"):format(#descendants, decalCount))
	expect(decalCount).toBeGreaterThan(0)

	model:Destroy()
end)
