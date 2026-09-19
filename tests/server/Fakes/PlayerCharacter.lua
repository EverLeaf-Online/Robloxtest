--!strict

local PlayerCharacter = {}

local nearByPlayer: { [Player]: boolean } = {}

function PlayerCharacter.Reset()
	table.clear(nearByPlayer)
end

function PlayerCharacter.SetNear(player: Player, near: boolean)
	nearByPlayer[player] = near
end

function PlayerCharacter.IsNear(player: Player, _part: BasePart, _maxDistance: number): boolean
	return nearByPlayer[player] == true
end

return PlayerCharacter
