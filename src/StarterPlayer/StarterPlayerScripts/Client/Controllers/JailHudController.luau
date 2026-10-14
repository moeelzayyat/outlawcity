--!strict
-- Jail countdown: a centred panel while the server says the player is jailed. The time left is
-- computed from the server's JailReleaseAt and server clock, so it can't drift from the real
-- release; the client has no way to shorten or end a sentence.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local JailRules = require(Shared.Jail.JailRules)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)

local JailHudController = {}

local player = Players.LocalPlayer

function JailHudController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "JailHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 136) -- below the BUSTED! banner (y 96-132)
	panel.Size = UDim2.fromOffset(240, 92)
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Text = "IN JAIL"
	title.Size = UDim2.new(1, 0, 0, 34)
	title.Position = UDim2.fromOffset(0, 6)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 90, 90)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 24
	title.Parent = panel

	local countdown = Instance.new("TextLabel")
	countdown.Name = "Countdown"
	countdown.Size = UDim2.new(1, 0, 0, 40)
	countdown.Position = UDim2.fromOffset(0, 42)
	countdown.BackgroundTransparency = 1
	countdown.TextColor3 = Color3.new(1, 1, 1)
	countdown.Font = Enum.Font.GothamBold
	countdown.TextSize = 22
	countdown.Parent = panel

	RunService.RenderStepped:Connect(function()
		local jailed = player:GetAttribute(PlayerAttributes.Jailed) == true
		panel.Visible = jailed
		if jailed then
			local releaseAt = player:GetAttribute(PlayerAttributes.JailReleaseAt)
			local left = if type(releaseAt) == "number" then JailRules.secondsLeft(releaseAt, Workspace:GetServerTimeNow()) else 0
			countdown.Text = `Release in {left}s`
		end
	end)
end

return JailHudController
