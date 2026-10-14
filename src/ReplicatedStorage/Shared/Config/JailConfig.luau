--!strict
-- Short jail tuning. Read-only at runtime.
local JailConfig = {
	Seconds = 12, -- sentence length; always clamped to [MinSeconds, MaxSeconds]
	MinSeconds = 10,
	MaxSeconds = 15,
	CheckInterval = 0.25, -- server release-check cadence
}

return table.freeze(JailConfig)
