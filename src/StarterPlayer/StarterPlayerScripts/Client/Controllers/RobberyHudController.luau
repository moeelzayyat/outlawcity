--!strict
-- Store robbery HUD (display only). The objective panel follows the server-written
-- RobberyPhase / RobberyHoldEndsAt / RobberyReward attributes; short messages come from the
-- server's OnRobberyNotice. Nothing here can start, finish or pay a robbery.
-- On short (phone) screens the panel is compact and sits just under the top HUD row (P7); while
-- escaping it explains how escaping works, matching WantedRules (P4).
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)
local OnboardingConfig = require(Shared.Config.OnboardingConfig)
local OnboardingRules = require(Shared.Onboarding.OnboardingRules)

local RobberyHudController = {}

local player = Players.LocalPlayer

local REJECT_TEXT: { [string]: string } = {
	Dead = "You can't rob while dead.",
	Jailed = "You can't rob while in jail.",
	InSafeZone = "No robberies inside a safe zone.",
	InVehicle = "Get out of your car to rob the store.",
	TooFar = "Get closer to the register.",
	StoreCooldown = "This store was robbed recently.",
	StoreBusy = "Someone is already robbing this store.",
	AlreadyRobbing = "You're already on a robbery.",
	CashUnavailable = "Your cash data isn't loaded right now. Try again in a moment.",
}
local FAIL_TEXT: { [string]: string } = {
	Died = "Robbery failed: you died. No cash.",
	Busted = "Robbery failed: busted by the police. No cash.",
	LeftArea = "Robbery failed: you left the store too early. No cash.",
	Disconnected = "Robbery failed: disconnected.",
	EscapeTimedOut = "Robbery failed: you didn't escape in time. No cash.",
}

local function money(amount: number): string
	local text = tostring(math.floor(amount))
	local formatted = text:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	return "$" .. formatted:gsub("^,", "")
end

function RobberyHudController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "RobberyHud"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 5
	gui.ScreenInsets = Enum.ScreenInsets.CoreUISafeInsets -- clear of notches and Roblox's top bar
	gui.Parent = player:WaitForChild("PlayerGui")

	-- Objective panel: same slot as the jail panel (y 136); the two can't be shown together.
	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0.5, 0)
	panel.Position = UDim2.new(0.5, 0, 0, 136)
	panel.Size = UDim2.fromOffset(300, 76)
	panel.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	panel.BackgroundTransparency = 0.15
	panel.Visible = false
	panel.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 12)
	corner.Parent = panel

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, -12, 0, 30)
	title.Position = UDim2.fromOffset(6, 6)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 200, 70)
	title.Font = Enum.Font.GothamBlack
	title.TextSize = 20
	title.TextScaled = false
	title.Parent = panel

	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.Size = UDim2.new(1, -12, 0, 32)
	detail.Position = UDim2.fromOffset(6, 38)
	detail.BackgroundTransparency = 1
	detail.TextColor3 = Color3.new(1, 1, 1)
	detail.Font = Enum.Font.GothamBold
	detail.TextSize = 16
	detail.TextWrapped = true
	detail.Parent = panel

	-- Full panel on PC/tablet; compact one under the top HUD row on short phone screens.
	local layoutHeight = -1
	local function applyLayout()
		local camera = Workspace.CurrentCamera
		local height = if camera then camera.ViewportSize.Y else 0
		if height == layoutHeight then
			return
		end
		layoutHeight = height
		local layout = OnboardingRules.robberyPanelLayout(height, OnboardingConfig)
		panel.Position = UDim2.new(0.5, 0, 0, layout.Y)
		panel.Size = UDim2.fromOffset(layout.Width, layout.Height)
		local titleHeight = layout.TitleSize + 6
		title.TextSize = layout.TitleSize
		title.Size = UDim2.new(1, -12, 0, titleHeight)
		title.Position = UDim2.fromOffset(6, 4)
		detail.TextSize = layout.DetailSize
		detail.Size = UDim2.new(1, -12, 0, layout.Height - titleHeight - 8)
		detail.Position = UDim2.fromOffset(6, 4 + titleHeight)
	end

	-- Toast for one-off messages (alarm, rejection reason, success, failure).
	local toast = Instance.new("TextLabel")
	toast.Name = "Toast"
	toast.AnchorPoint = Vector2.new(0.5, 0)
	toast.Position = UDim2.new(0.5, 0, 0, 220)
	toast.Size = UDim2.fromOffset(340, 40)
	toast.BackgroundColor3 = Color3.fromRGB(25, 25, 30)
	toast.BackgroundTransparency = 0.15
	toast.TextColor3 = Color3.new(1, 1, 1)
	toast.Font = Enum.Font.GothamBold
	toast.TextSize = 16
	toast.TextWrapped = true
	toast.Visible = false
	toast.Parent = gui
	local toastCorner = Instance.new("UICorner")
	toastCorner.CornerRadius = UDim.new(0, 10)
	toastCorner.Parent = toast

	local toastToken = 0
	local function showToast(text: string, color: Color3, seconds: number)
		toastToken += 1
		local token = toastToken
		toast.Text = text
		toast.TextColor3 = color
		toast.Visible = true
		task.delay(seconds, function()
			if toastToken == token then
				toast.Visible = false
			end
		end)
	end

	local WHITE = Color3.new(1, 1, 1)
	local RED = Color3.fromRGB(255, 110, 110)
	local GREEN = Color3.fromRGB(120, 255, 140)
	local AMBER = Color3.fromRGB(255, 200, 70)

	Remotes.getEvent("OnRobberyNotice").OnClientEvent:Connect(function(kind: string, payload: any)
		payload = if type(payload) == "table" then payload else {}
		if kind == "Rejected" then
			local text = REJECT_TEXT[payload.Reason] or "You can't rob this store right now."
			if payload.Reason == "StoreCooldown" and type(payload.CooldownLeft) == "number" then
				text = `This store was robbed recently. Try again in {payload.CooldownLeft}s.`
			end
			showToast(text, WHITE, 3)
		elseif kind == "Started" then
			showToast("Alarm tripped! Police have been alerted.", RED, 3.5)
		elseif kind == "Escape" then
			showToast("Got the cash! Now escape the police.", AMBER, 3.5)
		elseif kind == "Failed" then
			showToast(FAIL_TEXT[payload.Reason] or "Robbery failed. No cash.", RED, 4)
		elseif kind == "Paid" and type(payload.Amount) == "number" then
			showToast(`Escaped! +{money(payload.Amount)} from the robbery.`, GREEN, 4)
		elseif kind == "PayoutPending" then
			if payload.Recorded then
				showToast("Escaped! Your reward is safely recorded and will be added as soon as it can be saved (even if you rejoin).", AMBER, 5)
			else
				showToast("Escaped! Your cash data is reconnecting; the reward will be added. Stay in the game.", AMBER, 5)
			end
		elseif kind == "PayoutFailed" then
			showToast("Escaped, but the reward couldn't be paid.", RED, 4)
		end
	end)

	RunService.RenderStepped:Connect(function()
		local phase = player:GetAttribute(PlayerAttributes.RobberyPhase)
		local jailed = player:GetAttribute(PlayerAttributes.Jailed) == true
		panel.Visible = (phase == "Holding" or phase == "Escaping" or phase == "PayoutPending") and not jailed
		if panel.Visible then
			applyLayout()
		end
		if phase == "Holding" then
			local endsAt = player:GetAttribute(PlayerAttributes.RobberyHoldEndsAt)
			local left = if type(endsAt) == "number" then math.max(0, math.ceil(endsAt - Workspace:GetServerTimeNow())) else 0
			title.Text = `ROBBING THE STORE  {left}s`
			detail.Text = "Stay inside until the timer ends"
		elseif phase == "Escaping" then
			local reward = player:GetAttribute(PlayerAttributes.RobberyReward)
			title.Text = `ESCAPE TO KEEP {if type(reward) == "number" then money(reward) else "THE CASH"}`
			local stars = player:GetAttribute(PlayerAttributes.WantedLevel)
			detail.Text = OnboardingRules.escapeHint(player:GetAttribute(PlayerAttributes.WantedEvading) == true, if type(stars) == "number" then stars else 0)
		elseif phase == "PayoutPending" then
			local reward = player:GetAttribute(PlayerAttributes.RobberyReward)
			title.Text = "REWARD PENDING"
			detail.Text = `{if type(reward) == "number" then money(reward) else "Your reward"} will be added when your cash data reconnects`
		end
	end)
end

return RobberyHudController
