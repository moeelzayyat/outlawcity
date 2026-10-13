--!strict
-- Raycast suspension vehicle, simulated by the client that owns the chassis.
-- Springs push the chassis up with impulses; drive, grip and yaw are applied as velocity
-- changes so handling stays arcade-responsive and independent of part friction.
local Workspace = game:GetService("Workspace")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local VehicleMath = require(Shared.Vehicle.VehicleMath)

local VehiclePhysics = {}
VehiclePhysics.__index = VehiclePhysics

local FLIP_UP_THRESHOLD = 0.2
local FLIP_MAX_SPEED = 8
local FLIP_RESET_SECONDS = 2
local AIR_ANGULAR_DAMPING = 1.5
local TWO_PI = math.pi * 2

type VehiclePhysicsData = {
	model: Model,
	chassis: BasePart,
	stats: Types.VehicleStats,
	motors: { Motor6D },
	springLengths: { number },
	staticLength: number,
	wheelSpin: number,
	flippedTime: number,
	rayParams: RaycastParams,
	groundedWheels: number,
}
export type VehiclePhysics = typeof(setmetatable({} :: VehiclePhysicsData, VehiclePhysics))

function VehiclePhysics.new(model: Model, stats: Types.VehicleStats, ignore: { Instance }): VehiclePhysics?
	local chassis = model.PrimaryPart
	if not chassis then
		return nil
	end
	local motors = {}
	for index in stats.WheelOffsets do
		local motor = chassis:FindFirstChild(`WheelMotor{index}`)
		if motor and motor:IsA("Motor6D") then
			motors[index] = motor
		end
	end
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = ignore
	rayParams.IgnoreWater = true

	local staticLength = stats.SuspensionRestLength * (1 - stats.StaticCompressionRatio)
	local springLengths = table.create(#stats.WheelOffsets, staticLength)
	return setmetatable({
		model = model,
		chassis = chassis,
		stats = stats,
		motors = motors,
		springLengths = springLengths,
		staticLength = staticLength,
		wheelSpin = 0,
		flippedTime = 0,
		rayParams = rayParams,
		groundedWheels = 0,
	}, VehiclePhysics)
end

function VehiclePhysics.setIgnoreList(self: VehiclePhysics, ignore: { Instance })
	self.rayParams.FilterDescendantsInstances = ignore
end

function VehiclePhysics.isGrounded(self: VehiclePhysics): boolean
	return self.groundedWheels > 0
end

function VehiclePhysics._applySuspension(self: VehiclePhysics, dt: number)
	local stats = self.stats
	local chassis = self.chassis
	local cframe = chassis.CFrame
	local up = cframe.UpVector
	local wheelCount = #stats.WheelOffsets
	local stiffness, damping = VehicleMath.springConstants(
		chassis.AssemblyMass,
		Workspace.Gravity,
		wheelCount,
		stats.SuspensionRestLength,
		stats.StaticCompressionRatio,
		stats.DampingRatio
	)
	local rayLength = stats.SuspensionRestLength + stats.WheelRadius
	local grounded = 0
	for index, offset in stats.WheelOffsets do
		local origin = cframe:PointToWorldSpace(offset)
		local hit = Workspace:Raycast(origin, -up * rayLength, self.rayParams)
		local springLength = stats.SuspensionRestLength
		if hit then
			grounded += 1
			springLength = math.max(0, hit.Distance - stats.WheelRadius)
			local compression = stats.SuspensionRestLength - springLength
			local compressionVelocity = -chassis:GetVelocityAtPosition(origin):Dot(up)
			local force = VehicleMath.suspensionForce(compression, compressionVelocity, stiffness, damping)
			-- Push at the wheel's X/Z but at chassis-centre height to limit body roll.
			local applyAt = cframe:PointToWorldSpace(Vector3.new(offset.X, 0, offset.Z))
			chassis:ApplyImpulseAtPosition(up * force * dt, applyAt)
		end
		self.springLengths[index] = springLength
	end
	self.groundedWheels = grounded
end

function VehiclePhysics._applyDrive(self: VehiclePhysics, dt: number, input: Types.VehicleInput): number
	local stats = self.stats
	local chassis = self.chassis
	local cframe = chassis.CFrame
	local forward, right, up = cframe.LookVector, cframe.RightVector, cframe.UpVector
	local velocity = chassis.AssemblyLinearVelocity
	local forwardSpeed = velocity:Dot(forward)
	if self.groundedWheels == 0 then
		-- Airborne: keep yaw, gently damp tumbling so jumps land flat.
		local angular = chassis.AssemblyAngularVelocity
		local yawPart = up * angular:Dot(up)
		chassis.AssemblyAngularVelocity = yawPart + (angular - yawPart) * (1 - VehicleMath.approachAlpha(AIR_ANGULAR_DAMPING, dt))
		return forwardSpeed
	end

	local groundedFraction = self.groundedWheels / #stats.WheelOffsets
	local lateralSpeed = velocity:Dot(right)
	local nextForward = VehicleMath.stepForwardSpeed(forwardSpeed, input, stats, dt)
	nextForward = forwardSpeed + (nextForward - forwardSpeed) * groundedFraction
	local grip = if input.Handbrake then stats.HandbrakeLateralGrip else stats.LateralGrip
	local nextLateral = lateralSpeed * (1 - VehicleMath.approachAlpha(grip, dt) * groundedFraction)
	chassis.AssemblyLinearVelocity = velocity + forward * (nextForward - forwardSpeed) + right * (nextLateral - lateralSpeed)

	local angular = chassis.AssemblyAngularVelocity
	local currentYaw = angular:Dot(up)
	local targetYaw = VehicleMath.targetYawRate(forwardSpeed, input, stats)
	local nextYaw = currentYaw + (targetYaw - currentYaw) * VehicleMath.approachAlpha(stats.YawResponse, dt) * groundedFraction
	chassis.AssemblyAngularVelocity = angular + up * (nextYaw - currentYaw)
	return nextForward
end

function VehiclePhysics._recoverIfFlipped(self: VehiclePhysics, dt: number)
	local chassis = self.chassis
	local upY = chassis.CFrame.UpVector.Y
	if upY < FLIP_UP_THRESHOLD and chassis.AssemblyLinearVelocity.Magnitude < FLIP_MAX_SPEED then
		self.flippedTime += dt
	else
		self.flippedTime = 0
	end
	if self.flippedTime < FLIP_RESET_SECONDS then
		return
	end
	self.flippedTime = 0
	local look = chassis.CFrame.LookVector
	local flat = Vector3.new(look.X, 0, look.Z)
	if flat.Magnitude < 0.1 then
		flat = Vector3.new(0, 0, -1)
	end
	local position = chassis.Position + Vector3.new(0, 4, 0)
	self.model:PivotTo(CFrame.lookAt(position, position + flat.Unit))
	chassis.AssemblyLinearVelocity = Vector3.zero
	chassis.AssemblyAngularVelocity = Vector3.zero
end

function VehiclePhysics._animateWheels(self: VehiclePhysics, dt: number, input: Types.VehicleInput, forwardSpeed: number)
	local stats = self.stats
	self.wheelSpin = (self.wheelSpin + forwardSpeed * dt / stats.WheelRadius) % TWO_PI
	local steerAngle = -input.Steer * stats.MaxSteerAngle
	for index, motor in self.motors do
		local drop = self.staticLength - self.springLengths[index]
		local steer = if index <= 2 then steerAngle else 0
		motor.Transform = CFrame.new(0, drop, 0) * CFrame.Angles(0, steer, 0) * CFrame.Angles(-self.wheelSpin, 0, 0)
	end
end

function VehiclePhysics.step(self: VehiclePhysics, dt: number, input: Types.VehicleInput)
	if not self.chassis.Parent then
		return
	end
	self:_applySuspension(dt)
	local forwardSpeed = self:_applyDrive(dt, input)
	self:_recoverIfFlipped(dt)
	self:_animateWheels(dt, input, forwardSpeed)
end

function VehiclePhysics.destroy(self: VehiclePhysics)
	for _, motor in self.motors do
		if motor.Parent then
			motor.Transform = CFrame.identity
		end
	end
end

return VehiclePhysics
