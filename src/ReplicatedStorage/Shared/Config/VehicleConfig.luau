--!strict
-- Tuning data for every drivable vehicle. Read-only at runtime.
local Types = require(script.Parent.Parent.Types)

local VehicleConfig = {}

VehicleConfig.DefaultVehicleId = "Coupe"

local vehicles: { [string]: Types.VehicleStats } = {
	Coupe = {
		DisplayName = "Coupe",
		BodyColor = Color3.fromRGB(196, 40, 28),
		ChassisSize = Vector3.new(7, 1.4, 13),
		WheelOffsets = {
			Vector3.new(-3.3, 0.7, -4.3),
			Vector3.new(3.3, 0.7, -4.3),
			Vector3.new(-3.3, 0.7, 4.4),
			Vector3.new(3.3, 0.7, 4.4),
		},
		WheelRadius = 1.3,
		WheelWidth = 1.1,
		SuspensionRestLength = 1.8,
		StaticCompressionRatio = 0.45,
		DampingRatio = 0.5,
		MaxForwardSpeed = 120,
		MaxReverseSpeed = 35,
		Acceleration = 55,
		ReverseAcceleration = 30,
		BrakeDeceleration = 120,
		HandbrakeDeceleration = 60,
		RollingDeceleration = 6,
		DragCoefficient = 0.03,
		MaxYawRate = 2.2,
		FullSteerSpeed = 20,
		HighSpeedSteerReduction = 0.5,
		HandbrakeYawMultiplier = 1.4,
		YawResponse = 10,
		LateralGrip = 12,
		HandbrakeLateralGrip = 2.5,
		MaxSteerAngle = math.rad(30),
	},
	-- Phase 4C purchasable car: faster and harder-accelerating than the Coupe, but heavier-feeling
	-- (slower steering, less grip, longer braking), so it slides more in corners.
	Muscle = {
		DisplayName = "Muscle",
		BodyColor = Color3.fromRGB(20, 105, 60),
		ChassisSize = Vector3.new(7.6, 1.5, 14.6),
		WheelOffsets = {
			Vector3.new(-3.6, 0.7, -4.8),
			Vector3.new(3.6, 0.7, -4.8),
			Vector3.new(-3.6, 0.7, 4.9),
			Vector3.new(3.6, 0.7, 4.9),
		},
		WheelRadius = 1.45,
		WheelWidth = 1.4,
		SuspensionRestLength = 1.8,
		StaticCompressionRatio = 0.5,
		DampingRatio = 0.55,
		MaxForwardSpeed = 138,
		MaxReverseSpeed = 32,
		Acceleration = 68,
		ReverseAcceleration = 28,
		BrakeDeceleration = 100,
		HandbrakeDeceleration = 55,
		RollingDeceleration = 5,
		DragCoefficient = 0.025,
		MaxYawRate = 1.85,
		FullSteerSpeed = 24,
		HighSpeedSteerReduction = 0.6,
		HandbrakeYawMultiplier = 1.6,
		YawResponse = 8,
		LateralGrip = 9,
		HandbrakeLateralGrip = 2,
		MaxSteerAngle = math.rad(28),
	},
	-- NPC police cruiser: Coupe handling with a little more pace so it can close gaps.
	Police = {
		DisplayName = "Police Cruiser",
		BodyColor = Color3.fromRGB(25, 35, 80),
		ChassisSize = Vector3.new(7, 1.4, 13),
		WheelOffsets = {
			Vector3.new(-3.3, 0.7, -4.3),
			Vector3.new(3.3, 0.7, -4.3),
			Vector3.new(-3.3, 0.7, 4.4),
			Vector3.new(3.3, 0.7, 4.4),
		},
		WheelRadius = 1.3,
		WheelWidth = 1.1,
		SuspensionRestLength = 1.8,
		StaticCompressionRatio = 0.45,
		DampingRatio = 0.5,
		MaxForwardSpeed = 125,
		MaxReverseSpeed = 35,
		Acceleration = 60,
		ReverseAcceleration = 30,
		BrakeDeceleration = 120,
		HandbrakeDeceleration = 60,
		RollingDeceleration = 6,
		DragCoefficient = 0.03,
		MaxYawRate = 2.2,
		FullSteerSpeed = 20,
		HighSpeedSteerReduction = 0.5,
		HandbrakeYawMultiplier = 1.4,
		YawResponse = 10,
		LateralGrip = 12,
		HandbrakeLateralGrip = 2.5,
		MaxSteerAngle = math.rad(30),
		PlayerSpawnable = false,
	},
}

for _, stats in vehicles do
	table.freeze(stats.WheelOffsets)
	table.freeze(stats)
end
table.freeze(vehicles)

function VehicleConfig.get(vehicleId: string): Types.VehicleStats?
	return vehicles[vehicleId]
end

function VehicleConfig.getIds(): { string }
	local ids = {}
	for id in vehicles do
		table.insert(ids, id)
	end
	table.sort(ids)
	return ids
end

return VehicleConfig
