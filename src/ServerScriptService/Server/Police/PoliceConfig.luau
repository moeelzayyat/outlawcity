--!strict
-- NPC police tuning (server only). Read-only at runtime.
local PoliceConfig = {
	-- Dispatch
	MaxUnits = 1, -- Phase 3D prototype: a single unit. Raise only after owner approval.
	SpawnMinDistance = 160, -- spawn road nodes at least this far from the target...
	SpawnMaxDistance = 450, -- ...and preferably no farther than this
	DespawnDelay = 3, -- seconds a unit lingers after its pursuit ends
	LostTargetRespawnDistance = 650, -- if this far behind for LostTargetSeconds, respawn closer
	LostTargetSeconds = 10,

	-- Perception
	-- Audit remediation, EXPERIMENTAL pursuit tuning (owner/auditor review pending):
	-- SightRange 160 -> 130, ChaseSpeed 110 -> 100, ChaseGain 1.0 -> 0.25. Baseline values in
	-- the comments; WantedConfig.DecayDelay stays 8 s.
	SightRange = 130, -- studs; plus a clear line of sight (baseline 160)
	DirectChaseRange = 90, -- within this and in sight, drive straight at the target

	-- Driving (studs/s, studs, radians)
	CruiseSpeed = 95,
	ChaseSpeed = 100, -- baseline 110
	CornerSpeedMin = 30,
	CornerDecel = 1.1, -- allowed speed grows by this per stud of distance before a corner
	WaypointRadius = 16,
	MaxSteerAngle = math.rad(35),
	ThrottleGain = 1 / 8,
	WhiskerAngle = math.rad(25),
	WhiskerMinLength = 18,
	WhiskerSpeedFactor = 0.6,
	ReplanInterval = 1,
	ChaseLookAhead = 0.5, -- seconds of target velocity to lead by in direct chase
	ChaseFollowDistance = 10, -- gap the chase-speed rule closes down to
	ChaseGain = 0.25, -- extra studs/s per stud of gap beyond the follow distance (baseline 1.0)

	-- Stuck handling
	StuckSpeed = 3,
	StuckSeconds = 1.5,
	ReverseSeconds = 1.2,
	HardRecoverAfter = 3, -- soft recoveries within RecoveryWindow before a reposition
	RecoveryWindow = 20,

	-- Busting
	BustRange = 18,
	BustSeconds = 2.5,
	BustMaxTargetSpeed = 5,

	-- Diagnostics
	LogInterval = 5,
}

return table.freeze(PoliceConfig)
