--!strict
-- Pure vehicle maths: no Instances, no side effects. Everything here is unit-tested
-- (ServerStorage.Tests.VehicleMath.spec) and shared by client physics and future server checks.
local Types = require(script.Parent.Parent.Types)

local VehicleMath = {}

function VehicleMath.moveToward(value: number, target: number, maxDelta: number): number
	if value < target then
		return math.min(value + maxDelta, target)
	end
	return math.max(value - maxDelta, target)
end

-- Fraction of the remaining gap closed this frame by an exponential approach at `rate` per second.
function VehicleMath.approachAlpha(rate: number, dt: number): number
	return 1 - math.exp(-rate * dt)
end

-- Spring stiffness and damping so the car rests at `staticCompressionRatio` of its travel.
function VehicleMath.springConstants(
	totalMass: number,
	gravity: number,
	wheelCount: number,
	restLength: number,
	staticCompressionRatio: number,
	dampingRatio: number
): (number, number)
	local massPerWheel = totalMass / wheelCount
	local stiffness = massPerWheel * gravity / (restLength * staticCompressionRatio)
	local damping = dampingRatio * 2 * math.sqrt(stiffness * massPerWheel)
	return stiffness, damping
end

-- Spring + damper force along the suspension axis. Never pulls the car toward the ground.
function VehicleMath.suspensionForce(
	compression: number,
	compressionVelocity: number,
	stiffness: number,
	damping: number
): number
	return math.max(0, compression * stiffness + compressionVelocity * damping)
end

function VehicleMath.clampInput(throttle: number, steer: number, handbrake: boolean): Types.VehicleInput
	return {
		Throttle = math.clamp(throttle, -1, 1),
		Steer = math.clamp(steer, -1, 1),
		Handbrake = handbrake,
	}
end

-- Next forward speed (studs/s along the chassis LookVector) for one grounded step.
function VehicleMath.stepForwardSpeed(
	speed: number,
	input: Types.VehicleInput,
	stats: Types.VehicleStats,
	dt: number
): number
	local throttle = input.Throttle
	if input.Handbrake then
		return VehicleMath.moveToward(speed, 0, stats.HandbrakeDeceleration * dt)
	end
	if throttle > 0 then
		if speed < -0.5 then
			return VehicleMath.moveToward(speed, 0, stats.BrakeDeceleration * throttle * dt)
		end
		local ratio = math.clamp(speed / stats.MaxForwardSpeed, 0, 1)
		local accel = stats.Acceleration * throttle * (1 - ratio * ratio)
		return math.min(speed + accel * dt, math.max(speed, stats.MaxForwardSpeed))
	elseif throttle < 0 then
		if speed > 0.5 then
			return VehicleMath.moveToward(speed, 0, stats.BrakeDeceleration * -throttle * dt)
		end
		local ratio = math.clamp(-speed / stats.MaxReverseSpeed, 0, 1)
		local accel = stats.ReverseAcceleration * -throttle * (1 - ratio * ratio)
		return math.max(speed - accel * dt, math.min(speed, -stats.MaxReverseSpeed))
	end
	local decel = stats.RollingDeceleration + math.abs(speed) * stats.DragCoefficient
	return VehicleMath.moveToward(speed, 0, decel * dt)
end

-- Desired yaw rate (rad/s about the chassis up axis). Positive yaw turns left in Roblox,
-- so steering right (positive Steer) gives a negative rate when driving forward.
function VehicleMath.targetYawRate(forwardSpeed: number, input: Types.VehicleInput, stats: Types.VehicleStats): number
	local speed = math.abs(forwardSpeed)
	local lowSpeedFactor = math.clamp(speed / stats.FullSteerSpeed, 0, 1)
	local highSpeedFactor = 1 - stats.HighSpeedSteerReduction * math.clamp(speed / stats.MaxForwardSpeed, 0, 1)
	local direction = if forwardSpeed >= 0 then 1 else -1
	local handbrakeFactor = if input.Handbrake then stats.HandbrakeYawMultiplier else 1
	return -input.Steer * stats.MaxYawRate * lowSpeedFactor * highSpeedFactor * direction * handbrakeFactor
end

-- Studs/s to miles per hour, assuming 1 stud = 0.28 m.
function VehicleMath.toMph(studsPerSecond: number): number
	return studsPerSecond * 0.28 * 2.23694
end

return VehicleMath
