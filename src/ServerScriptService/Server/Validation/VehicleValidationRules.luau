--!strict
-- Pure validation of server-observed vehicle samples. Never trusts anything the client says:
-- it only sees positions/velocities the server reads from the replicated chassis.
-- Unit-tested in ServerStorage.Tests.VehicleValidation.spec.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)

local VehicleValidationRules = {}

export type Sample = { Time: number, Position: Vector3, Velocity: Vector3, OwnerOk: boolean }
export type Limits = { MaxSpeed: number }
export type Observation = { Kind: string, Detail: string, Points: number }
export type TrackState = {
	Last: Sample?,
	OverspeedTime: number,
	MismatchTime: number,
	GraceUntil: number,
	Scores: { { number } }, -- { time, points }
}
export type Result = { Observations: { Observation }, Alert: string? }

type Config = {
	SpeedFactor: number,
	SpeedSlack: number,
	SustainSeconds: number,
	DisplacementFactor: number,
	DisplacementSlack: number,
	ExtremeDistance: number,
	OwnershipGraceSeconds: number,
	AlertThreshold: number,
	Window: number,
	Points: { [string]: number },
}

local function finite(n: number): boolean
	return n == n and n ~= math.huge and n ~= -math.huge
end

function VehicleValidationRules.isFiniteVector(v: any): boolean
	return typeof(v) == "Vector3" and finite(v.X) and finite(v.Y) and finite(v.Z)
end

function VehicleValidationRules.limitsFor(stats: Types.VehicleStats, config: Config): Limits
	return { MaxSpeed = stats.MaxForwardSpeed * config.SpeedFactor + config.SpeedSlack }
end

function VehicleValidationRules.new(now: number, graceSeconds: number): TrackState
	return { Last = nil, OverspeedTime = 0, MismatchTime = 0, GraceUntil = now + graceSeconds, Scores = {} }
end

-- Authorized server-side move (spawn, reposition, recovery): skip judgement for a while and
-- start a fresh baseline afterwards.
function VehicleValidationRules.grant(state: TrackState, now: number, seconds: number)
	state.GraceUntil = math.max(state.GraceUntil, now + seconds)
	state.Last = nil
	state.OverspeedTime = 0
end

local function flat(v: Vector3): Vector3
	return Vector3.new(v.X, 0, v.Z)
end

function VehicleValidationRules.observe(state: TrackState, sample: Sample, limits: Limits, config: Config): Result
	local observations: { Observation } = {}
	local function add(kind: string, detail: string, pointsKey: string?)
		table.insert(observations, { Kind = kind, Detail = detail, Points = config.Points[pointsKey or kind] or 1 })
	end

	if not VehicleValidationRules.isFiniteVector(sample.Position) or not VehicleValidationRules.isFiniteVector(sample.Velocity) then
		add("InvalidState", "non-finite position or velocity")
	elseif sample.Time < state.GraceUntil then
		state.Last = sample
		state.OverspeedTime = 0
		state.MismatchTime = 0
	else
		local last = state.Last
		local dt = if last then sample.Time - last.Time else 0
		if last and dt > 0 then
			local distance = flat(sample.Position - last.Position).Magnitude
			local allowed = limits.MaxSpeed * dt * config.DisplacementFactor + config.DisplacementSlack
			if distance > allowed then
				local extreme = distance > config.ExtremeDistance
				add("Teleport", string.format("moved %.0f studs in %.2f s (allowed %.0f)", distance, dt, allowed), if extreme then "ExtremeTeleport" else "Teleport")
			end
			local speed = flat(sample.Velocity).Magnitude
			if speed > limits.MaxSpeed then
				state.OverspeedTime += dt
				if state.OverspeedTime >= config.SustainSeconds then
					add("SustainedOverspeed", string.format("%.0f studs/s for %.1f s (limit %.0f)", speed, state.OverspeedTime, limits.MaxSpeed))
					state.OverspeedTime = 0
				end
			else
				state.OverspeedTime = 0
			end
			if not sample.OwnerOk then
				state.MismatchTime += dt
				if state.MismatchTime >= config.OwnershipGraceSeconds then
					add("OwnershipMismatch", string.format("network owner differs from SimulatedBy for %.1f s", state.MismatchTime))
					state.MismatchTime = 0
				end
			else
				state.MismatchTime = 0
			end
		end
		state.Last = sample
	end

	-- Score within the window; alert at the threshold, then start counting afresh.
	for _, o in observations do
		table.insert(state.Scores, { sample.Time, o.Points })
	end
	local total, kept = 0, {}
	for _, entry in state.Scores do
		if sample.Time - entry[1] <= config.Window then
			table.insert(kept, entry)
			total += entry[2]
		end
	end
	state.Scores = kept
	local alert: string? = nil
	if #observations > 0 and total >= config.AlertThreshold then
		local kinds = {}
		for _, o in observations do
			table.insert(kinds, o.Kind)
		end
		alert = string.format("%d points in %ds (latest: %s)", total, config.Window, table.concat(kinds, ", "))
		state.Scores = {}
	end
	return { Observations = observations, Alert = alert }
end

return VehicleValidationRules
