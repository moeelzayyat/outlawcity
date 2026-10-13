--!strict
-- Tuning for server-side validation of client-simulated player vehicles. Read-only.
-- Mode is "Monitor": observations and alerts are logged only. No resets, kicks or bans exist.
local VehicleValidationConfig = {
	Mode = "Monitor",
	SampleInterval = 0.2, -- seconds between server samples of each player vehicle (5 Hz)

	-- Per-vehicle speed limit = MaxForwardSpeed * SpeedFactor + SpeedSlack (horizontal only).
	SpeedFactor = 1.3,
	SpeedSlack = 10,
	SustainSeconds = 1.0, -- over the limit this long (continuously) before it counts

	-- Position jump: horizontal displacement beyond limit * dt * DisplacementFactor + slack.
	DisplacementFactor = 1.5,
	DisplacementSlack = 12,
	ExtremeDistance = 150, -- a single jump this large scores double

	OwnershipGraceSeconds = 1.5, -- network owner may lag the SimulatedBy attribute this long
	SpawnGraceSeconds = 1.0, -- a newly seen vehicle settles before it is judged

	-- Scoring: each observation adds points; an alert needs AlertThreshold points within Window.
	AlertThreshold = 2,
	Window = 10,
	Points = {
		Teleport = 1,
		ExtremeTeleport = 2,
		SustainedOverspeed = 2,
		InvalidState = 2,
		OwnershipMismatch = 1,
	},

	LogLines = 40,
	SummaryInterval = 30,
}

local function deepFreeze(value: any)
	if type(value) == "table" and not table.isfrozen(value) then
		for _, child in value do
			deepFreeze(child)
		end
		table.freeze(value)
	end
end
deepFreeze(VehicleValidationConfig)

return VehicleValidationConfig
