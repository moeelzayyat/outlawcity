--!strict
-- Studio-only dev panel for solo testing of wanted rules. Does nothing outside Studio, and
-- does nothing if the server did not create ReplicatedStorage.DevRemotes. Toggle with F8.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local PlayerAttributes = require(ReplicatedStorage.Shared.Player.PlayerAttributes)

local DevPanelController = {}

local player = Players.LocalPlayer

type Action = { Label: string, Name: string, Value: any }

local ACTIONS: { Action } = {
	{ Label = "Crime: Ramming", Name = "ReportCrime", Value = "RammingPolice" },
	{ Label = "Crime: Speeding", Name = "ReportCrime", Value = "SpeedingNearPolice" },
	{ Label = "Set 1 star", Name = "SetStars", Value = 1 },
	{ Label = "Set 2 stars", Name = "SetStars", Value = 2 },
	{ Label = "Set 3 stars", Name = "SetStars", Value = 3 },
	{ Label = "Clear wanted", Name = "ResetWanted", Value = nil },
	{ Label = "Police sees me: ON", Name = "SetPoliceSight", Value = true },
	{ Label = "Police sees me: OFF", Name = "SetPoliceSight", Value = false },
	{ Label = "Simulate bust", Name = "SimulateBust", Value = nil },
	{ Label = "Cash +100", Name = "GrantCash", Value = 100 },
	{ Label = "Cash -100", Name = "DeductCash", Value = 100 },
	{ Label = "Cash +100 (tx dup-test)", Name = "GrantCashTx", Value = "dup-test" },
	{ Label = "Save data now", Name = "SaveNow", Value = nil },
	{ Label = "Store: clear cooldown", Name = "ClearRobberyCooldown", Value = nil },
}

function DevPanelController.init()
	if not RunService:IsStudio() then
		return
	end
	local folder = ReplicatedStorage:WaitForChild("DevRemotes", 10)
	local remote = folder and folder:FindFirstChild("RequestDevCommand")
	if not remote or not remote:IsA("RemoteFunction") then
		return
	end

	local gui = Instance.new("ScreenGui")
	gui.Name = "DevPanel"
	gui.ResetOnSpawn = false
	gui.DisplayOrder = 20
	gui.Parent = player:WaitForChild("PlayerGui")

	local panel = Instance.new("Frame")
	panel.Name = "Panel"
	panel.AnchorPoint = Vector2.new(0, 0.5)
	panel.Position = UDim2.new(0, 8, 0.5, 0)
	panel.Size = UDim2.fromOffset(170, 40 + #ACTIONS * 34)
	panel.BackgroundColor3 = Color3.fromRGB(40, 10, 10)
	panel.BackgroundTransparency = 0.2
	panel.Parent = gui

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.Size = UDim2.new(1, 0, 0, 34)
	title.BackgroundTransparency = 1
	title.TextColor3 = Color3.fromRGB(255, 120, 120)
	title.Font = Enum.Font.GothamBold
	title.TextSize = 13
	title.Parent = panel

	local function updateTitle(note: string?)
		local heat = player:GetAttribute(PlayerAttributes.WantedHeat)
		title.Text = `DEV (Studio) heat {tostring(heat or 0)}{if note then "\n" .. note else ""}`
	end
	player:GetAttributeChangedSignal(PlayerAttributes.WantedHeat):Connect(function()
		updateTitle(nil)
	end)
	updateTitle(nil)

	for index, action in ACTIONS do
		local button = Instance.new("TextButton")
		button.Name = action.Label
		button.Text = action.Label
		button.Size = UDim2.new(1, -12, 0, 30)
		button.Position = UDim2.fromOffset(6, 36 + (index - 1) * 34)
		button.BackgroundColor3 = Color3.fromRGB(90, 30, 30)
		button.TextColor3 = Color3.new(1, 1, 1)
		button.Font = Enum.Font.Gotham
		button.TextSize = 13
		button.Parent = panel
		button.Activated:Connect(function()
			task.spawn(function()
				local ok, result, err = pcall(function()
					return (remote :: RemoteFunction):InvokeServer(action.Name, action.Value)
				end)
				updateTitle(if ok and result then nil else `failed: {tostring(err or result)}`)
			end)
		end)
	end

	UserInputService.InputBegan:Connect(function(input, processed)
		if not processed and input.KeyCode == Enum.KeyCode.F8 then
			panel.Visible = not panel.Visible
		end
	end)
end

return DevPanelController
