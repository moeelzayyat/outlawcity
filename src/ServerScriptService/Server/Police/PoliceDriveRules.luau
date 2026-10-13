--!strict
-- Pure NPC driving decisions: steering toward a point, corner speed, throttle, and the
-- stuck-detection state machine. No Instances. Unit-tested in PoliceNavigation.spec.
local PoliceDriveRules = {}

export type StuckState = { StuckTime: number, ReverseTimeLeft: number, Recoveries: { number } }
export type StuckAction = "Drive" | "Reverse" | "HardRecover"

-- localTarget is in the chassis frame (forward = -Z). Returns (steer -1..1, headingError rad).
function PoliceDriveRules.steerToward(localTarget: Vector3, maxSteerAngle: number): (number, number)
	local angle = math.atan2(localTarget.X, -localTarget.Z)
	return math.clamp(angle / maxSteerAngle, -1, 1), angle
end

-- Turn angle at b when driving a -> b -> c, in radians (0 = straight, pi = U-turn), XZ only.
function PoliceDriveRules.cornerAngle(a: Vector3, b: Vector3, c: Vector3): number
	local u = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local v = Vector3.new(c.X - b.X, 0, c.Z - b.Z)
	if u.Magnitude < 1e-3 or v.Magnitude < 1e-3 then
		return 0
	end
	return math.acos(math.clamp(u.Unit:Dot(v.Unit), -1, 1))
end

-- Desired speed given the distance to the next corner, how sharp it is, and how far the car
-- is currently pointing away from its target.
function PoliceDriveRules.targetSpeed(
	distanceToCorner: number,
	cornerAngle: number,
	headingError: number,
	cruiseSpeed: number,
	config: { CornerSpeedMin: number, CornerDecel: number }
): number
	local sharpness = math.clamp(cornerAngle / (math.pi / 2), 0, 1)
	local cornerSpeed = config.CornerSpeedMin + (cruiseSpeed - config.CornerSpeedMin) * (1 - sharpness)
	local speed = math.min(cruiseSpeed, cornerSpeed + math.max(distanceToCorner, 0) * config.CornerDecel)
	if math.abs(headingError) > math.rad(60) then
		speed = math.min(speed, config.CornerSpeedMin)
	end
	return speed
end

-- Speed for following a moving target: match its speed, plus a closing term for the gap
-- beyond `followDistance`; never negative, never above `maxSpeed`.
function PoliceDriveRules.chaseSpeed(targetSpeed: number, gap: number, followDistance: number, gain: number, maxSpeed: number): number
	return math.clamp(targetSpeed + (gap - followDistance) * gain, 0, maxSpeed)
end

function PoliceDriveRules.throttleFor(targetSpeed: number, forwardSpeed: number, gain: number): number
	return math.clamp((targetSpeed - forwardSpeed) * gain, -1, 1)
end

function PoliceDriveRules.newStuckState(): StuckState
	return { StuckTime = 0, ReverseTimeLeft = 0, Recoveries = {} }
end

-- Advances stuck detection. "Reverse" = back off and turn away; "HardRecover" = too many
-- recoveries in the window, the caller should reposition the unit on the road network.
function PoliceDriveRules.updateStuck(
	state: StuckState,
	dt: number,
	now: number,
	speed: number,
	wantsToMove: boolean,
	config: { StuckSpeed: number, StuckSeconds: number, ReverseSeconds: number, HardRecoverAfter: number, RecoveryWindow: number }
): StuckAction
	if state.ReverseTimeLeft > 0 then
		state.ReverseTimeLeft -= dt
		return "Reverse"
	end
	if wantsToMove and speed < config.StuckSpeed then
		state.StuckTime += dt
	else
		state.StuckTime = 0
	end
	if state.StuckTime < config.StuckSeconds then
		return "Drive"
	end
	state.StuckTime = 0
	local recent = {}
	for _, t in state.Recoveries do
		if now - t <= config.RecoveryWindow then
			table.insert(recent, t)
		end
	end
	table.insert(recent, now)
	if #recent >= config.HardRecoverAfter then
		state.Recoveries = {}
		return "HardRecover"
	end
	state.Recoveries = recent
	state.ReverseTimeLeft = config.ReverseSeconds
	return "Reverse"
end

return PoliceDriveRules
