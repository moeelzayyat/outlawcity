--!strict
-- Peaceful / Combat status tuning. Read-only at runtime.
local CombatConfig = {}

-- Seconds after entering Combat (or after the last combat activity) before the player may
-- switch back to Peaceful.
CombatConfig.CombatCooldown = 30
-- Minimum seconds between combat-status requests from one player (anti-spam).
CombatConfig.RequestInterval = 1

return table.freeze(CombatConfig)
