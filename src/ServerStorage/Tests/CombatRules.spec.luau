local ReplicatedStorage = game:GetService("ReplicatedStorage")
local CombatRules = require(ReplicatedStorage.Shared.Combat.CombatRules)
local Assert = require(script.Parent.Assert)

local NOW = 1000

-- Mock players: no Player instances needed.
local function player(userId: number, overrides: { [string]: any }?)
	local p = {
		Kind = "Player",
		UserId = userId,
		Status = "Peaceful",
		WantedStars = 0,
		InSafeZone = false,
		SpawnProtectedUntil = 0,
	}
	for key, value in overrides or {} do
		p[key] = value
	end
	return p
end
local POLICE = { Kind = "NpcPolice", WantedStars = 0, InSafeZone = false, SpawnProtectedUntil = 0 }
local ATTACK = { Now = NOW, Action = "Attack" }
local BUST = { Now = NOW, Action = "Bust" }

local function expect(attacker, victim, context, allowed: boolean, reason: string?)
	local ok, why = CombatRules.canHarm(attacker, victim, context)
	Assert.equal(ok, allowed, `expected {allowed}, got {ok} ({tostring(why)})`)
	Assert.equal(why, reason)
end

return {
	["full player-vs-player matrix outside safe zones"] = function()
		-- attacker status x victim status x victim wanted
		local cases = {
			{ "Peaceful", "Peaceful", 0, false, "AttackerPeaceful" },
			{ "Peaceful", "Combat", 0, false, "AttackerPeaceful" },
			{ "Peaceful", "Peaceful", 2, false, "AttackerPeaceful" }, -- wanted alone does not authorise peaceful attackers
			{ "Peaceful", "Combat", 2, false, "AttackerPeaceful" },
			{ "Combat", "Peaceful", 0, false, "VictimPeaceful" },
			{ "Combat", "Combat", 0, true, nil },
			{ "Combat", "Peaceful", 1, true, nil }, -- wanted players lose peaceful protection
			{ "Combat", "Combat", 3, true, nil },
		}
		for _, c in cases do
			local attacker = player(1, { Status = c[1] })
			local victim = player(2, { Status = c[2], WantedStars = c[3] })
			expect(attacker, victim, ATTACK, c[4], c[5])
		end
	end,
	["safe zones block PvP even against wanted players"] = function()
		local attacker = player(1, { Status = "Combat" })
		expect(attacker, player(2, { Status = "Combat", InSafeZone = true }), ATTACK, false, "SafeZone")
		expect(attacker, player(2, { Status = "Combat", WantedStars = 3, InSafeZone = true }), ATTACK, false, "SafeZone")
		expect(player(1, { Status = "Combat", InSafeZone = true }), player(2, { Status = "Combat" }), ATTACK, false, "SafeZone")
	end,
	["spawn protection blocks PvP both ways"] = function()
		local fresh = player(2, { Status = "Combat", SpawnProtectedUntil = NOW + 3 })
		expect(player(1, { Status = "Combat" }), fresh, ATTACK, false, "SpawnProtected")
		expect(fresh, player(1, { Status = "Combat" }), ATTACK, false, "SpawnProtected")
		local expired = player(2, { Status = "Combat", SpawnProtectedUntil = NOW - 0.1 })
		expect(player(1, { Status = "Combat" }), expired, ATTACK, true, nil)
	end,
	["players cannot harm themselves"] = function()
		local p = player(7, { Status = "Combat" })
		expect(p, p, ATTACK, false, "Self")
	end,
	["NPC police bust wanted players regardless of status, zone or spawn protection"] = function()
		for _, status in { "Peaceful", "Combat" } do
			expect(POLICE, player(2, { Status = status, WantedStars = 1 }), BUST, true, nil)
			expect(POLICE, player(2, { Status = status, WantedStars = 3, InSafeZone = true }), BUST, true, nil)
			expect(POLICE, player(2, { Status = status, WantedStars = 2, SpawnProtectedUntil = NOW + 5 }), BUST, true, nil)
		end
	end,
	["NPC police never touch players who are not wanted"] = function()
		expect(POLICE, player(2, { Status = "Combat" }), BUST, false, "NotWanted")
		expect(POLICE, player(2, { Status = "Peaceful" }), ATTACK, false, "NotWanted")
	end,
	["malformed input is denied"] = function()
		expect(nil :: any, player(2), ATTACK, false, "Invalid")
		expect(player(1), nil :: any, ATTACK, false, "Invalid")
		expect(player(1), player(2), nil :: any, false, "Invalid")
		expect({ Kind = "Dragon" }, player(2, { Status = "Combat" }), ATTACK, false, "Invalid")
		expect(player(1, { Status = "Combat" }), POLICE, ATTACK, false, "Invalid")
	end,
}
