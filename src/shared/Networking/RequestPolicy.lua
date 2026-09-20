--!strict

local GameConfig = require(script.Parent.Parent.Config.GameConfig)
local RemoteNames = require(script.Parent.RemoteNames)

type ArgumentPolicy = {
	Kind: "string" | "number",
	MaxLength: number?,
	Integer: boolean?,
	Minimum: number?,
	Maximum: number?,
}

type RequestPolicyDefinition = {
	Arguments: { ArgumentPolicy },
}

local STRING_ID: ArgumentPolicy = table.freeze({
	Kind = "string",
	MaxLength = GameConfig.Networking.MaxStringLength,
})

local REQUESTS: { [string]: RequestPolicyDefinition } = {
	[RemoteNames.RequestState] = table.freeze({ Arguments = {} }),
	[RemoteNames.RequestCollect] = table.freeze({ Arguments = { STRING_ID } }),
	[RemoteNames.RequestProcess] = table.freeze({ Arguments = { STRING_ID } }),
	[RemoteNames.RequestAssemble] = table.freeze({ Arguments = {} }),
	[RemoteNames.RequestAssignRobot] = table.freeze({ Arguments = { STRING_ID, STRING_ID } }),
	[RemoteNames.RequestUnassignRobot] = table.freeze({ Arguments = { STRING_ID } }),
	[RemoteNames.RequestSellRobot] = table.freeze({ Arguments = { STRING_ID } }),
	[RemoteNames.RequestUpgrade] = table.freeze({ Arguments = { STRING_ID } }),
	[RemoteNames.RequestUnlockZone] = table.freeze({
		Arguments = {
			table.freeze({
				Kind = "number",
				Integer = true,
				Minimum = 2,
				Maximum = 100,
			}),
		},
	}),
	[RemoteNames.RequestPrestige] = table.freeze({ Arguments = {} }),
	[RemoteNames.RequestUseInstantProcessToken] = table.freeze({ Arguments = {} }),
	[RemoteNames.RequestEquipClubCosmetic] = table.freeze({ Arguments = { STRING_ID } }),
	[RemoteNames.RequestAdminBroadcast] = table.freeze({
		Arguments = {
			table.freeze({
				Kind = "string",
				MaxLength = 120,
			}),
		},
	}),
	[RemoteNames.RequestAdminFreshProfileReset] = table.freeze({
		Arguments = {
			table.freeze({
				Kind = "string",
				MaxLength = 5,
			}),
		},
	}),
}

local RequestPolicy = {}

local function validateArgument(value: any, policy: ArgumentPolicy): boolean
	if policy.Kind == "string" then
		if typeof(value) ~= "string" then
			return false
		end
		local stringValue = value :: string
		local maximumLength = policy.MaxLength or GameConfig.Networking.MaxStringLength
		return #stringValue > 0 and #stringValue <= maximumLength
	end

	if typeof(value) ~= "number" then
		return false
	end
	local numberValue = value :: number
	if numberValue ~= numberValue or numberValue <= -math.huge or numberValue >= math.huge then
		return false
	end
	if policy.Integer == true and numberValue % 1 ~= 0 then
		return false
	end
	if policy.Minimum ~= nil and numberValue < policy.Minimum then
		return false
	end
	if policy.Maximum ~= nil and numberValue > policy.Maximum then
		return false
	end
	return true
end

function RequestPolicy.Validate(requestName: string, ...: any): (boolean, string?)
	local definition = REQUESTS[requestName]
	if definition == nil then
		return false, "UNKNOWN_REQUEST"
	end

	local arguments = table.pack(...)
	if arguments.n ~= #definition.Arguments then
		return false, "INVALID_ARGUMENT_COUNT"
	end

	for index, argumentPolicy in definition.Arguments do
		if not validateArgument(arguments[index], argumentPolicy) then
			return false, ("INVALID_ARGUMENT_%d"):format(index)
		end
	end

	return true, nil
end

return table.freeze(RequestPolicy)
