--!strict
-- Pure Peaceful / Combat switching rules. Unit-tested in CombatStatusRules.spec.
-- Switching status never touches the wanted level: wanted state lives in WantedService only.
local Types = require(script.Parent.Parent.Types)

local CombatStatusRules = {}

export type State = { Status: Types.CombatStatus, CombatCooldownUntil: number }
type Config = { CombatCooldown: number }

-- Every player starts Peaceful.
function CombatStatusRules.new(): State
	return { Status = "Peaceful", CombatCooldownUntil = -math.huge }
end

-- Applies a requested switch. Returns (accepted, error).
function CombatStatusRules.requestSwitch(
	state: State,
	target: any,
	now: number,
	isWanted: boolean,
	config: Config
): (boolean, Types.CombatSwitchError?)
	if target ~= "Peaceful" and target ~= "Combat" then
		return false, "InvalidStatus"
	end
	if target == state.Status then
		return false, "AlreadyInStatus"
	end
	if target == "Combat" then
		state.Status = "Combat"
		state.CombatCooldownUntil = now + config.CombatCooldown
		return true, nil
	end
	if isWanted then
		return false, "Wanted"
	end
	if now < state.CombatCooldownUntil then
		return false, "Cooldown"
	end
	state.Status = "Peaceful"
	return true, nil
end

-- Combat activity (future: dealing or taking PvP damage) restarts the cooldown.
function CombatStatusRules.noteCombatActivity(state: State, now: number, config: Config)
	if state.Status == "Combat" then
		state.CombatCooldownUntil = math.max(state.CombatCooldownUntil, now + config.CombatCooldown)
	end
end

function CombatStatusRules.secondsUntilPeacefulAllowed(state: State, now: number): number
	return math.max(0, state.CombatCooldownUntil - now)
end

return CombatStatusRules
