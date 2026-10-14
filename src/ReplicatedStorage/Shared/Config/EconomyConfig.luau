--!strict
-- Economy and persistence tuning. Read-only at runtime.
local EconomyConfig = {
	StartingCash = 500,
	MaxBalance = 1_000_000_000,
	MaxTransaction = 1_000_000, -- largest single grant or deduction
	RecentTransactionLimit = 200, -- transaction ids remembered per player (duplicate guard)
	TransactionIdMaxLength = 64,
	ProfileVersion = 1,

	DataStoreName = "OutlawCity_PlayerData_v1", -- Studio uses DataStoreName .. "_Studio"
	LoadAttempts = 3, -- tries per load round, with exponential backoff
	RetryBaseDelay = 1, -- seconds; doubles each retry
	FailedRetryInterval = 30, -- seconds between background reloads after a failed load
	SessionLockTimeout = 180, -- seconds after which another server's lock counts as stale
	AutosaveInterval = 60,
	SaveAttempts = 3,
}

return table.freeze(EconomyConfig)
