--!strict
-- Wanted-level HUD: stars (from server attributes), a blinking "evading" state, and
-- Evading / Escaped banners from OnWantedNotice. Display only; it never changes wanted state.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local WantedConfig = require(Shared.Config.WantedConfig)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)

local WantedHudController = {}

local STAR_SIZE = 34
local BANNER_SECONDS = 3
local BLINK_PERIOD = 0.5
local LIT = Color3.fromRGB(255, 205, 60)
local UNLIT = Color3.fromRGB(70, 70, 80)

local player = Players.LocalPlayer

function WantedHudController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "WantedHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local maxStars = #WantedConfig.StarThresholds
	local row = Instance.new("Frame")
	row.Name = "Stars"
	row.AnchorPoint = Vector2.new(0.5, 0)
	row.Position = UDim2.new(0.5, 0, 0, 58)
	row.Size = UDim2.fromOffset(maxStars * STAR_SIZE, STAR_SIZE)
	row.BackgroundTransparency = 1
	row.Visible = false
	row.Parent = gui
	local layout = Instance.new("UIListLayout")
	layout.FillDirection = Enum.FillDirection.Horizontal
	layout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	layout.Parent = row

	local stars: { TextLabel } = {}
	for index = 1, maxStars do
		local star = Instance.new("TextLabel")
		star.Name = `Star{index}`
		star.LayoutOrder = index
		star.Size = UDim2.fromOffset(STAR_SIZE, STAR_SIZE)
		star.BackgroundTransparency = 1
		star.Text = "★"
		star.Font = Enum.Font.GothamBold
		star.TextSize = STAR_SIZE - 4
		star.TextStrokeTransparency = 0.3
		star.Parent = row
		stars[index] = star
	end

	local banner = Instance.new("TextLabel")
	banner.Name = "Banner"
	banner.AnchorPoint = Vector2.new(0.5, 0)
	banner.Position = UDim2.new(0.5, 0, 0, 96)
	banner.Size = UDim2.fromOffset(320, 36)
	banner.BackgroundTransparency = 1
	banner.Font = Enum.Font.GothamBlack
	banner.TextSize = 26
	banner.TextStrokeTransparency = 0.2
	banner.Visible = false
	banner.Parent = gui

	local bannerToken = 0
	local function showBanner(text: string, color: Color3)
		bannerToken += 1
		local token = bannerToken
		banner.Text = text
		banner.TextColor3 = color
		banner.Visible = true
		task.delay(BANNER_SECONDS, function()
			if token == bannerToken then
				banner.Visible = false
			end
		end)
	end

	local function refresh()
		local level = player:GetAttribute(PlayerAttributes.WantedLevel)
		local count = if type(level) == "number" then level else 0
		row.Visible = count > 0
		for index, star in stars do
			star.TextColor3 = if index <= count then LIT else UNLIT
		end
	end
	player:GetAttributeChangedSignal(PlayerAttributes.WantedLevel):Connect(refresh)
	refresh()

	-- Lit stars blink while evading, like a fading search.
	RunService.RenderStepped:Connect(function()
		if not row.Visible then
			return
		end
		local evading = player:GetAttribute(PlayerAttributes.WantedEvading) == true
		local dim = evading and (os.clock() % (BLINK_PERIOD * 2)) >= BLINK_PERIOD
		for _, star in stars do
			star.TextTransparency = if dim then 0.6 else 0
		end
	end)

	Remotes.getEvent("OnWantedNotice").OnClientEvent:Connect(function(kind: string, payload: any)
		if kind == "Evading" then
			showBanner("EVADING...", Color3.fromRGB(255, 190, 60))
		elseif kind == "Busted" then
			showBanner("BUSTED!", Color3.fromRGB(255, 70, 70))
		elseif kind == "Escaped" then
			local reputation = if type(payload) == "table" and type(payload.Reputation) == "number" then payload.Reputation else 0
			showBanner(if reputation > 0 then `ESCAPED!  +{reputation} REP` else "ESCAPED!", Color3.fromRGB(90, 230, 120))
		end
	end)
end

return WantedHudController
