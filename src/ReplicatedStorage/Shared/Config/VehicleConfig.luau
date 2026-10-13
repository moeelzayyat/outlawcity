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
