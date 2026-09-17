--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local FactoryRules = require(ReplicatedStorage.Shared.Domain.FactoryRules)
local RemoteNames = require(ReplicatedStorage.Shared.Networking.RemoteNames)
local Robots = require(ReplicatedStorage.Shared.Config.Robots)
local Upgrades = require(ReplicatedStorage.Shared.Config.Upgrades)

local Components = require(script.Parent.Components)
local StateHelpers = require(script.Parent.StateHelpers)
local Theme = require(script.Parent.Theme)

local COLORS = Theme.Colors
local rarityColors = Theme.RarityColors
local rarityOrder = Theme.RarityOrder
local upgradeFields = Theme.UpgradeFields
local upgradeOrder = Theme.UpgradeOrder
local Remotes = ReplicatedStorage:WaitForChild("Remotes")

local PanelContent = {}

local function getRemote(name: string): RemoteEvent
	return Remotes:WaitForChild(name) :: RemoteEvent
end

local function buildRobotRows(snapshot: any, extraWorkSlots: number): any
	local rows: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local ids = {}
	for uid in snapshot.Robots.OwnedByUid do
		table.insert(ids, uid)
	end
	table.sort(ids)
	if #ids == 0 then
		rows.Empty = Components.TextLabel("No bots yet. Build one at the assembler.", 13, COLORS.Muted)
		return rows
	end

	for index, uid in ids do
		local owned = snapshot.Robots.OwnedByUid[uid]
		local definition = Robots.Definitions[owned.RobotId]
		if definition ~= nil then
			local assignedPad = StateHelpers.GetAssignedPad(snapshot, uid)
			local freePad = StateHelpers.FirstFreePad(snapshot, extraWorkSlots)
			local canRecycle = assignedPad == nil
			local assignmentText = "No Slot"
			local assignmentCallback: (() -> ())? = nil
			if assignedPad ~= nil then
				assignmentText = "Unassign"
				assignmentCallback = function()
					getRemote(RemoteNames.RequestUnassignRobot):FireServer(uid)
				end
			elseif freePad ~= nil then
				assignmentText = "Assign"
				assignmentCallback = function()
					getRemote(RemoteNames.RequestAssignRobot):FireServer(uid, freePad)
				end
			end

			rows[("Robot_%s"):format(uid)] = React.createElement("Frame", {
				BackgroundColor3 = COLORS.PanelSoft,
				BorderSizePixel = 0,
				LayoutOrder = index,
				Size = UDim2.new(1, 0, 0, 58),
			}, {
				Corner = Components.Corner(8),
				Name = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.GothamBold,
					Position = UDim2.fromOffset(10, 7),
					Size = UDim2.new(1, -210, 0, 20),
					Text = definition.DisplayName,
					TextColor3 = COLORS.Text,
					TextSize = 14,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Meta = React.createElement("TextLabel", {
					BackgroundTransparency = 1,
					Font = Enum.Font.Gotham,
					Position = UDim2.fromOffset(10, 30),
					Size = UDim2.new(1, -210, 0, 18),
					Text = ("%s • %.1f credits/s • %s"):format(
						definition.Rarity,
						definition.ProductionPerSecond,
						assignedPad or "Idle"
					),
					TextColor3 = COLORS.Muted,
					TextSize = 11,
					TextXAlignment = Enum.TextXAlignment.Left,
				}),
				Assign = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.new(1, -198, 0.5, -16),
					Size = UDim2.fromOffset(92, 32),
				}, {
					Button = Components.Button(assignmentText, assignmentCallback ~= nil, assignmentCallback),
				}),
				Recycle = React.createElement("Frame", {
					BackgroundTransparency = 1,
					Position = UDim2.new(1, -100, 0.5, -16),
					Size = UDim2.fromOffset(92, 32),
				}, {
					Button = Components.Button(
						("Recycle +%s"):format(StateHelpers.FormatNumber(definition.RecycleCredits)),
						canRecycle,
						if canRecycle
							then function()
								getRemote(RemoteNames.RequestSellRobot):FireServer(uid)
							end
							else nil
					),
				}),
			})
		end
	end
	return rows
end

local function buildUpgradeRows(snapshot: any): any
	local rows: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	for index, upgradeId in upgradeOrder do
		local definition = Upgrades[upgradeId]
		local field = upgradeFields[upgradeId]
		local currentLevel = snapshot.Machines[field]
		local nextLevel = FactoryRules.GetNextUpgrade(upgradeId, currentLevel)
		local enabled = nextLevel ~= nil and snapshot.Currencies.Credits >= nextLevel.CostCredits
		local valueText = if nextLevel
			then ("Next: %s • %s credits"):format(
				tostring(nextLevel.Value),
				StateHelpers.FormatNumber(nextLevel.CostCredits)
			)
			else "Maximum level reached"

		rows[("Upgrade_%s"):format(upgradeId)] = React.createElement("Frame", {
			BackgroundColor3 = COLORS.PanelSoft,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 62),
		}, {
			Corner = Components.Corner(8),
			Name = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromOffset(10, 8),
				Size = UDim2.new(1, -116, 0, 20),
				Text = ("%s • Lv.%d"):format(definition.DisplayName, currentLevel),
				TextColor3 = COLORS.Text,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Meta = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				Position = UDim2.fromOffset(10, 31),
				Size = UDim2.new(1, -116, 0, 18),
				Text = valueText,
				TextColor3 = COLORS.Muted,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Buy = React.createElement("Frame", {
				BackgroundTransparency = 1,
				Position = UDim2.new(1, -102, 0.5, -16),
				Size = UDim2.fromOffset(92, 32),
			}, {
				Button = Components.Button(
					nextLevel and "Upgrade" or "Max",
					enabled,
					if nextLevel
						then function()
							getRemote(RemoteNames.RequestUpgrade):FireServer(upgradeId)
						end
						else nil
				),
			}),
		})
	end
	return rows
end

local function buildIndexRows(snapshot: any): any
	local rows: { [string]: any } = {
		Layout = React.createElement("UIListLayout", {
			Padding = UDim.new(0, 8),
			SortOrder = Enum.SortOrder.LayoutOrder,
		}),
	}
	local robotIds = {}
	for robotId in Robots.Definitions do
		table.insert(robotIds, robotId)
	end
	table.sort(robotIds, function(leftId, rightId)
		local left = Robots.Definitions[leftId]
		local right = Robots.Definitions[rightId]
		local leftRank = rarityOrder[left.Rarity] or 99
		local rightRank = rarityOrder[right.Rarity] or 99
		if leftRank ~= rightRank then
			return leftRank < rightRank
		end
		return left.DisplayName < right.DisplayName
	end)

	for index, robotId in robotIds do
		local definition = Robots.Definitions[robotId]
		local seen = snapshot.Collection.RobotSeen[robotId] == true
		local ownedCount = StateHelpers.CountOwnedRobotId(snapshot, robotId)
		local title = if seen then definition.DisplayName else "???"
		local meta = if seen
			then ("%s • %s • %.1f credits/s • Owned %d"):format(
				definition.Rarity,
				definition.Family,
				definition.ProductionPerSecond,
				ownedCount
			)
			else ("%s • Undiscovered"):format(definition.Rarity)

		rows[("Index_%s"):format(robotId)] = React.createElement("Frame", {
			BackgroundColor3 = COLORS.PanelSoft,
			BorderSizePixel = 0,
			LayoutOrder = index,
			Size = UDim2.new(1, 0, 0, 58),
		}, {
			Corner = Components.Corner(8),
			Rarity = React.createElement("Frame", {
				BackgroundColor3 = rarityColors[definition.Rarity] or COLORS.Muted,
				BorderSizePixel = 0,
				Size = UDim2.fromOffset(5, 58),
			}),
			Name = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.GothamBold,
				Position = UDim2.fromOffset(14, 8),
				Size = UDim2.new(1, -24, 0, 20),
				Text = title,
				TextColor3 = if seen then COLORS.Text else COLORS.Muted,
				TextSize = 14,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
			Meta = React.createElement("TextLabel", {
				BackgroundTransparency = 1,
				Font = Enum.Font.Gotham,
				Position = UDim2.fromOffset(14, 31),
				Size = UDim2.new(1, -24, 0, 17),
				Text = meta,
				TextColor3 = COLORS.Muted,
				TextSize = 11,
				TextXAlignment = Enum.TextXAlignment.Left,
			}),
		})
	end
	return rows
end

function PanelContent.Title(panelName: string, snapshot: any): string
	if panelName == "Bots" then
		return ("Bot Control (%d)"):format(StateHelpers.CountOwnedRobots(snapshot))
	elseif panelName == "Upgrades" then
		return "Factory Upgrades"
	end
	return ("Robot Index (%d/%d)"):format(
		StateHelpers.CountDiscovered(snapshot),
		StateHelpers.CountRobotDefinitions()
	)
end

function PanelContent.Hint(panelName: string): string
	if panelName == "Bots" then
		return "Assign or unassign bots from unlocked work pads. Idle bots can be recycled."
	elseif panelName == "Upgrades" then
		return "Upgrade prices, ownership, and currency spending are validated by the server."
	end
	return "Discover robot outcomes by assembling them. Undiscovered names remain hidden."
end

function PanelContent.Content(panelName: string, snapshot: any, extraWorkSlots: number): any
	if panelName == "Bots" then
		return buildRobotRows(snapshot, extraWorkSlots)
	elseif panelName == "Upgrades" then
		return buildUpgradeRows(snapshot)
	end
	return buildIndexRows(snapshot)
end

return table.freeze(PanelContent)
