--!strict
-- Cash display: shows the server's balance (Cash attribute) at the top, right of the stars.
-- Display only; the client has no way to change cash.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local PlayerAttributes = require(ReplicatedStorage.Shared.Player.PlayerAttributes)

local CashHudController = {}

local player = Players.LocalPlayer

local function format(amount: number): string
	local s = tostring(math.floor(amount))
	local formatted = s:reverse():gsub("(%d%d%d)", "%1,"):reverse()
	if formatted:sub(1, 1) == "," then
		formatted = formatted:sub(2)
	end
	return "$" .. formatted
end

function CashHudController.init()
	local gui = Instance.new("ScreenGui")
	gui.Name = "CashHud"
	gui.ResetOnSpawn = false
	gui.Parent = player:WaitForChild("PlayerGui")

	local label = Instance.new("TextLabel")
	label.Name = "Cash"
	label.AnchorPoint = Vector2.new(1, 0)
	-- Right of the centred wanted stars, under the Spawn Car button.
	label.Position = UDim2.new(0.5, 164, 0, 58)
	label.Size = UDim2.fromOffset(108, 26)
	label.BackgroundColor3 = Color3.fromRGB(20, 60, 30)
	label.BackgroundTransparency = 0.2
	label.TextColor3 = Color3.fromRGB(140, 255, 160)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 15
	label.Parent = gui
	local corner = Instance.new("UICorner")
	corner.CornerRadius = UDim.new(0, 8)
	corner.Parent = label

	local function refresh()
		local status = player:GetAttribute(PlayerAttributes.CashStatus)
		local cash = player:GetAttribute(PlayerAttributes.Cash)
		if status == "Loaded" and type(cash) == "number" then
			label.Text = format(cash)
			label.TextColor3 = Color3.fromRGB(140, 255, 160)
		elseif status == "Unavailable" then
			label.Text = "$ offline"
			label.TextColor3 = Color3.fromRGB(255, 190, 90)
		else
			label.Text = "$ ..."
			label.TextColor3 = Color3.fromRGB(200, 200, 200)
		end
	end
	player:GetAttributeChangedSignal(PlayerAttributes.Cash):Connect(refresh)
	player:GetAttributeChangedSignal(PlayerAttributes.CashStatus):Connect(refresh)
	refresh()
end

return CashHudController
