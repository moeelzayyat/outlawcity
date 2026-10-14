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
	PlayerSpawnable: boolean?, -- false for NPC-only vehicles (default true)
}

export type VehicleInput = {
	Throttle: number, -- -1..1, positive drives forward
	Steer: number, -- -1..1, positive steers right
	Handbrake: boolean,
}

-- Error codes returned by RequestSpawnVehicle.
export type SpawnError = "BadRequest" | "UnknownVehicle" | "NotAlive" | "Cooldown" | "NoFreeSpawn" | "Jailed"

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
export type WantedNoticeKind = "Evading" | "Escaped" | "Busted"

-- Every player starts Peaceful; Combat is opt-in.
export type CombatStatus = "Peaceful" | "Combat"

-- Errors returned by RequestSetCombatStatus.
export type CombatSwitchError = "InvalidStatus" | "AlreadyInStatus" | "Wanted" | "Cooldown" | "RateLimited" | "NotInGame" | "Jailed"

-- Plain view of anything that can harm or be harmed; built by CombatService (or mocks in tests).
export type Combatant = {
	Kind: "Player" | "NpcPolice",
	UserId: number?,
	Status: CombatStatus?,
	WantedStars: number,
	InSafeZone: boolean,
	SpawnProtectedUntil: number,
	Jailed: boolean?, -- jailed players can't harm or be harmed by anyone
}

export type HarmContext = { Now: number, Action: "Attack" | "Bust" }

-- Axis-aligned safe-zone volume (world space).
export type SafeZone = { Name: string, Min: Vector3, Max: Vector3 }

-- Why CombatRules.canHarm refused.
export type HarmDenial = "Invalid" | "Self" | "NotWanted" | "AttackerPeaceful" | "VictimPeaceful" | "SafeZone" | "SpawnProtected" | "Jailed"

-- Persistent player data (DataStore). Version allows future migrations (vehicles owned, etc.).
export type Profile = {
	Version: number,
	Cash: number,
	RecentTransactions: { string }, -- most recent last; bounded; blocks duplicate grants/deductions
}

export type EconomyError =
	"InvalidAmount"
	| "InvalidTransactionId"
	| "DuplicateTransaction"
	| "InsufficientFunds"
	| "BalanceCap"
	| "DataNotLoaded"
	| "NotInGame"

-- Store robbery (Phase 4B).
export type RobberyPhase = "Holding" | "Escaping" | "Paid" | "Failed"
export type RobberyStartError = "Dead" | "Jailed" | "InSafeZone" | "InVehicle" | "TooFar" | "StoreCooldown" | "StoreBusy" | "AlreadyRobbing"
export type RobberyFailReason = "Died" | "Busted" | "LeftArea" | "Disconnected" | "EscapeTimedOut"

-- Errors from JailService.jailForBust.
export type JailError = "NotInGame" | "NotWanted" | "AlreadyJailed"

-- Actions a jailed player may not take.
export type JailAction = "SpawnVehicle" | "Drive" | "Combat" | "Robbery"

return {}
