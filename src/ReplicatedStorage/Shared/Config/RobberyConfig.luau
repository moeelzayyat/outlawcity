--!strict
-- Store robbery tuning. Read-only at runtime. Every value here is owner-configurable.
local RobberyConfig = {
	HoldSeconds = 15, -- server-timed holdout inside the store
	Reward = 2000, -- paid only after a completed holdout AND a successful escape
	WantedCrime = "StoreRobbery", -- WantedConfig crime reported at the start (70 heat = 2 stars)
	InProgressCrime = "RobberyInProgress", -- re-reported while holding so heat can't decay early
	CooldownSeconds = 180, -- per store, from the moment a robbery starts
	-- EXPERIMENTAL (audit 4 trial, P5; decide after human playtests): after a FAILED robbery
	-- the store reopens 90 s after that robbery started instead of 180 s. Successful robberies
	-- keep 180 s. Set to nil to restore the old behaviour (180 s after any robbery).
	FailedCooldownSeconds = 90,
	PromptDistance = 10, -- studs from the register to start
	DistanceSlack = 4, -- extra studs the server allows for latency
	MaxEscapeSeconds = 300, -- after the holdout, escape within this or the payout is lost
	TickInterval = 0.25,
	-- Owner decision (4B follow-up): stars and the police alert come at the start, but the NPC
	-- unit is only sent when the holdout ends, so a robber has a head start to the getaway car.
	PoliceDispatchAtHoldEnd = true,
}

return table.freeze(RobberyConfig)
