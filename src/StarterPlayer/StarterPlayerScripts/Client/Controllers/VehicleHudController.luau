--!strict
-- Driving HUD built in code: spawn button, status toast, speedometer, control hints,
-- and on-screen gas / brake / handbrake / exit buttons on touch devices.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local VehicleConfig = require(Shared.Config.VehicleConfig)
local VehicleMath = require(Shared.Vehicle.VehicleMath)
local VehicleController = require(script.Parent.VehicleController)
local VehicleInputController = require(script.Parent.VehicleInputController)
local GarageController = require(script.Parent.GarageController)

local VehicleHudController = {}

local TOAST_SECONDS = 2.5
local ERROR_TEXT: { [string]: string } = {
	Cooldown = "Wait a moment before spawning again.",
	NoFreeSpawn = "All spawn pads are blocked. Try again shortly.",
	NotAlive = "You need to be alive to spawn a car.",
	UnknownVehicle = "That vehicle is not available.",
	BadRequest = "Spawn request was rejected.",
	NetworkError = "Could not reach the server.",
	Jailed = "You can't spawn a car while in jail.",
	NotOwned = "You don't own that car. Buy it at the dealership.",
}

local function corner(parent: Instance, radius: number)
	local c = Instance.new("UICorner")
	c.CornerRadius = UDim.new(0, radius)
	c.Parent = parent
end

local function label(parent: Instance, name: string, size: UDim2, position: UDim2, anchor: Vector2, textSize: number): TextLabel
	local l = Instance.new("TextLabel")
	l.Name = name
	l.Size = size
	l.Position = position
	l.AnchorPoint = anchor
	l.BackgroundColor3 = Color3.fromRGB(15, 15, 20)
	l.BackgroundTransparency = 0.35
	l.TextColor3 = Color3.new(1, 1, 1)
	l.Font = Enum.Font.GothamBold
	l.TextSize = textSize
	l.Parent = parent
	corner(l, 8)
	return l
end

local function button(parent: Instance, name: string, text: string, size: UDim2, position: UDim2, color: Color3): TextButton
	local b = Instance.new("TextButton")
	b.Name = name
	b.Text = text
	b.Size = size
	b.Position = position
	b.AnchorPoint = Vector2.new(1, 1)
	b.BackgroundColor3 = color
	b.BackgroundTransparency = 0.2
	b.TextColor3 = Color3.new(1, 1, 1)
	b.Font = Enum.Font.GothamBold
	b.TextSize = 18
	b.AutoButtonColor = true
	b.Parent = parent
	corner(b, 12)
	return b
end

-- Calls onChange(true) while held and onChange(false) on release, per touch or mouse press.
local function bindHold(target: GuiButton, onChange: (boolean) -> ())
	local active: InputObject? = nil
	target.InputBegan:Connect(function(input)
		if input.UserInputType == Enum.UserInputType.Touch or input.UserInputType == Enum.UserInputType.MouseButton1 then
			active = input
			onChange(true)
		end
	end)
	RunService.Heartbeat:Connect(function()
		local held = active
		if held and (held.UserInputState == Enum.UserInputState.End or held.UserInputState == Enum.UserInputState.Cancel) then
			active = nil
			onChange(false)
		end
	end)
end

function VehicleHudController.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local gui = Instance.new("ScreenGui")
	gui.Name = "OutlawHud"
	gui.ResetOnSpawn = false
	gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
	gui.Parent = playerGui

	local touch = UserInputService.TouchEnabled and not UserInputService.KeyboardEnabled

	local spawnButton = Instance.new("TextButton")
	spawnButton.Name = "SpawnButton"
	spawnButton.Text = if touch then "Spawn Car" else "Spawn Car [V]"
	spawnButton.Size = UDim2.fromOffset(160, 44)
	-- Top centre: the top-right corner can be covered by Roblox's player list.
	spawnButton.Position = UDim2.new(0.5, 84, 0, 8) -- right of the Combat button
	spawnButton.AnchorPoint = Vector2.new(0.5, 0)
	spawnButton.BackgroundColor3 = Color3.fromRGB(230, 160, 20)
	spawnButton.TextColor3 = Color3.new(1, 1, 1)
	spawnButton.Font = Enum.Font.GothamBold
	spawnButton.TextSize = 18
	spawnButton.Parent = gui
	corner(spawnButton, 10)
	spawnButton.Activated:Connect(function()
		GarageController.spawnOrChoose() -- one car: spawn it; 2+: choose in the garage
	end)

	local toast = label(gui, "Toast", UDim2.fromOffset(380, 36), UDim2.new(0.5, 0, 0, 140), Vector2.new(0.5, 0), 16)
	toast.Visible = false
	local toastToken = 0
	local function showToast(text: string)
		toastToken += 1
		local token = toastToken
		toast.Text = text
		toast.Visible = true
		task.delay(TOAST_SECONDS, function()
			if token == toastToken then
				toast.Visible = false
			end
		end)
	end

	local speedometer = label(gui, "Speedometer", UDim2.fromOffset(150, 48), UDim2.new(0.5, 0, 1, -16), Vector2.new(0.5, 1), 26)
	speedometer.Visible = false

	local hints = label(gui, "Hints", UDim2.fromOffset(520, 28), UDim2.new(0.5, 0, 1, -70), Vector2.new(0.5, 1), 14)
	hints.Text = "W/S drive  ·  A/D steer  ·  Space handbrake  ·  F exit"
	hints.BackgroundTransparency = 1
	hints.TextStrokeTransparency = 0.5
	hints.Visible = false

	local touchPanel = Instance.new("Frame")
	touchPanel.Name = "TouchControls"
	touchPanel.Size = UDim2.fromScale(1, 1)
	touchPanel.BackgroundTransparency = 1
	touchPanel.Visible = false
	touchPanel.Parent = gui
	local gas = button(touchPanel, "Gas", "GAS", UDim2.fromOffset(100, 100), UDim2.new(1, -20, 1, -20), Color3.fromRGB(40, 160, 70))
	local brake = button(touchPanel, "Brake", "BRAKE", UDim2.fromOffset(90, 90), UDim2.new(1, -132, 1, -20), Color3.fromRGB(190, 50, 40))
	local handbrake = button(touchPanel, "Handbrake", "DRIFT", UDim2.fromOffset(90, 50), UDim2.new(1, -132, 1, -122), Color3.fromRGB(70, 70, 90))
	local exit = button(touchPanel, "Exit", "EXIT", UDim2.fromOffset(100, 44), UDim2.new(1, -20, 1, -132), Color3.fromRGB(60, 60, 70))

	local gasHeld, brakeHeld = false, false
	local function updateThrottle()
		VehicleInputController.setTouchThrottle((if gasHeld then 1 else 0) - (if brakeHeld then 1 else 0))
	end
	bindHold(gas, function(held)
		gasHeld = held
		updateThrottle()
	end)
	bindHold(brake, function(held)
		brakeHeld = held
		updateThrottle()
	end)
	bindHold(handbrake, VehicleInputController.setTouchHandbrake)
	exit.Activated:Connect(VehicleController.requestExit)

	VehicleController.SpawnResult:Connect(function(ok: boolean, err: string?)
		if not ok then
			showToast(ERROR_TEXT[err or ""] or "Could not spawn a car.")
		end
	end)

	VehicleController.DrivingChanged:Connect(function(vehicle: Model?)
		local driving = vehicle ~= nil
		speedometer.Visible = driving
		hints.Visible = driving and not touch
		touchPanel.Visible = driving and UserInputService.TouchEnabled
		if not driving then
			gasHeld, brakeHeld = false, false
			updateThrottle()
			VehicleInputController.setTouchHandbrake(false)
		end
	end)

	RunService.RenderStepped:Connect(function()
		if speedometer.Visible then
			speedometer.Text = `{math.floor(VehicleMath.toMph(VehicleController.getCurrentSpeed()) + 0.5)} MPH`
		end
	end)
end

return VehicleHudController
