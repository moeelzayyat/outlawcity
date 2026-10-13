--!strict
-- Per-key cooldown gate. The server uses one per remote to throttle client requests.
local RateLimiter = {}
RateLimiter.__index = RateLimiter

type RateLimiterData = {
	_cooldown: number,
	_last: { [any]: number },
	_clock: () -> number,
}
export type RateLimiter = typeof(setmetatable({} :: RateLimiterData, RateLimiter))

function RateLimiter.new(cooldownSeconds: number, clock: (() -> number)?): RateLimiter
	return setmetatable({
		_cooldown = cooldownSeconds,
		_last = {},
		_clock = clock or os.clock,
	}, RateLimiter)
end

-- Returns (allowed, secondsRemaining). Only an allowed call starts a new cooldown.
function RateLimiter.tryConsume(self: RateLimiter, key: any): (boolean, number)
	local now = self._clock()
	local last = self._last[key]
	if last and now - last < self._cooldown then
		return false, self._cooldown - (now - last)
	end
	self._last[key] = now
	return true, 0
end

function RateLimiter.reset(self: RateLimiter, key: any)
	self._last[key] = nil
end

return RateLimiter
