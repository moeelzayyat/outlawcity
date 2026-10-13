--!strict
-- Pure wanted-level rules engine: no Instances, no clocks, no networking. The server's
-- WantedService owns one state per player and feeds it crimes, time and police sightings.
-- Unit-tested in ServerStorage.Tests.WantedRules.spec.
local Types = require(script.Parent.Parent.Types)

type Config = Types.WantedConfig
type State = Types.WantedState

local WantedRules = {}

export type StepResult = {
	StarsChanged: boolean,
	EvadingStarted: boolean,
	EvadingStars: number, -- stars held at the moment evading began (before that tick's decay)
	Escaped: boolean,
	EscapedFromStars: number,
	Reputation: number,
}

function WantedRules.new(): State
	return {
		Heat = 0,
		Stars = 0,
		PeakStars = 0,
		LastCrimeAt = -math.huge,
		LastSeenAt = -math.huge,
		Evading = false,
		CrimeCooldowns = {},
	}
end

function WantedRules.maxStars(config: Config): number
	return #config.StarThresholds
end

function WantedRules.starsForHeat(heat: number, config: Config): number
	local stars = 0
	for index, threshold in config.StarThresholds do
		if heat >= threshold then
			stars = index
		end
	end
	return stars
end

function WantedRules.reputationForEscape(peakStars: number, config: Config): number
	if peakStars < config.EscapeMinStars then
		return 0
	end
	return config.EscapeReputation[peakStars] or 0
end

local function isFiniteNumber(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function setHeatInternal(state: State, heat: number, config: Config): boolean
	local before = state.Stars
	state.Heat = math.clamp(heat, 0, config.MaxHeat)
	state.Stars = WantedRules.starsForHeat(state.Heat, config)
	state.PeakStars = math.max(state.PeakStars, state.Stars)
	return state.Stars ~= before
end

-- Applies one crime. Returns (accepted, error, starsChanged).
function WantedRules.applyCrime(state: State, crimeType: any, now: number, config: Config): (boolean, Types.CrimeError?, boolean)
	if type(crimeType) ~= "string" then
		return false, "InvalidCrime", false
	end
	local crime = config.Crimes[crimeType]
	if not crime then
		return false, "InvalidCrime", false
	end
	local readyAt = state.CrimeCooldowns[crimeType]
	if readyAt and now < readyAt then
		return false, "Cooldown", false
	end
	state.CrimeCooldowns[crimeType] = now + crime.Cooldown
	state.LastCrimeAt = now
	state.Evading = false
	local changed = setHeatInternal(state, state.Heat + crime.Heat, config)
	return true, nil, changed
end

-- Sets heat directly (Studio dev tools only). Rejects non-finite values; clamps the rest.
function WantedRules.setHeat(state: State, heat: any, now: number, config: Config): (boolean, boolean)
	if not isFiniteNumber(heat) then
		return false, false
	end
	state.LastCrimeAt = now
	state.Evading = false
	local changed = setHeatInternal(state, heat, config)
	if state.Heat == 0 then
		state.PeakStars = 0
	end
	return true, changed
end

-- Clears the wanted level with no reward (busted, admin, leaving).
function WantedRules.reset(state: State)
	state.Heat = 0
	state.Stars = 0
	state.PeakStars = 0
	state.Evading = false
	table.clear(state.CrimeCooldowns)
end

-- Advances time. Heat decays only after DecayDelay seconds with no crime and no police
-- sighting. Threshold rule: a star is held while heat >= its threshold and is lost the
-- instant heat drops below it (so heat sitting exactly on a threshold loses that star on
-- the first decay tick). Notices report the stars held before the tick (EvadingStars).
-- Reaching zero heat ends the episode; it counts as an escape from PeakStars.
function WantedRules.step(state: State, now: number, dt: number, seenByPolice: boolean, config: Config): StepResult
	local result: StepResult = {
		StarsChanged = false,
		EvadingStarted = false,
		EvadingStars = 0,
		Escaped = false,
		EscapedFromStars = 0,
		Reputation = 0,
	}
	if state.Heat <= 0 then
		return result
	end
	if seenByPolice then
		state.LastSeenAt = now
	end
	local quietSince = math.max(state.LastCrimeAt, state.LastSeenAt)
	local evading = now - quietSince >= config.DecayDelay
	if evading and not state.Evading and state.Stars > 0 then
		result.EvadingStarted = true
		result.EvadingStars = state.Stars
	end
	state.Evading = evading
	if not evading then
		return result
	end
	result.StarsChanged = setHeatInternal(state, state.Heat - config.DecayRate * math.max(dt, 0), config)
	if state.Heat <= 0 then
		-- Losing any stars by evading is an escape; only EscapeMinStars+ escapes earn reputation.
		local peak = state.PeakStars
		result.Escaped = peak >= 1
		result.EscapedFromStars = peak
		result.Reputation = WantedRules.reputationForEscape(peak, config)
		state.PeakStars = 0
		state.Evading = false
	end
	return result
end

return WantedRules
