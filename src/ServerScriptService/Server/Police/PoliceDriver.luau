--!strict
-- Movement for one server-simulated NPC vehicle. Follows a list of waypoints (or drives
-- straight at a target when told to), slows for corners, steers around obstacles with three
-- forward "whisker" raycasts, and backs off when stuck. Physics comes from the shared
-- VehiclePhysics used by player cars; this module only produces its inputs.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local VehicleMath = require(Shared.Vehicle.VehicleMath)
local VehiclePhysics = require(Shared.Vehicle.VehiclePhysics)
local PoliceConfig = require(script.Parent.PoliceConfig)
local PoliceDriveRules = require(script.Parent.PoliceDriveRules)

local PoliceDriver = {}
PoliceDriver.__index = PoliceDriver

type DriverData = {
	model: Model,
	chassis: BasePart,
	physics: VehiclePhysics.VehiclePhysics,
	waypoints: { Vector3 },
	waypointIndex: number,
	cruiseSpeed: number,
	stuck: PoliceDriveRules.StuckState,
	lastSteer: number,
	whiskerParams: RaycastParams,
	softRecoveries: number,
	hardRecoveries: number,
	whiskerHits: number,
	lastAction: string,
	chaseTargetSpeed: number?,
}
export type PoliceDriver = typeof(setmetatable({} :: DriverData, PoliceDriver))

function PoliceDriver.new(model: Model, stats: Types.VehicleStats, ignore: { Instance }): PoliceDriver?
	local chassis = model.PrimaryPart
	local physics = VehiclePhysics.new(model, stats, ignore)
	if not chassis or not physics then
		return nil
	end
	local whiskerParams = RaycastParams.new()
	whiskerParams.FilterType = Enum.RaycastFilterType.Exclude
	whiskerParams.FilterDescendantsInstances = ignore
	return setmetatable({
		model = model,
		chassis = chassis,
		physics = physics,
		waypoints = {},
		waypointIndex = 1,
		cruiseSpeed = PoliceConfig.CruiseSpeed,
		stuck = PoliceDriveRules.newStuckState(),
		lastSteer = 0,
		whiskerParams = whiskerParams,
		softRecoveries = 0,
		hardRecoveries = 0,
		whiskerHits = 0,
		lastAction = "Drive",
		chaseTargetSpeed = nil,
	}, PoliceDriver)
end

function PoliceDriver.setIgnoreList(self: PoliceDriver, ignore: { Instance })
	self.physics:setIgnoreList(ignore)
	self.whiskerParams.FilterDescendantsInstances = ignore
end

-- Replaces the route. `chase` raises the cruise speed (target close and in sight).
function PoliceDriver.setRoute(self: PoliceDriver, waypoints: { Vector3 }, chase: boolean)
	self.waypoints = waypoints
	self.waypointIndex = 1
	self.cruiseSpeed = if chase then PoliceConfig.ChaseSpeed else PoliceConfig.CruiseSpeed
	self.chaseTargetSpeed = nil
end

-- Direct chase: aim at where the target will be shortly and match its speed while closing in.
function PoliceDriver.setChaseTarget(self: PoliceDriver, position: Vector3, velocity: Vector3)
	local flatVelocity = Vector3.new(velocity.X, 0, velocity.Z)
	self.waypoints = { position + flatVelocity * PoliceConfig.ChaseLookAhead }
	self.waypointIndex = 1
	self.cruiseSpeed = PoliceConfig.ChaseSpeed
	self.chaseTargetSpeed = flatVelocity.Magnitude
end

function PoliceDriver.currentWaypoint(self: PoliceDriver): Vector3?
	return self.waypoints[self.waypointIndex]
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

-- Three forward rays; returns (steer bias, nearest centre-hit distance or nil).
function PoliceDriver._whiskers(self: PoliceDriver, speed: number): (number, number?)
	local cframe = self.chassis.CFrame
	local origin = cframe.Position + cframe.UpVector * 0.5 + cframe.LookVector * (self.chassis.Size.Z / 2)
	local length = math.max(PoliceConfig.WhiskerMinLength, speed * PoliceConfig.WhiskerSpeedFactor)
	local bias = 0
	local centreDistance: number? = nil
	for _, angle in { -PoliceConfig.WhiskerAngle, 0, PoliceConfig.WhiskerAngle } do
		local direction = (cframe * CFrame.Angles(0, -angle, 0)).LookVector * length
		local hit = Workspace:Raycast(origin, direction, self.whiskerParams)
		if hit and hit.Normal.Y < 0.7 then -- walls only, not the road surface
			local closeness = 1 - hit.Distance / length
			if angle == 0 then
				centreDistance = hit.Distance
			else
				-- Positive angle = ray to the right: steer left (negative), and vice versa.
				bias -= math.sign(angle) * closeness * 0.8
			end
		end
	end
	if centreDistance or bias ~= 0 then
		self.whiskerHits += 1
	end
	return bias, centreDistance
end

-- Advances one physics frame. Returns "HardRecover" when the caller should reposition the unit.
function PoliceDriver.step(self: PoliceDriver, dt: number, now: number): string?
	local chassis = self.chassis
	if not chassis.Parent then
		return nil
	end
	local position = chassis.Position
	local velocity = chassis.AssemblyLinearVelocity
	local forwardSpeed = velocity:Dot(chassis.CFrame.LookVector)

	-- Advance past reached waypoints (never past the final target point).
	local target = self.waypoints[self.waypointIndex]
	while target and self.waypointIndex < #self.waypoints and (flat(target) - flat(position)).Magnitude < PoliceConfig.WaypointRadius do
		self.waypointIndex += 1
		target = self.waypoints[self.waypointIndex]
	end

	local input: Types.VehicleInput
	if not target then
		input = VehicleMath.clampInput(0, 0, true)
	else
		local localTarget = chassis.CFrame:PointToObjectSpace(Vector3.new(target.X, position.Y, target.Z))
		local steer, headingError = PoliceDriveRules.steerToward(localTarget, PoliceConfig.MaxSteerAngle)
		local nextPoint = self.waypoints[self.waypointIndex + 1]
		local corner = if nextPoint then PoliceDriveRules.cornerAngle(position, target, nextPoint) else 0
		local distance = (flat(target) - flat(position)).Magnitude
		local desired = PoliceDriveRules.targetSpeed(distance, corner, headingError, self.cruiseSpeed, PoliceConfig)
		if not nextPoint then
			-- Final point (the target itself): arrive rather than overshoot, and stop short of
			-- it inside bust range instead of ramming it (which would also look like "stuck").
			if self.chaseTargetSpeed then
				desired = math.min(desired, PoliceDriveRules.chaseSpeed(self.chaseTargetSpeed, distance, PoliceConfig.ChaseFollowDistance, PoliceConfig.ChaseGain, self.cruiseSpeed))
			end
			if distance < PoliceConfig.BustRange * 0.6 and (self.chaseTargetSpeed or 0) < PoliceConfig.BustMaxTargetSpeed then
				desired = 0
			elseif not self.chaseTargetSpeed then
				desired = math.min(desired, distance * 1.2)
			end
		end
		-- The route wants progress whenever the desired speed (before obstacle braking) is
		-- meaningful; stuck detection uses this, so braking for a wall can't hide a stall.
		local wantsProgress = desired > PoliceConfig.StuckSpeed * 2
		local bias, wallDistance = self:_whiskers(math.abs(forwardSpeed))
		steer = math.clamp(steer + bias, -1, 1)
		if wallDistance then
			desired = math.min(desired, wallDistance * 1.0)
		end
		local throttle = PoliceDriveRules.throttleFor(desired, forwardSpeed, PoliceConfig.ThrottleGain)

		local action = PoliceDriveRules.updateStuck(self.stuck, dt, now, math.abs(forwardSpeed), wantsProgress, PoliceConfig)
		local previousAction = self.lastAction
		self.lastAction = action
		if action == "HardRecover" then
			self.hardRecoveries += 1
			return "HardRecover"
		elseif action == "Reverse" then
			if previousAction ~= "Reverse" then
				self.softRecoveries += 1
			end
			input = VehicleMath.clampInput(-1, -self.lastSteer, false)
		else
			self.lastSteer = if math.abs(steer) > 0.2 then steer else self.lastSteer
			input = VehicleMath.clampInput(throttle, steer, false)
		end
	end
	self.physics:step(dt, input)
	return nil
end

-- Teleports the unit upright onto `position`, facing `lookAt`, at rest.
function PoliceDriver.reposition(self: PoliceDriver, position: Vector3, lookAt: Vector3, rideHeight: number)
	local at = Vector3.new(position.X, position.Y + rideHeight + 0.5, position.Z)
	local facing = Vector3.new(lookAt.X, at.Y, lookAt.Z)
	if (facing - at).Magnitude < 1 then
		facing = at + Vector3.new(0, 0, -1)
	end
	self.model:PivotTo(CFrame.lookAt(at, facing))
	self.chassis.AssemblyLinearVelocity = Vector3.zero
	self.chassis.AssemblyAngularVelocity = Vector3.zero
	self.stuck = PoliceDriveRules.newStuckState()
end

function PoliceDriver.destroy(self: PoliceDriver)
	self.physics:destroy()
end

return PoliceDriver
