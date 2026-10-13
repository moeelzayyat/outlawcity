local ReplicatedStorage = game:GetService("ReplicatedStorage")
local VehicleMath = require(ReplicatedStorage.Shared.Vehicle.VehicleMath)
local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)
local Assert = require(script.Parent.Assert)

local stats = assert(VehicleConfig.get(VehicleConfig.DefaultVehicleId))
local DT = 1 / 60

local function input(throttle: number, steer: number, handbrake: boolean?)
	return VehicleMath.clampInput(throttle, steer, handbrake == true)
end

local function simulate(speed: number, inp, seconds: number): number
	for _ = 1, math.floor(seconds / DT) do
		speed = VehicleMath.stepForwardSpeed(speed, inp, stats, DT)
	end
	return speed
end

return {
	["moveToward never overshoots"] = function()
		Assert.equal(VehicleMath.moveToward(0, 1, 5), 1)
		Assert.equal(VehicleMath.moveToward(3, -1, 10), -1)
		Assert.equal(VehicleMath.moveToward(3, 0, 1), 2)
	end,
	["springs hold the car at static compression"] = function()
		local mass, gravity = 150, 196.2
		local k, c = VehicleMath.springConstants(mass, gravity, 4, stats.SuspensionRestLength, stats.StaticCompressionRatio, stats.DampingRatio)
		local staticCompression = stats.SuspensionRestLength * stats.StaticCompressionRatio
		local total = 4 * VehicleMath.suspensionForce(staticCompression, 0, k, c)
		Assert.near(total, mass * gravity, 1e-6, "total spring force")
		Assert.truthy(c > 0, "damping positive")
	end,
	["suspension never pulls down"] = function()
		Assert.equal(VehicleMath.suspensionForce(0.1, -100, 1000, 100), 0)
		Assert.equal(VehicleMath.suspensionForce(-1, 0, 1000, 100), 0)
	end,
	["clampInput clamps axes"] = function()
		local i = VehicleMath.clampInput(2, -3, true)
		Assert.equal(i.Throttle, 1)
		Assert.equal(i.Steer, -1)
		Assert.equal(i.Handbrake, true)
	end,
	["full throttle accelerates and respects top speed"] = function()
		local after1 = simulate(0, input(1, 0), 1)
		Assert.truthy(after1 > 40, `expected brisk launch, got {after1}`)
		local after30 = simulate(0, input(1, 0), 30)
		Assert.truthy(after30 <= stats.MaxForwardSpeed + 1e-6, "never exceeds max")
		Assert.truthy(after30 > stats.MaxForwardSpeed * 0.9, `should approach max, got {after30}`)
	end,
	["brake stops then reverses up to reverse cap"] = function()
		local stopped = simulate(60, input(-1, 0), 0.6)
		Assert.truthy(stopped <= 0.5, `expected stop within 0.6s, got {stopped}`)
		local reversing = simulate(0, input(-1, 0), 20)
		Assert.truthy(reversing < 0, "reverses")
		Assert.truthy(reversing >= -stats.MaxReverseSpeed - 1e-6, "reverse cap")
	end,
	["coasting slows to rest without reversing"] = function()
		local speed = simulate(80, input(0, 0), 30)
		Assert.equal(speed, 0)
	end,
	["handbrake brings the car to rest"] = function()
		Assert.equal(simulate(50, input(1, 0, true), 2), 0)
	end,
	["no yaw at standstill"] = function()
		Assert.equal(VehicleMath.targetYawRate(0, input(0, 1), stats), 0)
	end,
	["steering right turns clockwise and flips in reverse"] = function()
		local forward = VehicleMath.targetYawRate(40, input(1, 1), stats)
		local backward = VehicleMath.targetYawRate(-20, input(-1, 1), stats)
		Assert.truthy(forward < 0, "right steer forward is negative yaw")
		Assert.truthy(backward > 0, "right steer in reverse is positive yaw")
	end,
	["handbrake increases yaw rate"] = function()
		local normal = math.abs(VehicleMath.targetYawRate(60, input(1, 1), stats))
		local drift = math.abs(VehicleMath.targetYawRate(60, input(1, 1, true), stats))
		Assert.truthy(drift > normal, "handbrake yaw boost")
	end,
	["steering softens at top speed"] = function()
		local mid = math.abs(VehicleMath.targetYawRate(stats.FullSteerSpeed, input(1, 1), stats))
		local top = math.abs(VehicleMath.targetYawRate(stats.MaxForwardSpeed, input(1, 1), stats))
		Assert.truthy(top < mid, "less yaw at top speed")
	end,
}
