--!strict
-- Open-world gameplay tuning shared by server and client. Read-only at runtime.
local GameplayConfig = {}

-- Seconds of protection after every spawn (also the SpawnLocation ForceField duration).
GameplayConfig.SpawnProtectionSeconds = 5
-- A civilian spawn counts as occupied if a character or vehicle is within this many studs.
GameplayConfig.SpawnClearance = 8

return table.freeze(GameplayConfig)
