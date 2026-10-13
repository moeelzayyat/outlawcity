--!strict
-- Turns keyboard, gamepad and touch input into one VehicleInput, and raises action signals.
-- Keyboard: W/S or Up/Down throttle, A/D or Left/Right steer, Space handbrake, F exit, V spawn.
-- Gamepad: left stick steer/throttle, RT/LT throttle/brake, X handbrake, B exit, DPadUp spawn.
-- Touch: left thumbstick (PlayerModule) plus on-screen buttons fed in by the HUD.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local UserInputService = game:GetService("UserInputService")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local VehicleMath = require(Shared.Vehicle.VehicleMath)
local Signal = require(Shared.Util.Signal)

local VehicleInputController = {}

VehicleInputController.ExitRequested = Signal.new()
VehicleInputController.SpawnRequested = Signal.new()

local FORWARD_KEYS = { Enum.KeyCode.W, Enum.KeyCode.Up }
local BACK_KEYS = { Enum.KeyCode.S, Enum.KeyCode.Down }
local RIGHT_KEYS = { Enum.KeyCode.D, Enum.KeyCode.Right }
local LEFT_KEYS = { Enum.KeyCode.A, Enum.KeyCode.Left }

local controls: any = nil
local touchThrottle = 0
local touchHandbrake = false
local triggerThrottle = 0
local triggerBrake = 0

local function anyKeyDown(keys: { Enum.KeyCode }): boolean
	for _, key in keys do
		if UserInputService:IsKeyDown(key) then
			return true
		end
	end
	return false
end

local function keyAxis(positive: { Enum.KeyCode }, negative: { Enum.KeyCode }): number
	return (if anyKeyDown(positive) then 1 else 0) - (if anyKeyDown(negative) then 1 else 0)
end

local function getMoveVector(): Vector3
	if controls then
		local ok, vector = pcall(controls.GetMoveVector, controls)
		if ok and typeof(vector) == "Vector3" then
			return vector
		end
	end
	return Vector3.zero
end

function VehicleInputController.init()
	task.spawn(function()
		local playerScripts = Players.LocalPlayer:WaitForChild("PlayerScripts")
		local playerModule = playerScripts:WaitForChild("PlayerModule", 10)
		if playerModule then
			local ok, result = pcall(function()
				return (require :: any)(playerModule):GetControls()
			end)
			if ok then
				controls = result
			end
		end
	end)

	UserInputService.InputChanged:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonR2 then
			triggerThrottle = input.Position.Z
		elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
			triggerBrake = input.Position.Z
		end
	end)
	UserInputService.InputEnded:Connect(function(input)
		if input.KeyCode == Enum.KeyCode.ButtonR2 then
			triggerThrottle = 0
		elseif input.KeyCode == Enum.KeyCode.ButtonL2 then
			triggerBrake = 0
		end
	end)
	UserInputService.InputBegan:Connect(function(input, gameProcessed)
		if gameProcessed then
			return
		end
		local key = input.KeyCode
		if key == Enum.KeyCode.F or key == Enum.KeyCode.ButtonB then
			VehicleInputController.ExitRequested:Fire()
		elseif key == Enum.KeyCode.V or key == Enum.KeyCode.DPadUp then
			VehicleInputController.SpawnRequested:Fire()
		end
	end)
end

function VehicleInputController.getInput(): Types.VehicleInput
	local typing = UserInputService:GetFocusedTextBox() ~= nil
	local stick = getMoveVector()
	local throttle = -stick.Z + touchThrottle + triggerThrottle - triggerBrake
	local steer = stick.X
	local handbrake = touchHandbrake
	if not typing then
		throttle += keyAxis(FORWARD_KEYS, BACK_KEYS)
		steer += keyAxis(RIGHT_KEYS, LEFT_KEYS)
		handbrake = handbrake
			or UserInputService:IsKeyDown(Enum.KeyCode.Space)
			or UserInputService:IsGamepadButtonDown(Enum.UserInputType.Gamepad1, Enum.KeyCode.ButtonX)
	end
	return VehicleMath.clampInput(throttle, steer, handbrake)
end

-- Fed by the touch HUD: +1 gas, -1 brake/reverse, 0 released.
function VehicleInputController.setTouchThrottle(value: number)
	touchThrottle = math.clamp(value, -1, 1)
end

function VehicleInputController.setTouchHandbrake(pressed: boolean)
	touchHandbrake = pressed
end

return VehicleInputController
