--!strict
-- Pure jail rules: sentencing, duplicate protection, release timing, restricted actions and
-- cell slot choice. The server (JailService) owns the clock and every decision.
-- Unit-tested in ServerStorage.Tests.JailRules.spec.
local Types = require(script.Parent.Parent.Types)

local JailRules = {}

export type State = { ReleaseAt: number?, Slot: number? }
type Config = { Seconds: number, MinSeconds: number, MaxSeconds: number }

local RESTRICTED: { [string]: boolean } = { SpawnVehicle = true, Drive = true, Combat = true, Robbery = true }

function JailRules.new(): State
	return { ReleaseAt = nil, Slot = nil }
end

-- Sentence length in seconds, always within [MinSeconds, MaxSeconds].
function JailRules.clampSeconds(seconds: any, config: Config): number
	local value = if type(seconds) == "number" and seconds == seconds then seconds else config.Seconds
	return math.clamp(value, config.MinSeconds, config.MaxSeconds)
end

-- A player is jailed from sentencing until the server releases them (not merely until the
-- clock passes ReleaseAt), so nothing slips through between the deadline and the release.
function JailRules.isJailed(state: State): boolean
	return state.ReleaseAt ~= nil
end

-- Starts a sentence. Refuses duplicates and players who aren't wanted.
function JailRules.sentence(state: State, now: number, seconds: number, isWanted: boolean): (boolean, Types.JailError?)
	if state.ReleaseAt ~= nil then
		return false, "AlreadyJailed"
	end
	if not isWanted then
		return false, "NotWanted"
	end
	state.ReleaseAt = now + seconds
	return true, nil
end

function JailRules.dueForRelease(state: State, now: number): boolean
	return state.ReleaseAt ~= nil and now >= (state.ReleaseAt :: number)
end

function JailRules.release(state: State)
	state.ReleaseAt = nil
	state.Slot = nil
end

-- Whole seconds left, rounded up, for the countdown.
function JailRules.secondsLeft(releaseAt: number, now: number): number
	return math.max(0, math.ceil(releaseAt - now))
end

function JailRules.allows(state: State, action: Types.JailAction): boolean
	return not (JailRules.isJailed(state) and RESTRICTED[action] == true)
end

-- First free cell slot; if all are taken, share the least-recently-numbered one.
function JailRules.pickSlot(occupied: { [number]: boolean }, slotCount: number): number
	for slot = 1, slotCount do
		if not occupied[slot] then
			return slot
		end
	end
	local taken = 0
	for _ in occupied do
		taken += 1
	end
	return (taken % slotCount) + 1
end

return JailRules
