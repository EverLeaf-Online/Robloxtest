--!strict

local PlayerCharacter = {}

function PlayerCharacter.GetPosition(player: Player): Vector3?
	local character = player.Character
	if character == nil then
		return nil
	end

	local root = character:FindFirstChild("HumanoidRootPart")
	if root == nil or not root:IsA("BasePart") then
		return nil
	end

	return root.Position
end

function PlayerCharacter.IsNear(player: Player, part: BasePart, maxDistance: number): boolean
	local position = PlayerCharacter.GetPosition(player)
	return position ~= nil and (position - part.Position).Magnitude <= maxDistance
end

return table.freeze(PlayerCharacter)
