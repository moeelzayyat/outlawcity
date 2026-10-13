local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WantedRules = require(ReplicatedStorage.Shared.Wanted.WantedRules)
local WantedConfig = require(ReplicatedStorage.Shared.Config.WantedConfig)
local Assert = require(script.Parent.Assert)

local C = WantedConfig
local DT = 0.25

-- Runs step() from `from` for `seconds`, returning the last result and whether any step escaped.
local function run(state, from: number, seconds: number, seenByPolice: boolean?)
	local now, last, escaped, evadingStarted = from, nil, nil, false
	for _ = 1, math.floor(seconds / DT) do
		now += DT
		last = WantedRules.step(state, now, DT, seenByPolice == true, C)
		if last.Escaped then
			escaped = last
		end
		evadingStarted = evadingStarted or last.EvadingStarted
	end
	return now, last, escaped, evadingStarted
end

local function withHeat(heat: number)
	local state = WantedRules.new()
	assert(WantedRules.setHeat(state, heat, 0, C))
	return state
end

return {
	["MVP has exactly three stars"] = function()
		Assert.equal(WantedRules.maxStars(C), 3)
	end,
	["heat thresholds map to stars"] = function()
		local t = C.StarThresholds
		Assert.equal(WantedRules.starsForHeat(0, C), 0)
		Assert.equal(WantedRules.starsForHeat(t[1] - 0.01, C), 0)
		Assert.equal(WantedRules.starsForHeat(t[1], C), 1)
		Assert.equal(WantedRules.starsForHeat(t[2], C), 2)
		Assert.equal(WantedRules.starsForHeat(t[3], C), 3)
		Assert.equal(WantedRules.starsForHeat(C.MaxHeat, C), 3)
	end,
	["five-star config works without code changes"] = function()
		local five = table.clone(C) :: any
		five.StarThresholds = { 10, 40, 100, 160, 240 }
		five.MaxHeat = 300
		Assert.equal(WantedRules.maxStars(five), 5)
		Assert.equal(WantedRules.starsForHeat(250, five), 5)
		Assert.equal(WantedRules.reputationForEscape(5, five), C.EscapeReputation[5])
	end,
	["a crime adds heat and stars"] = function()
		local state = WantedRules.new()
		local ok, err, changed = WantedRules.applyCrime(state, "RammingPolice", 0, C)
		Assert.equal(ok, true)
		Assert.equal(err, nil)
		Assert.equal(changed, true)
		Assert.equal(state.Heat, C.Crimes.RammingPolice.Heat)
		Assert.equal(state.Stars, WantedRules.starsForHeat(C.Crimes.RammingPolice.Heat, C))
	end,
	["repeated crimes respect the cooldown and the heat cap"] = function()
		local state = WantedRules.new()
		local crime = C.Crimes.RammingPolice
		Assert.equal((WantedRules.applyCrime(state, "RammingPolice", 0, C)), true)
		local ok, err = WantedRules.applyCrime(state, "RammingPolice", crime.Cooldown / 2, C)
		Assert.equal(ok, false)
		Assert.equal(err, "Cooldown")
		Assert.equal(state.Heat, crime.Heat)
		local now = 0
		for _ = 1, 50 do
			now += crime.Cooldown
			WantedRules.applyCrime(state, "RammingPolice", now, C)
		end
		Assert.equal(state.Heat, C.MaxHeat)
		Assert.equal(state.Stars, WantedRules.maxStars(C))
	end,
	["invalid input is rejected without changing state"] = function()
		local state = WantedRules.new()
		for _, bad in { "NotACrime", "", 42, {}, true } do
			local ok, err = WantedRules.applyCrime(state, bad, 0, C)
			Assert.equal(ok, false)
			Assert.equal(err, "InvalidCrime")
		end
		Assert.equal((WantedRules.applyCrime(state, nil, 0, C)), false)
		for _, bad in { 0 / 0, math.huge, -math.huge, "50" } do
			Assert.equal((WantedRules.setHeat(state, bad, 0, C)), false)
		end
		Assert.equal(state.Heat, 0)
		Assert.equal(state.Stars, 0)
	end,
	["setHeat clamps to the valid range"] = function()
		local state = WantedRules.new()
		WantedRules.setHeat(state, 9999, 0, C)
		Assert.equal(state.Heat, C.MaxHeat)
		WantedRules.setHeat(state, -5, 0, C)
		Assert.equal(state.Heat, 0)
		Assert.equal(state.Stars, 0)
	end,
	["no decay before the delay"] = function()
		local state = withHeat(C.StarThresholds[2])
		local _, last = run(state, 0, C.DecayDelay - 1)
		Assert.equal(state.Heat, C.StarThresholds[2])
		Assert.equal(last.EvadingStarted, false)
	end,
	["police sightings block decay"] = function()
		local state = withHeat(C.StarThresholds[2])
		run(state, 0, C.DecayDelay * 3, true)
		Assert.equal(state.Heat, C.StarThresholds[2])
		Assert.equal(state.Evading, false)
	end,
	["decay starts evading and steps stars down"] = function()
		local state = withHeat(C.StarThresholds[3])
		local _, _, _, evadingStarted = run(state, 0, C.DecayDelay + 2)
		Assert.equal(evadingStarted, true)
		Assert.truthy(state.Heat < C.StarThresholds[3], "heat decayed")
		Assert.equal(state.Stars, 2)
	end,
	["escape completes with reputation from peak stars"] = function()
		local state = withHeat(C.StarThresholds[3])
		local seconds = C.DecayDelay + C.MaxHeat / C.DecayRate + 2
		local _, _, escaped = run(state, 0, seconds)
		Assert.truthy(escaped, "escape event")
		Assert.equal(escaped.EscapedFromStars, 3)
		Assert.equal(escaped.Reputation, C.EscapeReputation[3])
		Assert.equal(state.Heat, 0)
		Assert.equal(state.Stars, 0)
		Assert.equal(state.PeakStars, 0)
	end,
	["one-star escape is announced but earns nothing"] = function()
		local state = withHeat(C.StarThresholds[1])
		local _, _, escaped = run(state, 0, C.DecayDelay + 10)
		Assert.truthy(escaped, "escape event")
		Assert.equal(escaped.EscapedFromStars, 1)
		Assert.equal(escaped.Reputation, 0)
	end,
	["a new crime while evading restarts the delay"] = function()
		local state = withHeat(C.StarThresholds[2])
		local now = run(state, 0, C.DecayDelay + 1)
		Assert.equal(state.Evading, true)
		WantedRules.applyCrime(state, "SpeedingNearPolice", now, C)
		Assert.equal(state.Evading, false)
		local heat = state.Heat
		run(state, now, C.DecayDelay - 1)
		Assert.equal(state.Heat, heat)
	end,
	["heat exactly on a threshold loses that star on the first decay tick; notice keeps the prior stars"] = function()
		local state = withHeat(C.StarThresholds[3])
		local evadingResult
		local now = 0
		for _ = 1, math.floor((C.DecayDelay + 1) / DT) do
			now += DT
			local r = WantedRules.step(state, now, DT, false, C)
			if r.EvadingStarted then
				evadingResult = r
				break
			end
		end
		Assert.truthy(evadingResult, "evading started")
		Assert.equal(evadingResult.EvadingStars, 3)
		Assert.equal(state.Stars, 2)
	end,
	["heat above a threshold keeps the star until it drops below"] = function()
		local state = withHeat(C.StarThresholds[3] + C.DecayRate)
		run(state, 0, C.DecayDelay + 0.5)
		Assert.equal(state.Stars, 3)
		run(state, C.DecayDelay + 0.5, 1)
		Assert.equal(state.Stars, 2)
	end,
	["reset clears everything with no escape reward"] = function()
		local state = withHeat(C.StarThresholds[3])
		WantedRules.applyCrime(state, "RammingPolice", 0, C)
		WantedRules.reset(state)
		Assert.equal(state.Heat, 0)
		Assert.equal(state.Stars, 0)
		Assert.equal(state.PeakStars, 0)
		local _, last, escaped = run(state, 0, 30)
		Assert.equal(escaped, nil)
		Assert.equal(last.Reputation, 0)
		-- Cooldowns are cleared too.
		Assert.equal((WantedRules.applyCrime(state, "RammingPolice", 0.1, C)), true)
	end,
}
