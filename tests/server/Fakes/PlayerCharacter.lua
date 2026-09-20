--!strict

local PlayerCharacter = {}

local nearByPlayer: { [Player]: boolean } = {}
local positionByPlayer: { [Player]: Vector3 } = {}

function PlayerCharacter.Reset()
	table.clear(nearByPlayer)
	table.clear(positionByPlayer)
end

function PlayerCharacter.SetNear(player: Player, near: boolean)
	nearByPlayer[player] = near
end

function PlayerCharacter.SetPosition(player: Player, position: Vector3?)
	positionByPlayer[player] = position
end

function PlayerCharacter.GetPosition(player: Player): Vector3?
	return positionByPlayer[player]
end

function PlayerCharacter.IsNear(player: Player, _part: BasePart, _maxDistance: number): boolean
	return nearByPlayer[player] == true
end

return PlayerCharacter
