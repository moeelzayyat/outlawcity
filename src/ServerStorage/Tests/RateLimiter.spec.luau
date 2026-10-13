local ServerScriptService = game:GetService("ServerScriptService")
local RateLimiter = require(ServerScriptService.Server.Util.RateLimiter)
local Assert = require(script.Parent.Assert)

return {
	["blocks within cooldown and allows after"] = function()
		local now = 100
		local limiter = RateLimiter.new(3, function()
			return now
		end)
		Assert.equal((limiter:tryConsume("a")), true)
		local ok, remaining = limiter:tryConsume("a")
		Assert.equal(ok, false)
		Assert.near(remaining, 3, 1e-9)
		now += 3
		Assert.equal((limiter:tryConsume("a")), true)
	end,
	["keys are independent and reset clears"] = function()
		local limiter = RateLimiter.new(10, function()
			return 0
		end)
		Assert.equal((limiter:tryConsume(1)), true)
		Assert.equal((limiter:tryConsume(2)), true)
		Assert.equal((limiter:tryConsume(1)), false)
		limiter:reset(1)
		Assert.equal((limiter:tryConsume(1)), true)
	end,
}
