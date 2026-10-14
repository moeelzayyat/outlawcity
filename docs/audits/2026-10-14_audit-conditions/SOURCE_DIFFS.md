# Source diffs: 2026-10-14_audit-conditions

Commit range `1057d17..d442381`. The `src/` snapshot is byte-identical to the Outlaw City place (the 4 changed files were checked by hash).

## `src/ServerScriptService/Server/Data/ProfileSession.luau`

```diff
diff --git a/src/ServerScriptService/Server/Data/ProfileSession.luau b/src/ServerScriptService/Server/Data/ProfileSession.luau
index d3f0123..6f9b006 100644
--- a/src/ServerScriptService/Server/Data/ProfileSession.luau
+++ b/src/ServerScriptService/Server/Data/ProfileSession.luau
@@ -1,6 +1,9 @@
 --!strict
 -- One player's profile on this server, and the ONLY way it is written (audit remediation).
---  * Operations (commits and saves) run one at a time, in order (`run`).
+--  * Operations (commits and saves) run one at a time, strictly in arrival order (`run` hands
+--    out tickets: first come, first served).
+--  * Once the player is leaving, only the final release-save may still run: queued commits and
+--    heartbeat saves are refused, so nothing can interleave with or follow the release.
 --  * Once a session is closed (the player left, this server lost the lock, or another server
 --    took ownership), every operation still queued or started later is refused with
 --    "SessionClosed" and writes nothing.
@@ -31,7 +34,8 @@ export type Session = {
 	Closed: boolean,
 	CloseReason: string?,
 	Busy: boolean,
-	Queue: number, -- operations waiting for their turn
+	NextTicket: number, -- FIFO queue: the ticket the next operation gets...
+	Serving: number, -- ...and the ticket whose turn it is
 	Wait: (number) -> (),
 	Now: () -> number,
 	Log: (string) -> (),
@@ -50,7 +54,8 @@ function ProfileSession.new(store: any, key: string, sessionId: string, profile:
 		Closed = false,
 		CloseReason = nil,
 		Busy = false,
-		Queue = 0,
+		NextTicket = 1,
+		Serving = 1,
 		Wait = opts.Wait or function(seconds: number)
 			task.wait(seconds)
 		end,
@@ -73,23 +78,26 @@ function ProfileSession.close(session: Session, reason: string)
 	end
 end
 
--- Runs fn with the profile to itself, in arrival order. Refuses if the session is (or becomes)
--- closed before fn's turn comes.
+-- Runs fn with the profile to itself, strictly in arrival order (FIFO tickets). Refuses if the
+-- session is (or becomes) closed before fn's turn comes; a refused ticket still passes the
+-- turn on, so the queue never stalls.
 function ProfileSession.run<T...>(session: Session, fn: () -> T...): (boolean, ...any)
 	if session.Closed then
 		return false, "SessionClosed"
 	end
-	session.Queue += 1
-	while session.Busy do
+	local ticket = session.NextTicket
+	session.NextTicket += 1
+	while session.Serving ~= ticket do
 		task.wait()
 	end
-	session.Queue -= 1
 	if session.Closed then
+		session.Serving += 1
 		return false, "SessionClosed"
 	end
 	session.Busy = true
 	local results = table.pack(pcall(fn))
 	session.Busy = false
+	session.Serving += 1
 	if not results[1] then
 		error(results[2], 0)
 	end
@@ -201,6 +209,9 @@ end
 -- written. release=true drops the lock and closes the session. Returns (ok, err).
 function ProfileSession.save(session: Session, release: boolean): (boolean, string?)
 	local ran, ok, err = ProfileSession.run(session, function(): (boolean, string?)
+		if session.Leaving and not release then
+			return false, "SessionClosed" -- only the final release-save may run once leaving
+		end
 		if session.Stale then
 			local reconciled, recErr = reconcile(session)
 			if not reconciled then
```

## `src/ServerScriptService/Server/Data/RewardLedger.luau`

```diff
diff --git a/src/ServerScriptService/Server/Data/RewardLedger.luau b/src/ServerScriptService/Server/Data/RewardLedger.luau
index cf94f80..309a59d 100644
--- a/src/ServerScriptService/Server/Data/RewardLedger.luau
+++ b/src/ServerScriptService/Server/Data/RewardLedger.luau
@@ -18,6 +18,7 @@
 local ReplicatedStorage = game:GetService("ReplicatedStorage")
 local Types = require(ReplicatedStorage.Shared.Types)
 local EconomyRules = require(ReplicatedStorage.Shared.Economy.EconomyRules)
+local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
 
 local RewardLedger = {}
 
@@ -69,9 +70,39 @@ local function build(valid: { Reward }, malformed: { any }): any
 	return { Rewards = list }
 end
 
+local MAX_REASON = 100
+
+-- Checks a reward before it may enter the ledger (audit condition 4): a valid transaction id
+-- and amount by the same rules the profile uses, a short reason and a numeric time. Returns
+-- (ok, problem?).
+function RewardLedger.validate(reward: any): (boolean, string?)
+	if type(reward) ~= "table" then
+		return false, "not a table"
+	end
+	local okTx, txErr = EconomyRules.validateTransactionId(reward.TxId, EconomyConfig)
+	if not okTx then
+		return false, txErr
+	end
+	local okAmount, amountErr = EconomyRules.validateAmount(reward.Amount, EconomyConfig)
+	if not okAmount then
+		return false, amountErr
+	end
+	if type(reward.Reason) ~= "string" or #reward.Reason > MAX_REASON then
+		return false, "InvalidReason"
+	end
+	if type(reward.At) ~= "number" or reward.At ~= reward.At then
+		return false, "InvalidTime"
+	end
+	return true, nil
+end
+
 -- Adds a reward (no-op if its TxId is already recorded). Returns (ok, err?):
--- err is "LedgerFull", "LedgerCorrupt" or a store error.
+-- err is "InvalidReward: <why>" (nothing written), "LedgerFull", "LedgerCorrupt" or a store error.
 function RewardLedger.record(store: Store, key: string, reward: Reward, maxEntries: number?): (boolean, string?)
+	local valid, why = RewardLedger.validate(reward)
+	if not valid then
+		return false, `InvalidReward: {why}`
+	end
 	local limit = maxEntries or DEFAULT_MAX
 	local refusal: string? = nil
 	local ok, err = pcall(function()
```

## `src/ServerStorage/Tests/ProfileSession.spec.luau`

```diff
diff --git a/src/ServerStorage/Tests/ProfileSession.spec.luau b/src/ServerStorage/Tests/ProfileSession.spec.luau
index 52e6ce6..1d31862 100644
--- a/src/ServerStorage/Tests/ProfileSession.spec.luau
+++ b/src/ServerStorage/Tests/ProfileSession.spec.luau
@@ -8,6 +8,7 @@ local ProfileSession = require(ServerScriptService.Server.Data.ProfileSession)
 local ProfileStore = require(ServerScriptService.Server.Data.ProfileStore)
 local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
 local EconomyRules = require(ReplicatedStorage.Shared.Economy.EconomyRules)
+local RewardLedger = require(ServerScriptService.Server.Data.RewardLedger)
 local Assert = require(script.Parent.Assert)
 
 local C = EconomyConfig
@@ -20,14 +21,18 @@ local function deepCopy(value)
 end
 
 -- Fail: every call errors. CommitThenError = n: the next n writes are stored, then error.
--- Yield = seconds: each call waits (lets other operations queue up).
+-- Yield = seconds: each call waits (lets other operations queue up). Hold = true: calls wait
+-- until the test sets it back to false (deterministic overlap, independent of frame timing).
 local function fakeStore()
 	local data = {}
-	local store = { Fail = false, CommitThenError = 0, Yield = 0, Writes = 0, Data = data }
+	local store = { Fail = false, CommitThenError = 0, Yield = 0, Hold = false, Writes = 0, Data = data }
 	function store.UpdateAsync(self, key, transform)
 		if self.Yield > 0 then
 			task.wait(self.Yield)
 		end
+		while self.Hold do
+			task.wait()
+		end
 		if self.Fail then
 			error("simulated outage")
 		end
@@ -200,6 +205,83 @@ return {
 		Assert.equal(store.Data.k.Lock.Id, "B", "B's ownership untouched")
 		Assert.equal(store.Data.k.Profile.Cash, 20000, "nothing written over B")
 	end,
+	["operations run strictly in arrival order (FIFO)"] = function()
+		local store = fakeStore()
+		local s = session(store, 0)
+		store.Yield = 0.02
+		local order = {}
+		local done = 0
+		for i = 1, 6 do
+			task.spawn(function()
+				ProfileSession.commit(s, function(draft)
+					table.insert(order, i)
+					return EconomyRules.grant(draft, 1, "f" .. i, C)
+				end)
+				done += 1
+			end)
+		end
+		local t0 = os.clock()
+		while done < 6 and os.clock() - t0 < 5 do
+			task.wait(0.05)
+		end
+		Assert.equal(table.concat(order, ","), "1,2,3,4,5,6")
+		Assert.equal(store.Data.k.Profile.Cash, 6)
+	end,
+	["once leaving, a queued heartbeat save is refused and only the release-save runs"] = function()
+		local store = fakeStore()
+		local s = session(store, 100)
+		store.Hold = true -- the commit's write stays in flight until released below
+		local results = {}
+		task.spawn(function()
+			results.commit = table.pack(ProfileSession.commit(s, function(draft)
+				return EconomyRules.grant(draft, 1, "c1", C)
+			end))
+		end)
+		task.spawn(function()
+			results.heartbeat = table.pack(ProfileSession.save(s, false)) -- queued behind the commit
+		end)
+		ProfileSession.beginLeave(s) -- the player leaves while both are pending
+		task.spawn(function()
+			results.release = table.pack(ProfileSession.save(s, true))
+		end)
+		store.Hold = false
+		local t0 = os.clock()
+		while (not results.commit or not results.heartbeat or not results.release) and os.clock() - t0 < 3 do
+			task.wait(0.05)
+		end
+		Assert.equal(results.commit[1], true)
+		Assert.equal(results.heartbeat[1], false)
+		Assert.equal(results.heartbeat[2], "SessionClosed")
+		Assert.equal(results.release[1], true)
+		Assert.equal(store.Data.k.Lock, nil, "released by the final save")
+		Assert.equal(s.Closed, true)
+	end,
+	["ambiguous multi-reward claim: every reward paid exactly once"] = function()
+		local store = fakeStore()
+		local s = session(store, 1000)
+		local rewards = {
+			{ TxId = "robbery:1", Amount = 2000, Reason = "r", At = 1 },
+			{ TxId = "robbery:2", Amount = 2000, Reason = "r", At = 1 },
+			{ TxId = "robbery:3", Amount = 500, Reason = "r", At = 1 },
+		}
+		store.CommitThenError = 1 -- the claim's write is stored, then errors
+		local result
+		local ok, err = ProfileSession.commit(s, function(draft)
+			result = RewardLedger.applyAll(draft, rewards, C)
+			return true, nil
+		end)
+		Assert.equal(ok, true, tostring(err))
+		Assert.equal(#result.Settled, 3, "all three settled (already paid on the retry)")
+		Assert.equal(s.Profile.Cash, 1000 + 4500, "paid once, not twice")
+		Assert.equal(store.Data.k.Profile.Cash, 1000 + 4500)
+		Assert.equal(#store.Data.k.Profile.PaidRewards, 3)
+		-- a later claim of the same rewards pays nothing
+		ProfileSession.commit(s, function(draft)
+			result = RewardLedger.applyAll(draft, rewards, C)
+			return true, nil
+		end)
+		Assert.equal(store.Data.k.Profile.Cash, 1000 + 4500)
+	end,
 	["a heartbeat after the lock moved closes the session instead of writing"] = function()
 		local store = fakeStore()
 		local s = session(store, 20000)
```

## `src/ServerStorage/Tests/RewardLedger.spec.luau`

```diff
diff --git a/src/ServerStorage/Tests/RewardLedger.spec.luau b/src/ServerStorage/Tests/RewardLedger.spec.luau
index 169b0ed..765c15d 100644
--- a/src/ServerStorage/Tests/RewardLedger.spec.luau
+++ b/src/ServerStorage/Tests/RewardLedger.spec.luau
@@ -187,6 +187,27 @@ return {
 		Assert.equal(#rewards.Data.r2.Rewards, 1)
 		Assert.equal(rewards.Data.r2.Rewards[1].TxId, 5, "malformed entry kept as found")
 	end,
+	["invalid rewards are refused before they reach the ledger"] = function()
+		local rewards = fakeStore()
+		local bad = {
+			{ TxId = "", Amount = 10, Reason = "x", At = 1 },
+			{ TxId = string.rep("a", C.TransactionIdMaxLength + 1), Amount = 10, Reason = "x", At = 1 },
+			{ TxId = 5, Amount = 10, Reason = "x", At = 1 },
+			{ TxId = "t", Amount = 0, Reason = "x", At = 1 },
+			{ TxId = "t", Amount = -5, Reason = "x", At = 1 },
+			{ TxId = "t", Amount = 1.5, Reason = "x", At = 1 },
+			{ TxId = "t", Amount = 0 / 0, Reason = "x", At = 1 },
+			{ TxId = "t", Amount = C.MaxTransaction + 1, Reason = "x", At = 1 },
+			{ TxId = "t", Amount = 10, Reason = string.rep("r", 101), At = 1 },
+			{ TxId = "t", Amount = 10, Reason = "x", At = 0 / 0 },
+		}
+		for i, r in bad do
+			local ok, err = RewardLedger.record(rewards, "r", r :: any)
+			Assert.equal(ok, false, `bad reward {i} accepted`)
+			Assert.truthy(type(err) == "string" and err:find("InvalidReward", 1, true) ~= nil, `bad reward {i}: {tostring(err)}`)
+		end
+		Assert.equal(rewards.Data.r, nil, "nothing was written")
+	end,
 	["several recorded rewards are paid together and each once"] = function()
 		local profiles, rewards = fakeStore(), fakeStore()
 		local a = ProfileStore.load(profiles, "k", "A", 1000, C)
```
