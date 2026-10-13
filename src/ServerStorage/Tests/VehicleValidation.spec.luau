-- Vehicle movement validation rules (pure). Traces are generated from the real handling maths
-- so "normal driving" here is the same physics model player cars use.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Validation = ServerScriptService.Server.Validation
local Rules = require(Validation.VehicleValidationRules)
local Config = require(Validation.VehicleValidationConfig)
local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)
local VehicleMath = require(ReplicatedStorage.Shared.Vehicle.VehicleMath)
local Assert = require(script.Parent.Assert)

local coupe = assert(VehicleConfig.get("Coupe"))
local LIMITS = Rules.limitsFor(coupe, Config)
local DT = Config.SampleInterval

-- Feeds samples and returns (observation kinds list, alert count).
local function feed(state, samples)
	local kinds, alerts = {}, 0
	for _, sample in samples do
		local result = Rules.observe(state, sample, LIMITS, Config)
		for _, o in result.Observations do
			table.insert(kinds, o.Kind)
		end
		if result.Alert then
			alerts += 1
		end
	end
	return kinds, alerts
end

local function sample(t, x, vx, ownerOk)
	return { Time = t, Position = Vector3.new(x, 2, 0), Velocity = Vector3.new(vx, 0, 0), OwnerOk = ownerOk ~= false }
end

-- A realistic 60 s drive: full throttle to top speed, brake, reverse, handbrake drift, repeat.
local function normalDrive()
	local samples, x, speed, t = {}, 0, 0, 0
	local phases = { { 1, 0, false, 12 }, { -1, 0, false, 4 }, { -1, 0, false, 3 }, { 1, 1, true, 3 }, { 1, 0, false, 8 }, { 0, 0, false, 10 } }
	local step = 1 / 60
	local nextSample = 0
	for _ = 1, 3 do
		for _, phase in phases do
			local input = VehicleMath.clampInput(phase[1], phase[2], phase[3])
			for _ = 1, math.floor(phase[4] / step) do
				speed = VehicleMath.stepForwardSpeed(speed, input, coupe, step)
				x += speed * step
				t += step
				if t >= nextSample then
					table.insert(samples, sample(t, x, speed))
					nextSample = t + DT
				end
			end
		end
	end
	return samples
end

return {
	["limits come from each vehicle's own stats"] = function()
		local police = assert(VehicleConfig.get("Police"))
		Assert.near(LIMITS.MaxSpeed, coupe.MaxForwardSpeed * Config.SpeedFactor + Config.SpeedSlack, 1e-9)
		Assert.truthy(Rules.limitsFor(police, Config).MaxSpeed > LIMITS.MaxSpeed, "faster car, higher limit")
		Assert.equal(Config.Mode, "Monitor")
	end,
	["three minutes of normal driving, braking, reversing and drifting: zero observations"] = function()
		local state = Rules.new(0, 0)
		local kinds, alerts = feed(state, normalDrive())
		Assert.equal(#kinds, 0, `false positives: {table.concat(kinds, ",")}`)
		Assert.equal(alerts, 0)
	end,
	["a single collision spike or impulse is tolerated"] = function()
		local state = Rules.new(0, 0)
		local samples = {}
		local x = 0
		for i = 1, 20 do
			local v = if i == 10 then 260 else 80 -- one sample of a violent impulse
			x += v * DT
			table.insert(samples, sample(i * DT, x, v))
		end
		local kinds, alerts = feed(state, samples)
		Assert.equal(alerts, 0)
		for _, k in kinds do
			Assert.truthy(k ~= "SustainedOverspeed", "single spike is not sustained")
		end
	end,
	["falling fast is not speeding (horizontal only)"] = function()
		local state = Rules.new(0, 0)
		local samples = {}
		for i = 1, 20 do
			table.insert(samples, { Time = i * DT, Position = Vector3.new(0, 500 - i * 60, 0), Velocity = Vector3.new(0, -300, 0), OwnerOk = true })
		end
		local kinds = feed(state, samples)
		Assert.equal(#kinds, 0)
	end,
	["sustained speed beyond the limit is detected and alerts"] = function()
		local state = Rules.new(0, 0)
		local samples, x = {}, 0
		local v = LIMITS.MaxSpeed + 40
		for i = 1, 10 do
			x += v * DT
			table.insert(samples, sample(i * DT, x, v))
		end
		local kinds, alerts = feed(state, samples)
		Assert.truthy(table.find(kinds, "SustainedOverspeed"), "overspeed observed")
		Assert.truthy(alerts >= 1, "alert raised")
	end,
	["a large teleport is detected and alerts at once"] = function()
		local state = Rules.new(0, 0)
		local kinds, alerts = feed(state, { sample(0.2, 0, 0), sample(0.4, 300, 0) })
		Assert.equal(kinds[1], "Teleport")
		Assert.equal(alerts, 1)
	end,
	["a small jump is noted once, and alerts only when repeated"] = function()
		local state = Rules.new(0, 0)
		-- 90 studs in 0.2 s: above the ~62-stud allowance, below the 150-stud "extreme" jump.
		local kinds, alerts = feed(state, { sample(0.2, 0, 0), sample(0.4, 90, 0) })
		Assert.equal(#kinds, 1)
		Assert.equal(alerts, 0)
		local kinds2, alerts2 = feed(state, { sample(0.6, 90, 0), sample(0.8, 180, 0) })
		Assert.equal(#kinds2, 1)
		Assert.equal(alerts2, 1)
	end,
	["isolated small jumps far apart never alert"] = function()
		local state = Rules.new(0, 0)
		local alerts = 0
		local x, t = 0, 0
		for _ = 1, 5 do
			t += DT
			local _, a = feed(state, { sample(t, x, 0) })
			x += 90
			t += DT
			local _, b = feed(state, { sample(t, x, 0) })
			alerts += a + b
			t += Config.Window + 1 -- next jump outside the scoring window
			feed(state, { sample(t, x, 0) })
		end
		Assert.equal(alerts, 0)
	end,
	["authorized repositions are not judged"] = function()
		local state = Rules.new(0, 0)
		feed(state, { sample(0.2, 0, 0) })
		Rules.grant(state, 0.3, 1)
		local kinds = feed(state, { sample(0.4, 500, 0), sample(0.6, 500, 0), sample(1.4, 505, 0), sample(1.6, 510, 0) })
		Assert.equal(#kinds, 0)
	end,
	["new vehicles get a spawn grace period"] = function()
		local state = Rules.new(10, Config.SpawnGraceSeconds)
		local kinds = feed(state, { sample(10.2, 0, 0), sample(10.4, 400, 0), sample(11.2, 400, 0), sample(11.4, 402, 0) })
		Assert.equal(#kinds, 0)
	end,
	["non-finite values are rejected and keep the last good baseline"] = function()
		local state = Rules.new(0, 0)
		feed(state, { sample(0.2, 0, 0) })
		local kinds, alerts = feed(state, {
			{ Time = 0.4, Position = Vector3.new(0 / 0, 0, 0), Velocity = Vector3.zero, OwnerOk = true },
		})
		Assert.equal(kinds[1], "InvalidState")
		Assert.equal(alerts, 1)
		Assert.equal(state.Last.Position.X, 0, "baseline kept")
		Assert.equal(Rules.isFiniteVector(Vector3.new(math.huge, 0, 0)), false)
		Assert.equal(Rules.isFiniteVector("nope"), false)
	end,
	["ownership mismatch only counts when it persists"] = function()
		local state = Rules.new(0, 0)
		local brief = feed(state, { sample(0.2, 0, 0, true), sample(0.4, 0, 0, false), sample(0.6, 0, 0, true) })
		Assert.equal(#brief, 0, "brief handover tolerated")
		local samples = {}
		for i = 4, 15 do
			table.insert(samples, sample(i * DT, 0, 0, false))
		end
		local kinds = feed(state, samples)
		Assert.truthy(table.find(kinds, "OwnershipMismatch"), "persistent mismatch observed")
	end,
}
