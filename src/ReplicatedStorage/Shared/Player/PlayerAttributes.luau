--!strict
-- Names of the read-only gameplay attributes the server publishes on each Player.
-- Only the server writes them (client-set attributes never replicate); clients read them for UI.
local PlayerAttributes = table.freeze({
	Status = "Status", -- Types.PlayerStatus
	SpawnProtectedUntil = "SpawnProtectedUntil", -- server time (Workspace:GetServerTimeNow())
})

return PlayerAttributes
