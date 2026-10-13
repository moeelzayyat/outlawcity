--!strict
-- Chase camera while driving: trails behind the car, widens with speed, avoids clipping walls.
-- Hands control back to the default Roblox camera when the player leaves the vehicle.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local VehicleMath = require(ReplicatedStorage.Shared.Vehicle.VehicleMath)
local VehicleController = require(script.Parent.VehicleController)

local VehicleCameraController = {}

local BIND_NAME = "OutlawVehicleCamera"
local BASE_DISTANCE = 20
local EXTRA_DISTANCE_AT_SPEED = 8
local HEIGHT = 6
local FOCUS_HEIGHT = 2.5
local LOOK_AHEAD = 6
local BASE_FOV = 70
local FOV_BOOST = 12
local SPEED_FOR_FULL_EFFECT = 120
local DIRECTION_RATE = 4
local POSITION_RATE = 12
local REVERSE_LOOK_SPEED = -8

local function flatten(vector: Vector3, fallback: Vector3): Vector3
	local flat = Vector3.new(vector.X, 0, vector.Z)
	if flat.Magnitude < 1e-3 then
		return fallback
	end
	return flat.Unit
end

local function start(vehicle: Model)
	local chassis = vehicle.PrimaryPart
	local camera = Workspace.CurrentCamera
	if not chassis or not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Scriptable
	local direction = flatten(chassis.CFrame.LookVector, Vector3.new(0, 0, -1))
	local position = camera.CFrame.Position
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude

	RunService:BindToRenderStep(BIND_NAME, Enum.RenderPriority.Camera.Value + 1, function(dt: number)
		if not chassis.Parent then
			return
		end
		-- The default camera scripts can reset CameraType (e.g. on respawn or seat events).
		if camera.CameraType ~= Enum.CameraType.Scriptable then
			camera.CameraType = Enum.CameraType.Scriptable
		end
		local cframe = chassis.CFrame
		local velocity = chassis.AssemblyLinearVelocity
		local speed = Vector3.new(velocity.X, 0, velocity.Z).Magnitude
		local speedRatio = math.clamp(speed / SPEED_FOR_FULL_EFFECT, 0, 1)

		-- Follow the direction of travel when reversing quickly, else the car's nose.
		local forwardSpeed = velocity:Dot(cframe.LookVector)
		local desiredDirection = flatten(cframe.LookVector, direction)
		if forwardSpeed < REVERSE_LOOK_SPEED then
			desiredDirection = flatten(-cframe.LookVector, direction)
		end
		direction = flatten(direction:Lerp(desiredDirection, VehicleMath.approachAlpha(DIRECTION_RATE, dt)), direction)

		local focus = cframe.Position + Vector3.new(0, FOCUS_HEIGHT, 0)
		local distance = BASE_DISTANCE + EXTRA_DISTANCE_AT_SPEED * speedRatio
		local desired = focus - direction * distance + Vector3.new(0, HEIGHT, 0)

		local ignore: { Instance } = { vehicle }
		local character = Players.LocalPlayer.Character
		if character then
			table.insert(ignore, character)
		end
		rayParams.FilterDescendantsInstances = ignore
		local hit = Workspace:Raycast(focus, desired - focus, rayParams)
		if hit then
			desired = hit.Position + hit.Normal * 0.5
		end

		position = position:Lerp(desired, VehicleMath.approachAlpha(POSITION_RATE, dt))
		camera.CFrame = CFrame.lookAt(position, focus + direction * LOOK_AHEAD)
		camera.FieldOfView = BASE_FOV + FOV_BOOST * speedRatio
	end)
end

local function stop()
	RunService:UnbindFromRenderStep(BIND_NAME)
	local camera = Workspace.CurrentCamera
	if not camera then
		return
	end
	camera.CameraType = Enum.CameraType.Custom
	camera.FieldOfView = BASE_FOV
	local character = Players.LocalPlayer.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid then
		camera.CameraSubject = humanoid
	end
end

function VehicleCameraController.init()
	VehicleController.DrivingChanged:Connect(function(vehicle: Model?)
		stop()
		if vehicle then
			start(vehicle)
		end
	end)
end

return VehicleCameraController
