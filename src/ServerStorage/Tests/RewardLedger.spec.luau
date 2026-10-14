-- Durable reward ledger (audit remediation): earned rewards survive failed profile saves,
-- disconnects and server crashes, are paid exactly once (also after 200+ later transactions),
-- and invalid states (BalanceCap, malformed data, a full ledger) are handled explicitly.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local HttpService = game:GetService("HttpService")
local RewardLedger = require(ServerScriptService.Server.Data.RewardLedger)
local ProfileStore = require(ServerScriptService.Server.Data.ProfileStore)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local EconomyRules = require(ReplicatedStorage.Shared.Economy.EconomyRules)
local Assert = require(script.Parent.Assert)

local C = EconomyConfig

local function deepCopy(value)
	if value == nil then
		return nil
	end
	return HttpService:JSONDecode(HttpService:JSONEncode(value))
end

local function fakeStore()
	local data = {}
	local store = { Fail = false, Data = data }
	function store.UpdateAsync(self, key, transform)
		if self.Fail then
			error("simulated outage")
		end
		local result = transform(deepCopy(data[key]))
		if result ~= nil then
			data[key] = deepCopy(result)
		end
		return deepCopy(result)
	end
	return store
end

local function reward(tx: string, amount: number?)
	return { TxId = tx, Amount = amount or 2000, Reason = "store robbery", At = 1 }
end

-- What EconomyService.claimRewards does: pay what the ledger holds, prune PaidRewards the
-- ledger no longer lists, then settle/block entries in the ledger.
local function claim(profiles, rewards, profile, sessionId, now)
	local list = RewardLedger.list(rewards, "r")
	if not list then
		return false, nil
	end
	local inLedger = {}
	for _, r in list do
		table.insert(inLedger, r.TxId)
	end
	local result = { Settled = {}, Blocked = {}, Retry = {} }
	local ok = ProfileStore.commit(profiles, "k", sessionId, profile, now, function(draft)
		EconomyRules.prunePaidRewards(draft, inLedger)
		result = RewardLedger.applyAll(draft, list, C)
		return true, nil
	end)
	if ok then
		RewardLedger.update(rewards, "r", result)
	end
	return ok, result
end

local function pay(profiles, profile, tx, amount, now)
	return ProfileStore.commit(profiles, "k", "A", profile, now, function(draft)
		return EconomyRules.payReward(draft, amount, tx, C)
	end)
end

return {
	["recording is idempotent per transaction id"] = function()
		local rewards = fakeStore()
		Assert.equal((RewardLedger.record(rewards, "r", reward("robbery:1"))), true)
		Assert.equal((RewardLedger.record(rewards, "r", reward("robbery:1"))), true)
		Assert.equal(#assert(RewardLedger.list(rewards, "r")), 1)
	end,
	["profile write fails after escape: the reward is paid once on the next load (any server)"] = function()
		local profiles, rewards = fakeStore(), fakeStore()
		local a = ProfileStore.load(profiles, "k", "A", 1000, C)
		local startCash = a.Cash
		assert(RewardLedger.record(rewards, "r", reward("robbery:1")))
		profiles.Fail = true
		Assert.equal((pay(profiles, a, "robbery:1", 2000, 1001)), false)
		profiles.Fail = false
		local b = ProfileStore.load(profiles, "k", "B", 1001 + C.SessionLockTimeout + 1, C)
		Assert.equal((claim(profiles, rewards, b, "B", 1300)), true)
		Assert.equal(b.Cash, startCash + 2000)
		Assert.equal(#assert(RewardLedger.list(rewards, "r")), 0, "ledger cleared")
		Assert.equal((claim(profiles, rewards, b, "B", 1301)), true)
		Assert.equal(b.Cash, startCash + 2000, "a second claim pays nothing")
	end,
	["dedupe beyond 200 transactions: a paid reward left in the ledger never pays again"] = function()
		local profiles, rewards = fakeStore(), fakeStore()
		local a = ProfileStore.load(profiles, "k", "A", 1000, C)
		assert(RewardLedger.record(rewards, "r", reward("robbery:old")))
		assert(pay(profiles, a, "robbery:old", 2000, 1001))
		-- the ledger removal failed, so the entry is still there; then lots of other activity
		for i = 1, C.RecentTransactionLimit + 50 do
			assert(ProfileStore.commit(profiles, "k", "A", a, 1002 + i, function(draft)
				return EconomyRules.grant(draft, 1, "g" .. i, C)
			end))
		end
		Assert.equal(EconomyRules.hasTransaction(a, "robbery:old"), false, "aged out of the recent ids")
		local cash = a.Cash
		Assert.equal((claim(profiles, rewards, a, "A", 2000)), true)
		Assert.equal(a.Cash, cash, "not paid again (PaidRewards)")
		Assert.equal(#assert(RewardLedger.list(rewards, "r")), 0, "settled and cleared")
		-- next claim prunes the paid id now that the ledger no longer lists it
		Assert.equal((claim(profiles, rewards, a, "A", 2001)), true)
		Assert.equal(table.find(a.PaidRewards, "robbery:old"), nil, "pruned")
		Assert.equal(table.find(profiles.Data.k.Profile.PaidRewards, "robbery:old"), nil)
	end,
	["claim during a profile outage pays nothing and keeps the ledger entry"] = function()
		local profiles, rewards = fakeStore(), fakeStore()
		local a = ProfileStore.load(profiles, "k", "A", 1000, C)
		local cash = a.Cash
		assert(RewardLedger.record(rewards, "r", reward("robbery:1")))
		profiles.Fail = true
		Assert.equal((claim(profiles, rewards, a, "A", 1001)), false)
		Assert.equal(a.Cash, cash)
		Assert.equal(#assert(RewardLedger.list(rewards, "r")), 1, "still recorded for the next try")
	end,
	["recovery: an unreadable ledger is retried and pays once it can be read"] = function()
		local profiles, rewards = fakeStore(), fakeStore()
		local a = ProfileStore.load(profiles, "k", "A", 1000, C)
		local cash = a.Cash
		assert(RewardLedger.record(rewards, "r", reward("robbery:1", 500)))
		rewards.Fail = true
		local list, err = RewardLedger.list(rewards, "r")
		Assert.equal(list, nil)
		Assert.truthy(err ~= nil, "unreadable is reported")
		Assert.equal((claim(profiles, rewards, a, "A", 1001)), false)
		rewards.Fail = false
		Assert.equal((claim(profiles, rewards, a, "A", 1031)), true)
		Assert.equal(a.Cash, cash + 500)
	end,
	["BalanceCap: the reward is kept as Blocked (not dropped, not paid) and paid once it fits"] = function()
		local profiles, rewards = fakeStore(), fakeStore()
		local a = ProfileStore.load(profiles, "k", "A", 1000, C)
		assert(ProfileStore.commit(profiles, "k", "A", a, 1000, function(draft)
			draft.Cash = C.MaxBalance - 100
			return true, nil
		end))
		assert(RewardLedger.record(rewards, "r", reward("robbery:big", 2000)))
		local ok, result = claim(profiles, rewards, a, "A", 1001)
		Assert.equal(ok, true)
		Assert.equal(result.Blocked["robbery:big"], "BalanceCap")
		Assert.equal(a.Cash, C.MaxBalance - 100)
		local entry = assert(RewardLedger.list(rewards, "r"))[1]
		Assert.equal(entry.State, "Blocked")
		Assert.equal(entry.Note, "BalanceCap")
		-- the player spends; the next claim pays it
		assert(ProfileStore.commit(profiles, "k", "A", a, 1002, function(draft)
			return EconomyRules.deduct(draft, 5000, "spend", C)
		end))
		Assert.equal((claim(profiles, rewards, a, "A", 1003)), true)
		Assert.equal(a.Cash, C.MaxBalance - 100 - 5000 + 2000)
		Assert.equal(#assert(RewardLedger.list(rewards, "r")), 0)
	end,
	["a full ledger refuses new rewards explicitly"] = function()
		local rewards = fakeStore()
		for i = 1, 3 do
			assert(RewardLedger.record(rewards, "r", reward("r" .. i), 3))
		end
		local ok, err = RewardLedger.record(rewards, "r", reward("r4"), 3)
		Assert.equal(ok, false)
		Assert.equal(err, "LedgerFull")
		Assert.equal(#assert(RewardLedger.list(rewards, "r")), 3, "nothing dropped")
	end,
	["a corrupt ledger record is never overwritten; malformed entries are kept"] = function()
		local rewards = fakeStore()
		rewards.Data.r = "garbage"
		local ok, err = RewardLedger.record(rewards, "r", reward("robbery:1"))
		Assert.equal(ok, false)
		Assert.equal(err, "LedgerCorrupt")
		Assert.equal(rewards.Data.r, "garbage", "untouched")
		local list, listErr = RewardLedger.list(rewards, "r")
		Assert.equal(list, nil)
		Assert.equal(listErr, "LedgerCorrupt")
		-- a record with one malformed entry: the entry survives every rewrite
		rewards.Data.r2 = { Rewards = { { TxId = 5 }, reward("robbery:2") } }
		local valid, _, malformed = RewardLedger.list(rewards, "r2")
		Assert.equal(#assert(valid), 1)
		Assert.equal(malformed, 1)
		assert(RewardLedger.remove(rewards, "r2", { "robbery:2" }))
		Assert.equal(#rewards.Data.r2.Rewards, 1)
		Assert.equal(rewards.Data.r2.Rewards[1].TxId, 5, "malformed entry kept as found")
	end,
	["invalid rewards are refused before they reach the ledger"] = function()
		local rewards = fakeStore()
		local bad = {
			{ TxId = "", Amount = 10, Reason = "x", At = 1 },
			{ TxId = string.rep("a", C.TransactionIdMaxLength + 1), Amount = 10, Reason = "x", At = 1 },
			{ TxId = 5, Amount = 10, Reason = "x", At = 1 },
			{ TxId = "t", Amount = 0, Reason = "x", At = 1 },
			{ TxId = "t", Amount = -5, Reason = "x", At = 1 },
			{ TxId = "t", Amount = 1.5, Reason = "x", At = 1 },
			{ TxId = "t", Amount = 0 / 0, Reason = "x", At = 1 },
			{ TxId = "t", Amount = C.MaxTransaction + 1, Reason = "x", At = 1 },
			{ TxId = "t", Amount = 10, Reason = string.rep("r", 101), At = 1 },
			{ TxId = "t", Amount = 10, Reason = "x", At = 0 / 0 },
			{ TxId = "t", Amount = 10, Reason = "x", At = math.huge },
			{ TxId = "t", Amount = 10, Reason = "x", At = -math.huge },
		}
		for i, r in bad do
			local ok, err = RewardLedger.record(rewards, "r", r :: any)
			Assert.equal(ok, false, `bad reward {i} accepted`)
			Assert.truthy(type(err) == "string" and err:find("InvalidReward", 1, true) ~= nil, `bad reward {i}: {tostring(err)}`)
		end
		Assert.equal(rewards.Data.r, nil, "nothing was written")
	end,
	["several recorded rewards are paid together and each once"] = function()
		local profiles, rewards = fakeStore(), fakeStore()
		local a = ProfileStore.load(profiles, "k", "A", 1000, C)
		local cash = a.Cash
		assert(RewardLedger.record(rewards, "r", reward("robbery:1", 2000)))
		assert(RewardLedger.record(rewards, "r", reward("robbery:2", 2000)))
		Assert.equal((claim(profiles, rewards, a, "A", 1001)), true)
		Assert.equal(a.Cash, cash + 4000)
	end,
}
