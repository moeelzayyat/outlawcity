--!strict
-- The single gate for anything that harms or arrests a player. Every future damage source
-- (weapons, vehicle damage, melee) and NPC police busts must call CombatRules.canHarm and
-- obey its answer. Pure: takes plain tables, so solo tests can use mock players.
-- Unit-tested in ServerStorage.Tests.CombatRules.spec.
local Types = require(script.Parent.Parent.Types)

local CombatRules = {}

-- Returns (allowed, reasonWhenDenied).
function CombatRules.canHarm(
	attacker: Types.Combatant,
	victim: Types.Combatant,
	context: Types.HarmContext
): (boolean, Types.HarmDenial?)
	if type(attacker) ~= "table" or type(victim) ~= "table" or type(context) ~= "table" then
		return false, "Invalid"
	end
	if victim.Kind ~= "Player" then
		return false, "Invalid"
	end
	if attacker.Kind == "Player" and attacker.UserId ~= nil and attacker.UserId == victim.UserId then
		return false, "Self"
	end
	-- Jailed players are out of play: nobody harms or busts them, and they harm nobody.
	if victim.Jailed or (attacker.Kind == "Player" and attacker.Jailed) then
		return false, "Jailed"
	end

	-- NPC police: may pursue and bust wanted players regardless of combat status, safe zones
	-- or spawn protection. Never touches players who are not wanted.
	if attacker.Kind == "NpcPolice" then
		if victim.WantedStars > 0 then
			return true, nil
		end
		return false, "NotWanted"
	end
	if attacker.Kind ~= "Player" then
		return false, "Invalid"
	end

	-- Player vs player.
	if attacker.Status ~= "Combat" then
		-- A peaceful player cannot attack anyone, wanted victims included.
		return false, "AttackerPeaceful"
	end
	if victim.Status ~= "Combat" and victim.WantedStars <= 0 then
		-- Peaceful players are protected unless they are wanted.
		return false, "VictimPeaceful"
	end
	if attacker.InSafeZone or victim.InSafeZone then
		-- Ordinary PvP never happens in safe zones, even against wanted players.
		return false, "SafeZone"
	end
	if context.Now < victim.SpawnProtectedUntil or context.Now < attacker.SpawnProtectedUntil then
		return false, "SpawnProtected"
	end
	return true, nil
end

return CombatRules
