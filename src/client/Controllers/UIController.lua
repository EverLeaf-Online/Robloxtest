--!strict

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local React = require(ReplicatedStorage.Packages.React)
local ReactRoblox = require(ReplicatedStorage.Packages.ReactRoblox)

local App = require(script.Parent.Parent.UI.App)

local UIController = {}
local root: any? = nil
local screenGui: ScreenGui? = nil

function UIController.Init()
	if root ~= nil then
		return
	end

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui") :: PlayerGui

	local existing = playerGui:FindFirstChild("ScrapToBotUI")
	if existing then
		existing:Destroy()
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "ScrapToBotUI"
	gui.ResetOnSpawn = false
	gui.IgnoreGuiInset = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local reactRoot = ReactRoblox.createRoot(gui)
	reactRoot:render(React.createElement(App))

	screenGui = gui
	root = reactRoot
end

function UIController.Destroy()
	if root ~= nil then
		root:unmount()
		root = nil
	end

	if screenGui ~= nil then
		screenGui:Destroy()
		screenGui = nil
	end
end

return table.freeze(UIController)
