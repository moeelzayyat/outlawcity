--!strict
-- Shared type definitions. Anything that crosses a module or network boundary is typed here.

export type VehicleStats = {
	DisplayName: string,
	BodyColor: Color3,
	ChassisSize: Vector3,
	-- Suspension anchor points relative to the chassis centre, ordered FL, FR, RL, RR.
	-- The front of every vehicle is -Z (the chassis LookVector).
	WheelOffsets: { Vector3 },
	WheelRadius: number,
	WheelWidth: number,
	SuspensionRestLength: number,
	StaticCompressionRatio: number, -- 0..1: how compressed each spring sits at rest
	DampingRatio: number, -- fraction of critical damping per wheel
	-- Longitudinal, in studs/s and studs/s^2
	MaxForwardSpeed: number,
	MaxReverseSpeed: number,
	Acceleration: number,
	ReverseAcceleration: number,
	BrakeDeceleration: number,
	HandbrakeDeceleration: number,
	RollingDeceleration: number,
	DragCoefficient: number,
	-- Steering and grip, in rad/s and 1/s approach rates
	MaxYawRate: number,
	FullSteerSpeed: number,
	HighSpeedSteerReduction: number,
	HandbrakeYawMultiplier: number,
	YawResponse: number,
	LateralGrip: number,
	HandbrakeLateralGrip: number,
	MaxSteerAngle: number, -- visual front-wheel angle, radians
}

export type VehicleInput = {
	Throttle: number, -- -1..1, positive drives forward
	Steer: number, -- -1..1, positive steers right
	Handbrake: boolean,
}

-- Error codes returned by RequestSpawnVehicle.
export type SpawnError = "BadRequest" | "UnknownVehicle" | "NotAlive" | "Cooldown" | "NoFreeSpawn"

-- Every player is a civilian in the open world; more statuses may follow (e.g. "Jailed").
export type PlayerStatus = "Civilian"

export type CrimeDefinition = { Heat: number, Cooldown: number }

-- The number of wanted stars is #StarThresholds (3 for the MVP; extendable to 5).
export type WantedConfig = {
	StarThresholds: { number },
	MaxHeat: number,
	DecayDelay: number,
	DecayRate: number,
	EscapeMinStars: number,
	EscapeReputation: { [number]: number },
	Crimes: { [string]: CrimeDefinition },
}

export type WantedState = {
	Heat: number,
	Stars: number,
	PeakStars: number,
	LastCrimeAt: number,
	LastSeenAt: number,
	Evading: boolean,
	CrimeCooldowns: { [string]: number },
}

export type CrimeError = "InvalidCrime" | "Cooldown" | "NotInGame"

-- Kinds sent through OnWantedNotice.
export type WantedNoticeKind = "Evading" | "Escaped"

return {}
