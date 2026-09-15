local Workspace = game:GetService("Workspace")

-- This project is a space-view experience. Remove Roblox Studio's stock template
-- geometry if the source is synced into a default Baseplate place.
local baseplate = Workspace:FindFirstChild("Baseplate")
if baseplate and baseplate:IsA("BasePart") then
	baseplate:Destroy()
end

for _, child in ipairs(Workspace:GetChildren()) do
	if child:IsA("SpawnLocation") then
		child:Destroy()
	end
end

Workspace.FallenPartsDestroyHeight = -1000
