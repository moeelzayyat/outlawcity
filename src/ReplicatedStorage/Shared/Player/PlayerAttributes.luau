--!strict
-- Names of the read-only gameplay attributes the server publishes on each Player.
-- Only the server writes them (client-set attributes never replicate); clients read them for UI.
local PlayerAttributes = table.freeze({
	Status = "Status", -- Types.PlayerStatus
	SpawnProtectedUntil = "SpawnProtectedUntil", -- server time (Workspace:GetServerTimeNow())
	WantedLevel = "WantedLevel", -- stars, 0..#WantedConfig.StarThresholds
	WantedHeat = "WantedHeat", -- heat, 0..WantedConfig.MaxHeat (1 decimal)
	WantedEvading = "WantedEvading", -- true while heat is decaying
	CriminalReputation = "CriminalReputation", -- earned by escapes (session only until persistence)
	CombatStatus = "CombatStatus", -- Types.CombatStatus
	CombatCooldownUntil = "CombatCooldownUntil", -- server time before which Peaceful is refused (0 = none)
	InSafeZone = "InSafeZone", -- set by SafeZoneService (4 Hz); absent means false
	Jailed = "Jailed", -- true while serving a jail sentence (JailService)
	JailReleaseAt = "JailReleaseAt", -- server time the sentence ends (0 when not jailed)
	Cash = "Cash", -- server-authoritative balance (EconomyService); absent until data has loaded
	CashStatus = "CashStatus", -- "Loading" | "Loaded" | "Unavailable"
	OwnedVehicles = "OwnedVehicles", -- comma-separated vehicle ids from the profile (display only)
	RobberyPhase = "RobberyPhase", -- "Holding" | "Escaping" | "PayoutPending" while a robbery is live or unpaid (else nil)
	RobberyHoldEndsAt = "RobberyHoldEndsAt", -- server time the holdout completes
	RobberyReward = "RobberyReward", -- cash promised for escaping (display only)
})

return PlayerAttributes
