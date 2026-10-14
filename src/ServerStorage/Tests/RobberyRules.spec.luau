-- Store robbery rules (pure state machine) and the store layout.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local RobberyRules = require(ReplicatedStorage.Shared.Robbery.RobberyRules)
local RobberyConfig = require(ReplicatedStorage.Shared.Config.RobberyConfig)
local WantedConfig = require(ReplicatedStorage.Shared.Config.WantedConfig)
local WantedRules = require(ReplicatedStorage.Shared.Wanted.WantedRules)
local JailRules = require(ReplicatedStorage.Shared.Jail.JailRules)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local CityLayout = require(ServerScriptService.Server.World.CityLayout)
local Assert = require(script.Parent.Assert)

local C = RobberyConfig
local function facts(overrides: { [string]: any }?)
	local f = { Alive = true, Jailed = false, InSafeZone = false, InVehicle = false, DistanceToRegister = 3, HasActiveSession = false, CashReady = true }
	for k, v in overrides or {} do
		f[k] = v
	end
	return f
end
local OK_TICK = { Connected = true, Alive = true, Jailed = false, InArea = true }
local function tickFacts(overrides: { [string]: any })
	local f = table.clone(OK_TICK)
	for k, v in overrides do
		f[k] = v
	end
	return f
end
local function started(t: number?)
	local store = RobberyRules.newStore()
	local session = RobberyRules.start(store, "id-1", 1, "Store1", t or 100, C)
	return store, session
end

return {
	["default values match the approved design"] = function()
		Assert.equal(C.HoldSeconds, 15)
		Assert.equal(C.Reward, 2000)
		Assert.equal(C.CooldownSeconds, 180)
		local crime = WantedConfig.Crimes[C.WantedCrime]
		Assert.equal(WantedRules.starsForHeat(crime.Heat, WantedConfig), 2, "the robbery alarm gives 2 stars")
		Assert.equal(WantedConfig.Crimes[C.InProgressCrime].Heat, 0)
	end,
	["eligible players can start; each blocker gives its own reason"] = function()
		local store = RobberyRules.newStore()
		Assert.equal((RobberyRules.canStart(store, facts(), 0, C)), true)
		local cases = {
			{ { Alive = false }, "Dead" },
			{ { Jailed = true }, "Jailed" },
			{ { InSafeZone = true }, "InSafeZone" },
			{ { InVehicle = true }, "InVehicle" },
			{ { HasActiveSession = true }, "AlreadyRobbing" },
			{ { CashReady = false }, "CashUnavailable" },
			{ { DistanceToRegister = C.PromptDistance + C.DistanceSlack + 0.1 }, "TooFar" },
			{ { DistanceToRegister = 0 / 0 }, "TooFar" },
			{ { DistanceToRegister = math.huge }, "TooFar" },
		}
		for _, case in cases do
			local ok, err = RobberyRules.canStart(store, facts(case[1]), 0, C)
			Assert.equal(ok, false)
			Assert.equal(err, case[2])
		end
	end,
	["a store can't be robbed twice at once or during its cooldown"] = function()
		local store, session = started(100)
		local ok, err = RobberyRules.canStart(store, facts(), 101, C)
		Assert.equal(ok, false)
		Assert.equal(err, "StoreBusy")
		RobberyRules.tick(session, store, tickFacts({ InArea = false }), 102, C)
		ok, err = RobberyRules.canStart(store, facts(), 102, C)
		Assert.equal(err, "StoreCooldown", "a failed robbery still cools the store down")
		Assert.equal((RobberyRules.canStart(store, facts(), 100 + C.CooldownSeconds - 0.01, C)), false)
		Assert.equal((RobberyRules.canStart(store, facts(), 100 + C.CooldownSeconds, C)), true)
	end,
	["holdout completes only after the full server time"] = function()
		local store, session = started(100)
		Assert.equal((RobberyRules.tick(session, store, OK_TICK, 100 + C.HoldSeconds - 0.01, C)), nil)
		Assert.equal(session.Phase, "Holding")
		Assert.equal((RobberyRules.onEscaped(session)), false, "escaping while still holding pays nothing")
		Assert.equal((RobberyRules.tick(session, store, OK_TICK, 100 + C.HoldSeconds, C)), "HoldComplete")
		Assert.equal(session.Phase, "Escaping")
		Assert.equal(store.ActiveSession, nil, "the store frees up once the holdout ends")
	end,
	["death, bust, leaving and disconnecting fail the holdout"] = function()
		for _, case in { { { Alive = false }, "Died" }, { { Jailed = true }, "Busted" }, { { InArea = false }, "LeftArea" }, { { Connected = false }, "Disconnected" } } do
			local store, session = started(100)
			local event, reason = RobberyRules.tick(session, store, tickFacts(case[1]), 105, C)
			Assert.equal(event, "Failed")
			Assert.equal(reason, case[2])
			Assert.equal(store.ActiveSession, nil)
			Assert.equal((RobberyRules.onEscaped(session)), false, "a failed robbery never pays")
		end
	end,
	["while escaping, bust, death, disconnect and timeout fail; leaving the store is fine"] = function()
		for _, case in { { { Jailed = true }, "Busted" }, { { Alive = false }, "Died" }, { { Connected = false }, "Disconnected" } } do
			local store, session = started(100)
			RobberyRules.tick(session, store, OK_TICK, 115, C)
			local event, reason = RobberyRules.tick(session, store, tickFacts(case[1]), 120, C)
			Assert.equal(event, "Failed")
			Assert.equal(reason, case[2])
			Assert.equal((RobberyRules.onEscaped(session)), false)
		end
		local store, session = started(100)
		RobberyRules.tick(session, store, OK_TICK, 115, C)
		Assert.equal((RobberyRules.tick(session, store, tickFacts({ InArea = false }), 120, C)), nil)
		local event, reason = RobberyRules.tick(session, store, tickFacts({ InArea = false }), 115 + C.MaxEscapeSeconds + 0.1, C)
		Assert.equal(event, "Failed")
		Assert.equal(reason, "EscapeTimedOut")
	end,
	["an escape pays exactly once"] = function()
		local store, session = started(100)
		RobberyRules.tick(session, store, OK_TICK, 115, C)
		Assert.equal((RobberyRules.onEscaped(session)), true)
		Assert.equal(session.Phase, "Paid")
		Assert.equal((RobberyRules.onEscaped(session)), false)
		Assert.equal((RobberyRules.onEscaped(session)), false)
		Assert.equal((RobberyRules.tick(session, store, tickFacts({ Alive = false }), 130, C)), nil, "settled sessions don't change")
		Assert.equal(RobberyRules.isLive(session), false)
	end,
	["payout results: paid, already paid, retry only for temporary data loss"] = function()
		Assert.equal(RobberyRules.payoutOutcome(true, nil), "Paid")
		Assert.equal(RobberyRules.payoutOutcome(false, "DuplicateTransaction"), "AlreadyPaid")
		Assert.equal(RobberyRules.payoutOutcome(false, "DataNotLoaded"), "Retry")
		Assert.equal(RobberyRules.payoutOutcome(false, "SaveFailed"), "Retry")
		Assert.equal(RobberyRules.payoutOutcome(false, "NotInGame"), "Rejected")
		Assert.equal(RobberyRules.payoutOutcome(false, "InvalidAmount"), "Rejected")
	end,
	["jail blocks robbery and the notice remote is server-to-client only"] = function()
		local jail = JailRules.new()
		JailRules.sentence(jail, 0, 12, true)
		Assert.equal(JailRules.allows(jail, "Robbery"), false)
		Assert.equal(Remotes.Definitions.OnRobberyNotice, "RemoteEvent")
		for name in Remotes.Definitions do
			Assert.equal(name:find("Robbery", 1, true) == nil or name:sub(1, 2) == "On", true, `{name}: no client robbery requests`)
		end
	end,
	["the store sits inside the city, clear of the roads"] = function()
		local spec = CityLayout.store()
		local c, size = spec.Area.Center, spec.Area.Size
		Assert.equal(spec.Id, CityLayout.STORE_ID)
		local half = CityLayout.ROAD_WIDTH / 2
		for _, roadX in CityLayout.GRID_LINES do
			Assert.equal(math.abs(c.X - roadX) >= size.X / 2 + half, true, `store overlaps road x={roadX}`)
		end
		for _, roadZ in CityLayout.GRID_LINES do
			Assert.equal(math.abs(c.Z - roadZ) >= size.Z / 2 + half, true, `store overlaps road z={roadZ}`)
		end
		local register = spec.Register.Position
		Assert.equal(math.abs(register.X - c.X) < size.X / 2 and math.abs(register.Z - c.Z) < size.Z / 2, true, "register inside the holdout area")
	end,
}
