--!strict
-- Economy and persistence tuning. Read-only at runtime.
local EconomyConfig = {
	StartingCash = 500,
	MaxBalance = 1_000_000_000,
	MaxTransaction = 1_000_000, -- largest single grant or deduction
	RecentTransactionLimit = 200, -- transaction ids remembered per player (duplicate guard)
	TransactionIdMaxLength = 64,
	-- 1: cash only (4A). 2: + OwnedVehicles (4C). Older records are migrated on load; a record
	-- from a NEWER version is refused untouched, so an old server can never downgrade it.
	ProfileVersion = 3, -- 3 (audit remediation): + PaidRewards (durable reward dedupe)
	StarterVehicles = table.freeze({ "Coupe" }), -- every profile owns these (new and migrated)
	MaxOwnedVehicles = 50,
	VehicleIdMaxLength = 32,

	DataStoreName = "OutlawCity_PlayerData_v1", -- Studio uses DataStoreName .. "_Studio"
	LoadAttempts = 3, -- tries per load round, with exponential backoff
	RetryBaseDelay = 1, -- seconds; doubles each retry
	FailedRetryInterval = 30, -- seconds between background reloads after a failed load
	SessionLockTimeout = 180, -- seconds after which another server's lock counts as stale
	AutosaveInterval = 60,
	SaveAttempts = 3,
	-- Earned-but-unpaid rewards are recorded here first (separate store), so they survive a
	-- failed profile save, a disconnect or a server crash. Claimed on the next load.
	RewardStoreName = "OutlawCity_PendingRewards_v1",
	CommitAttempts = 3, -- write-through tries per cash change (each retry reconciles from the store first)
	MaxPaidRewards = 1000, -- paid-reward ids kept until the ledger drops them
	LedgerMaxEntries = 50, -- unpaid rewards per player in the ledger; more is refused as LedgerFull
	ClaimRetryBase = 30, -- seconds; ledger claim retry after a failure, doubling...
	ClaimRetryMax = 900, -- ...up to this
	ClaimIdleInterval = 300, -- seconds between ledger checks when nothing is outstanding
	-- If the save on leave fails, the unsaved profile is kept on this server and retried.
	OrphanRetryInterval = 10,
	OrphanRetryLimit = 900, -- seconds; stops early if another server takes the lock
}

return table.freeze(EconomyConfig)
