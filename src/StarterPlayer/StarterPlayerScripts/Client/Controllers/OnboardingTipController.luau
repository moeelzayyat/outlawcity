--!strict
-- One-time first-spawn tip (audit 4, P3). A small card on the left, under the top HUD row, that
-- tells a new player what to do. It never blocks driving: only its X button takes input, it
-- stays clear of the touch controls (bottom right) and the speedometer (bottom centre), and it
-- closes itself after OnboardingConfig.TipSeconds. Shown once per session.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local OnboardingConfig = require(Shared.Config.OnboardingConfig)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)
local OnboardingRules = require(Shared.Onboarding.OnboardingRules)
local UiKit = require(script.Parent.UiKit)

local OnboardingTipController = {}

local player = Players.LocalPlayer

local TIP_TEXT = "Rob the 24/7 MART for cash, then escape the police. Buy faster cars at OUTLAW MOTORS. Follow the markers."

function OnboardingTipController.init()
	if not player.Character then
		player.CharacterAdded:Wait()
	end
	local gui = Instance.new("ScreenGui")
	gui.Name = "OnboardingTip"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 4
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets
	gui.Parent = player:WaitForChild("PlayerGui")

	local card = Instance.new("Frame")
	card.Name = "Tip"
	card.Active = false -- touches and clicks outside the X pass through to the game
	card.Position = UDim2.fromOffset(12, 92)
	card.Size = UDim2.fromOffset(250, 84)
	card.BackgroundColor3 = Color3.fromRGB(22, 24, 30)
	card.BackgroundTransparency = 0.2
	card.Parent = gui
	UiKit.corner(card, 12)
	local text = UiKit.text(card, "Text", TIP_TEXT, UDim2.new(1, -56, 1, -12), UDim2.fromOffset(10, 6), OnboardingConfig.MinTextSize)
	text.TextXAlignment = Enum.TextXAlignment.Left
	text.TextYAlignment = Enum.TextYAlignment.Center
	local close = UiKit.button(card, "Close", "X", UDim2.fromOffset(44, 44), UDim2.new(1, -48, 0, 4), Color3.fromRGB(70, 70, 80))
	close.Activated:Connect(function()
		gui:Destroy()
	end)
	task.delay(OnboardingConfig.TipSeconds, function()
		if gui.Parent then
			gui:Destroy()
		end
	end)
	-- A running robbery's objective panel takes over the top of the screen, so the tip steps aside.
	-- Other RobberyPhase changes (cleared, payout pending) leave it alone.
	local connection: RBXScriptConnection
	connection = player:GetAttributeChangedSignal(PlayerAttributes.RobberyPhase):Connect(function()
		if OnboardingRules.isActiveRobbery(player:GetAttribute(PlayerAttributes.RobberyPhase)) then
			connection:Disconnect()
			if gui.Parent then
				gui:Destroy()
			end
		end
	end)
	gui.Destroying:Connect(function()
		connection:Disconnect()
	end)
end

return OnboardingTipController
