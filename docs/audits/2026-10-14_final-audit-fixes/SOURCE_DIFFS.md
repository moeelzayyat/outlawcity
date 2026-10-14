# Source diffs: 2026-10-14_final-audit-fixes

Commit range `882e857..9404c20`. The `src/` snapshot is byte-identical to the Outlaw City place 132163592957463 (94/94 scripts). These are all changed modules, including the tests. ProfileSession and its spec are new, so their diff is their full source.

## `src/ReplicatedStorage/Shared/Config/EconomyConfig.luau`

```diff
diff --git a/src/ReplicatedStorage/Shared/Config/EconomyConfig.luau b/src/ReplicatedStorage/Shared/Config/EconomyConfig.luau
index 3d72d1d..b14b504 100644
--- a/src/ReplicatedStorage/Shared/Config/EconomyConfig.luau
+++ b/src/ReplicatedStorage/Shared/Config/EconomyConfig.luau
@@ -8,7 +8,7 @@ local EconomyConfig = {
 	TransactionIdMaxLength = 64,
 	-- 1: cash only (4A). 2: + OwnedVehicles (4C). Older records are migrated on load; a record
 	-- from a NEWER version is refused untouched, so an old server can never downgrade it.
-	ProfileVersion = 2,
+	ProfileVersion = 3, -- 3 (audit remediation): + PaidRewards (durable reward dedupe)
 	StarterVehicles = table.freeze({ "Coupe" }), -- every profile owns these (new and migrated)
 	MaxOwnedVehicles = 50,
 	VehicleIdMaxLength = 32,
@@ -23,7 +23,12 @@ local EconomyConfig = {
 	-- Earned-but-unpaid rewards are recorded here first (separate store), so they survive a
 	-- failed profile save, a disconnect or a server crash. Claimed on the next load.
 	RewardStoreName = "OutlawCity_PendingRewards_v1",
-	CommitAttempts = 2, -- write-through tries per cash change before it is refused as SaveFailed
+	CommitAttempts = 3, -- write-through tries per cash change (each retry reconciles from the store first)
+	MaxPaidRewards = 1000, -- paid-reward ids kept until the ledger drops them
+	LedgerMaxEntries = 50, -- unpaid rewards per player in the ledger; more is refused as LedgerFull
+	ClaimRetryBase = 30, -- seconds; ledger claim retry after a failure, doubling...
+	ClaimRetryMax = 900, -- ...up to this
+	ClaimIdleInterval = 300, -- seconds between ledger checks when nothing is outstanding
 	-- If the save on leave fails, the unsaved profile is kept on this server and retried.
 	OrphanRetryInterval = 10,
 	OrphanRetryLimit = 900, -- seconds; stops early if another server takes the lock
```

## `src/ReplicatedStorage/Shared/Economy/EconomyRules.luau`

```diff
diff --git a/src/ReplicatedStorage/Shared/Economy/EconomyRules.luau b/src/ReplicatedStorage/Shared/Economy/EconomyRules.luau
index 3630038..fe08206 100644
--- a/src/ReplicatedStorage/Shared/Economy/EconomyRules.luau
+++ b/src/ReplicatedStorage/Shared/Economy/EconomyRules.luau
@@ -16,6 +16,7 @@ type Config = {
 	StarterVehicles: { string },
 	MaxOwnedVehicles: number,
 	VehicleIdMaxLength: number,
+	MaxPaidRewards: number,
 }
 
 local function isWholeFinite(n: any): boolean
@@ -43,6 +44,7 @@ function EconomyRules.newProfile(config: Config): Types.Profile
 		Cash = config.StartingCash,
 		RecentTransactions = {},
 		OwnedVehicles = table.clone(config.StarterVehicles),
+		PaidRewards = {},
 	}
 end
 
@@ -87,11 +89,26 @@ function EconomyRules.validateSaved(saved: any, config: Config): (Types.Profile?
 			end
 		end
 	end
+	-- Paid-reward ids (v3+, audit remediation): rewards paid from the ledger that the ledger may
+	-- still list. Kept until the ledger no longer has them, so a reward can never be paid twice
+	-- even after its id has left RecentTransactions.
+	local paid = {}
+	if version >= 3 then
+		if type(saved.PaidRewards) ~= "table" then
+			return nil, "Corrupt" -- a v3 record without its paid-reward list is damaged, not empty
+		end
+		for _, txId in saved.PaidRewards do
+			if type(txId) == "string" and not table.find(paid, txId) then
+				table.insert(paid, txId)
+			end
+		end
+	end
 	return {
 		Version = config.ProfileVersion,
 		Cash = saved.Cash,
 		RecentTransactions = recent,
 		OwnedVehicles = owned,
+		PaidRewards = paid,
 	}, if version < config.ProfileVersion then "Migrated" else "Existing"
 end
 
@@ -183,6 +200,38 @@ function EconomyRules.purchaseVehicle(profile: Types.Profile, vehicleId: any, pr
 	return true, nil
 end
 
+-- Pays a ledger reward once (audit remediation). Refuses a reward already in PaidRewards or in
+-- the recent transaction ids ("DuplicateTransaction"), so it can't pay twice even after the id
+-- has aged out of RecentTransactions. Records the id in PaidRewards in the same step.
+function EconomyRules.payReward(profile: Types.Profile, amount: any, txId: any, config: Config): (boolean, Types.EconomyError?)
+	if type(txId) == "string" and table.find(profile.PaidRewards, txId) then
+		return false, "DuplicateTransaction"
+	end
+	if #profile.PaidRewards >= config.MaxPaidRewards then
+		return false, "RewardHistoryFull"
+	end
+	local ok, err = EconomyRules.grant(profile, amount, txId, config)
+	if not ok then
+		return false, err
+	end
+	table.insert(profile.PaidRewards, txId)
+	return true, nil
+end
+
+-- Drops paid-reward ids the ledger no longer lists (they can never be claimed again).
+-- Returns how many were dropped.
+function EconomyRules.prunePaidRewards(profile: Types.Profile, stillInLedger: { string }): number
+	local kept = {}
+	for _, txId in profile.PaidRewards do
+		if table.find(stillInLedger, txId) then
+			table.insert(kept, txId)
+		end
+	end
+	local dropped = #profile.PaidRewards - #kept
+	profile.PaidRewards = kept
+	return dropped
+end
+
 -- Session lock: a server may claim a record when it is unlocked, already its own, or the
 -- other server's lock is older than `timeout` seconds (that server crashed or hung).
 function EconomyRules.canClaimLock(lock: any, sessionId: string, now: number, timeout: number): boolean
```

## `src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau`

```diff
diff --git a/src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau b/src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau
index 61c6b63..0ea7195 100644
--- a/src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau
+++ b/src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau
@@ -152,7 +152,7 @@ function RobberyRules.payoutOutcome(ok: boolean, err: string?): Types.PayoutOutc
 		return "Paid"
 	elseif err == "DuplicateTransaction" then
 		return "AlreadyPaid"
-	elseif err == "DataNotLoaded" or err == "SaveFailed" then
+	elseif err == "DataNotLoaded" or err == "SaveFailed" or err == "SaveUnconfirmed" or err == "SessionClosed" or err == "RewardHistoryFull" then
 		return "Retry" -- temporary: the data isn't loaded, or the write didn't go through
 	end
 	return "Rejected"
```

## `src/ReplicatedStorage/Shared/Types.luau`

```diff
diff --git a/src/ReplicatedStorage/Shared/Types.luau b/src/ReplicatedStorage/Shared/Types.luau
index cb3dfc8..acaf2e1 100644
--- a/src/ReplicatedStorage/Shared/Types.luau
+++ b/src/ReplicatedStorage/Shared/Types.luau
@@ -108,6 +108,7 @@ export type Profile = {
 	Cash: number,
 	RecentTransactions: { string }, -- most recent last; bounded; blocks duplicate grants/deductions
 	OwnedVehicles: { string }, -- vehicle ids this player may spawn (v2+); always includes the starters
+	PaidRewards: { string }, -- (v3+) ledger reward ids already paid; kept until the ledger drops them
 }
 
 export type EconomyError =
@@ -121,6 +122,10 @@ export type EconomyError =
 	| "AlreadyOwned"
 	| "TooManyVehicles"
 	| "SaveFailed" -- the change could not be stored, so it was NOT applied
+	| "SaveUnconfirmed" -- a write failed ambiguously and the store couldn't be read to check; the next
+	--   operation reconciles from the store, so it is applied at most once
+	| "SessionClosed" -- the player left or this server lost the profile's lock before it ran
+	| "RewardHistoryFull"
 	| "NotInGame"
 
 -- Store robbery (Phase 4B).
```

## `src/ServerScriptService/Server/Data/DataStoreAdapter.luau`

```diff
diff --git a/src/ServerScriptService/Server/Data/DataStoreAdapter.luau b/src/ServerScriptService/Server/Data/DataStoreAdapter.luau
index 7bd98b2..c391d97 100644
--- a/src/ServerScriptService/Server/Data/DataStoreAdapter.luau
+++ b/src/ServerScriptService/Server/Data/DataStoreAdapter.luau
@@ -30,11 +30,28 @@ function DataStoreAdapter.get(baseName: string): any
 	local store = DataStoreService:GetDataStore(DataStoreAdapter.storeName(baseName))
 	-- Studio-only: Workspace attribute SimulateStoreFailure_<baseName> fails just this store.
 	local perStore = "SimulateStoreFailure_" .. baseName
+	-- Studio-only: Workspace attribute SimulateCommitThenError_<baseName> = N makes the next N
+	-- writes to this store succeed and THEN raise an error (an ambiguous write).
+	local ambiguous = "SimulateCommitThenError_" .. baseName
 	return {
 		UpdateAsync = function(_, key: string, transform: (any) -> any): any
 			if DataStoreAdapter.isSimulatingFailure() or (RunService:IsStudio() and Workspace:GetAttribute(perStore) == true) then
 				error("Simulated DataStore failure (Studio test)")
 			end
+			local remaining = if RunService:IsStudio() then Workspace:GetAttribute(ambiguous) else nil
+			if type(remaining) == "number" and remaining > 0 then
+				local wrote = false
+				local result = store:UpdateAsync(key, function(old)
+					local new = transform(old)
+					wrote = new ~= nil
+					return new
+				end)
+				if wrote then
+					Workspace:SetAttribute(ambiguous, remaining - 1)
+					error("Simulated ambiguous DataStore write: stored, then errored (Studio test)")
+				end
+				return result
+			end
 			return store:UpdateAsync(key, transform)
 		end,
 	}
```

## `src/ServerScriptService/Server/Data/ProfileSession.luau`

```diff
diff --git a/src/ServerScriptService/Server/Data/ProfileSession.luau b/src/ServerScriptService/Server/Data/ProfileSession.luau
new file mode 100644
index 0000000..d3f0123
--- /dev/null
+++ b/src/ServerScriptService/Server/Data/ProfileSession.luau
@@ -0,0 +1,230 @@
+--!strict
+-- One player's profile on this server, and the ONLY way it is written (audit remediation).
+--  * Operations (commits and saves) run one at a time, in order (`run`).
+--  * Once a session is closed (the player left, this server lost the lock, or another server
+--    took ownership), every operation still queued or started later is refused with
+--    "SessionClosed" and writes nothing.
+--  * Write-through commits: a change is applied to a copy and stored before it takes effect
+--    (ProfileStore.commit).
+--  * Ambiguous writes: a write that errors may still have been stored. After any failed write
+--    the session is marked Stale, and NOTHING more is written from memory until it has been
+--    reconciled: the stored profile is read back (ProfileStore.read, our lock only) and adopted
+--    as the truth. A commit is then re-applied to that stored state; if the stored state
+--    already contains it (its transaction id is there), it reports success without applying it
+--    twice. Heartbeat and leave saves reconcile first too, so a stale copy can never overwrite
+--    a stored change.
+-- Pure apart from the injected store and wait function; unit-tested in ProfileSession.spec.
+local ReplicatedStorage = game:GetService("ReplicatedStorage")
+local Types = require(ReplicatedStorage.Shared.Types)
+local ProfileStore = require(script.Parent.ProfileStore)
+
+local ProfileSession = {}
+
+export type Session = {
+	Store: any,
+	Key: string,
+	SessionId: string,
+	Config: any,
+	Profile: Types.Profile,
+	Stale: boolean, -- a write failed ambiguously; reconcile before writing again
+	Leaving: boolean, -- the player is leaving: only the final save may still run
+	Closed: boolean,
+	CloseReason: string?,
+	Busy: boolean,
+	Queue: number, -- operations waiting for their turn
+	Wait: (number) -> (),
+	Now: () -> number,
+	Log: (string) -> (),
+}
+
+function ProfileSession.new(store: any, key: string, sessionId: string, profile: Types.Profile, config: any, options: { [string]: any }?): Session
+	local opts = options or {}
+	return {
+		Store = store,
+		Key = key,
+		SessionId = sessionId,
+		Config = config,
+		Profile = profile,
+		Stale = false,
+		Leaving = false,
+		Closed = false,
+		CloseReason = nil,
+		Busy = false,
+		Queue = 0,
+		Wait = opts.Wait or function(seconds: number)
+			task.wait(seconds)
+		end,
+		Now = opts.Now or os.time,
+		Log = opts.Log or function() end,
+	}
+end
+
+-- The player is leaving: commits queued or started from now on are refused; the final save
+-- (ProfileSession.save with release) may still run.
+function ProfileSession.beginLeave(session: Session)
+	session.Leaving = true
+end
+
+-- Closes the session: anything queued or started later writes nothing.
+function ProfileSession.close(session: Session, reason: string)
+	if not session.Closed then
+		session.Closed = true
+		session.CloseReason = reason
+	end
+end
+
+-- Runs fn with the profile to itself, in arrival order. Refuses if the session is (or becomes)
+-- closed before fn's turn comes.
+function ProfileSession.run<T...>(session: Session, fn: () -> T...): (boolean, ...any)
+	if session.Closed then
+		return false, "SessionClosed"
+	end
+	session.Queue += 1
+	while session.Busy do
+		task.wait()
+	end
+	session.Queue -= 1
+	if session.Closed then
+		return false, "SessionClosed"
+	end
+	session.Busy = true
+	local results = table.pack(pcall(fn))
+	session.Busy = false
+	if not results[1] then
+		error(results[2], 0)
+	end
+	return true, table.unpack(results, 2, results.n)
+end
+
+local function adopt(session: Session, stored: Types.Profile)
+	local profile = session.Profile
+	profile.Version = stored.Version
+	profile.Cash = stored.Cash
+	profile.RecentTransactions = stored.RecentTransactions
+	profile.OwnedVehicles = stored.OwnedVehicles
+	profile.PaidRewards = stored.PaidRewards
+end
+
+-- Reads the stored profile and adopts it. Returns (ok, err): "LockLost" closes the session.
+local function reconcile(session: Session): (boolean, string?)
+	local stored, err, detail = ProfileStore.read(session.Store, session.Key, session.SessionId, session.Config)
+	if stored then
+		adopt(session, stored)
+		session.Stale = false
+		session.Log(`reconciled from the store (cash={stored.Cash})`)
+		return true, nil
+	end
+	if err == "LockLost" then
+		ProfileSession.close(session, "LockLost")
+	end
+	session.Log(`reconcile failed ({err}{if detail then ": " .. detail else ""})`)
+	return false, err
+end
+
+-- Write-through change. mutate(draft) applies the change to a copy (and returns ok, err); the
+-- copy is stored before it takes effect. Returns (ok, err, note):
+--   ok=true            stored (note "AlreadyApplied" if an earlier ambiguous write had stored it)
+--   err = rule error   refused by the rules; nothing written
+--   err = "SaveFailed"       not stored (confirmed by reading the store)
+--   err = "SaveUnconfirmed"  writes failed and the store couldn't be read to check
+--   err = "SessionClosed"    the session closed (left / lock lost) before or while running
+function ProfileSession.commit(session: Session, mutate: (Types.Profile) -> (boolean, string?)): (boolean, string?, string?)
+	local ran, ok, err, note = ProfileSession.run(session, function(): (boolean, string?, string?)
+		local ambiguous = false
+		for attempt = 1, session.Config.CommitAttempts do
+			if session.Closed or session.Leaving then
+				return false, "SessionClosed", session.CloseReason or "Leaving"
+			end
+			if session.Stale then
+				local reconciled, recErr = reconcile(session)
+				if not reconciled then
+					if recErr == "LockLost" then
+						return false, "SessionClosed", "LockLost"
+					end
+					if attempt < session.Config.CommitAttempts then
+						session.Wait(session.Config.RetryBaseDelay * 2 ^ (attempt - 1))
+					end
+					continue
+				end
+			end
+			local committed, commitErr, detail = ProfileStore.commit(session.Store, session.Key, session.SessionId, session.Profile, session.Now(), mutate)
+			if committed then
+				return true, nil, nil
+			end
+			if commitErr == "DuplicateTransaction" and ambiguous then
+				-- The stored state (just reconciled) already holds this change: an earlier
+				-- write that reported an error had in fact been stored.
+				return true, nil, "AlreadyApplied"
+			end
+			if commitErr == "LockLost" then
+				ProfileSession.close(session, "LockLost")
+				return false, "SessionClosed", "LockLost"
+			end
+			if commitErr ~= "StoreError" then
+				return false, commitErr, nil -- refused by the rules
+			end
+			-- The write may or may not have been stored: never trust memory until reconciled.
+			ambiguous = true
+			session.Stale = true
+			session.Log(`write attempt {attempt} failed ({detail or commitErr})`)
+			if attempt < session.Config.CommitAttempts then
+				session.Wait(session.Config.RetryBaseDelay * 2 ^ (attempt - 1))
+			end
+		end
+		-- Out of attempts. Settle the answer from the store if it can be read.
+		if session.Stale and not session.Closed then
+			local reconciled = reconcile(session)
+			if reconciled then
+				local probe = table.clone(session.Profile) :: any
+				probe.RecentTransactions = table.clone(session.Profile.RecentTransactions)
+				probe.OwnedVehicles = table.clone(session.Profile.OwnedVehicles)
+				probe.PaidRewards = table.clone(session.Profile.PaidRewards)
+				local _, probeErr = mutate(probe)
+				if probeErr == "DuplicateTransaction" then
+					return true, nil, "AlreadyApplied"
+				end
+				return false, "SaveFailed", nil
+			end
+		end
+		if session.Closed then
+			return false, "SessionClosed", session.CloseReason
+		end
+		return false, if session.Stale then "SaveUnconfirmed" else "SaveFailed", nil
+	end)
+	if not ran then
+		return false, ok :: any, nil -- "SessionClosed"
+	end
+	return ok, err, note
+end
+
+-- Heartbeat / leave save. Reconciles first if a write was ambiguous, so a stale copy is never
+-- written. release=true drops the lock and closes the session. Returns (ok, err).
+function ProfileSession.save(session: Session, release: boolean): (boolean, string?)
+	local ran, ok, err = ProfileSession.run(session, function(): (boolean, string?)
+		if session.Stale then
+			local reconciled, recErr = reconcile(session)
+			if not reconciled then
+				return false, recErr -- don't write a copy that may be older than the store
+			end
+		end
+		local saved, saveErr = ProfileStore.save(session.Store, session.Key, session.SessionId, session.Profile, session.Now(), release)
+		if saved then
+			if release then
+				ProfileSession.close(session, "Released")
+			end
+			return true, nil
+		end
+		if saveErr == "LockLost" then
+			ProfileSession.close(session, "LockLost")
+		else
+			session.Stale = true
+		end
+		return false, saveErr
+	end)
+	if not ran then
+		return false, ok :: any
+	end
+	return ok, err
+end
+
+return ProfileSession
```

## `src/ServerScriptService/Server/Data/ProfileStore.luau`

```diff
diff --git a/src/ServerScriptService/Server/Data/ProfileStore.luau b/src/ServerScriptService/Server/Data/ProfileStore.luau
index 56da08a..7dbef52 100644
--- a/src/ServerScriptService/Server/Data/ProfileStore.luau
+++ b/src/ServerScriptService/Server/Data/ProfileStore.luau
@@ -19,6 +19,7 @@ export type Store = { UpdateAsync: (self: any, key: string, transform: (any) ->
 export type LoadResult = "New" | "Existing" | "Migrated"
 export type LoadError = "StoreError" | "SessionLocked" | "Corrupt"
 export type SaveError = "StoreError" | "LockLost"
+export type ReadError = "StoreError" | "LockLost" | "Corrupt"
 
 function ProfileStore.load(store: Store, key: string, sessionId: string, now: number, config: any): (Types.Profile?, LoadResult | LoadError, string?)
 	local profile: Types.Profile? = nil
@@ -55,6 +56,7 @@ local function copyProfile(profile: Types.Profile): Types.Profile
 		Cash = profile.Cash,
 		RecentTransactions = table.clone(profile.RecentTransactions),
 		OwnedVehicles = table.clone(profile.OwnedVehicles),
+		PaidRewards = table.clone(profile.PaidRewards),
 	}
 end
 
@@ -85,6 +87,7 @@ function ProfileStore.commit(
 	profile.Cash = draft.Cash
 	profile.RecentTransactions = draft.RecentTransactions
 	profile.OwnedVehicles = draft.OwnedVehicles
+	profile.PaidRewards = draft.PaidRewards
 	return true, nil, nil
 end
 
@@ -105,6 +108,7 @@ function ProfileStore.save(store: Store, key: string, sessionId: string, profile
 					Cash = profile.Cash,
 					RecentTransactions = table.clone(profile.RecentTransactions),
 					OwnedVehicles = table.clone(profile.OwnedVehicles),
+					PaidRewards = table.clone(profile.PaidRewards),
 				},
 				Lock = if release then nil else { Id = sessionId, At = now },
 			}
@@ -119,4 +123,35 @@ function ProfileStore.save(store: Store, key: string, sessionId: string, profile
 	return true, nil, nil
 end
 
+-- Reads the stored profile WITHOUT writing (the transform cancels), for reconciling after an
+-- ambiguous write. Returns (profile?, err?): "LockLost" if another session owns the record now.
+function ProfileStore.read(store: Store, key: string, sessionId: string, config: any): (Types.Profile?, ReadError?, string?)
+	local profile: Types.Profile? = nil
+	local outcome: ReadError? = nil
+	local ok, err = pcall(function()
+		store:UpdateAsync(key, function(old: any)
+			local record = if type(old) == "table" then old else nil
+			local lock = record and record.Lock
+			if type(lock) ~= "table" or lock.Id ~= sessionId then
+				outcome = "LockLost"
+				return nil
+			end
+			local loaded = EconomyRules.validateSaved(record and record.Profile, config)
+			if not loaded then
+				outcome = "Corrupt"
+				return nil
+			end
+			profile = loaded
+			return nil -- read only
+		end)
+	end)
+	if not ok then
+		return nil, "StoreError", tostring(err)
+	end
+	if outcome then
+		return nil, outcome, nil
+	end
+	return profile, nil, nil
+end
+
 return ProfileStore
```

## `src/ServerScriptService/Server/Data/RewardLedger.luau`

```diff
diff --git a/src/ServerScriptService/Server/Data/RewardLedger.luau b/src/ServerScriptService/Server/Data/RewardLedger.luau
index 12317a6..cf94f80 100644
--- a/src/ServerScriptService/Server/Data/RewardLedger.luau
+++ b/src/ServerScriptService/Server/Data/RewardLedger.luau
@@ -1,10 +1,19 @@
 --!strict
--- Durable record of earned-but-unpaid rewards (audit remediation). Kept in its OWN DataStore
+-- Durable record of earned-but-unpaid rewards. Kept in its OWN DataStore
 -- (EconomyConfig.RewardStoreName), separate from the player profile, so a reward survives a
 -- failed profile save, a disconnect or a server crash. Each entry carries the reward's stable
--- transaction id, so paying it later (on any server, on the player's next load) can never pay
--- twice: the profile's duplicate-transaction guard refuses a second grant.
--- Record: { Rewards = { { TxId: string, Amount: number, Reason: string, At: number } } }
+-- transaction id. Paying it (on any server, on load or in the periodic claim) records the id in
+-- the profile's PaidRewards in the same write, so it can never pay twice, however many other
+-- transactions happen in between.
+-- Record: { Rewards = { { TxId, Amount, Reason, At, State = "Pending" | "Blocked", Note? } } }
+-- Invalid states are handled explicitly (audit remediation):
+--  * a record that isn't a table of this shape is "LedgerCorrupt": never overwritten, never
+--    guessed at, reported;
+--  * an entry that isn't a valid reward is kept untouched in the record (never dropped) and
+--    counted as malformed;
+--  * a full ledger refuses new rewards with "LedgerFull" (the caller still tries to pay directly);
+--  * an entry the profile rules refuse for a lasting reason (e.g. BalanceCap) is marked
+--    "Blocked" with the reason, kept, and retried at the normal claim pace.
 -- Unit-tested with a fake store in ServerStorage.Tests.RewardLedger.spec.
 local ReplicatedStorage = game:GetService("ReplicatedStorage")
 local Types = require(ReplicatedStorage.Shared.Types)
@@ -12,89 +21,184 @@ local EconomyRules = require(ReplicatedStorage.Shared.Economy.EconomyRules)
 
 local RewardLedger = {}
 
-export type Reward = { TxId: string, Amount: number, Reason: string, At: number }
+export type Reward = { TxId: string, Amount: number, Reason: string, At: number, State: string?, Note: string? }
 export type Store = { UpdateAsync: (self: any, key: string, transform: (any) -> any) -> any }
+export type ClaimResult = { Settled: { string }, Blocked: { [string]: string }, Retry: { string } }
 
-local MAX_ENTRIES = 50
+local DEFAULT_MAX = 50
 
-local function entriesOf(record: any): { Reward }
-	local list = {}
-	if type(record) == "table" and type(record.Rewards) == "table" then
-		for _, r in record.Rewards do
-			if type(r) == "table" and type(r.TxId) == "string" and type(r.Amount) == "number" then
-				table.insert(list, { TxId = r.TxId, Amount = r.Amount, Reason = tostring(r.Reason or ""), At = tonumber(r.At) or 0 })
-			end
+local function isReward(r: any): boolean
+	return type(r) == "table" and type(r.TxId) == "string" and #r.TxId > 0 and type(r.Amount) == "number" and r.Amount == r.Amount
+end
+
+-- Splits a record into valid rewards and untouched malformed entries. Returns nil if the record
+-- itself is unusable (corrupt).
+local function parse(record: any): ({ Reward }?, { any }?)
+	if record == nil then
+		return {}, {}
+	end
+	if type(record) ~= "table" or (record.Rewards ~= nil and type(record.Rewards) ~= "table") then
+		return nil, nil
+	end
+	local valid, malformed = {}, {}
+	for _, r in record.Rewards or {} do
+		if isReward(r) then
+			table.insert(valid, {
+				TxId = r.TxId,
+				Amount = r.Amount,
+				Reason = tostring(r.Reason or ""),
+				At = tonumber(r.At) or 0,
+				State = if r.State == "Blocked" then "Blocked" else "Pending",
+				Note = if type(r.Note) == "string" then r.Note else nil,
+			})
+		else
+			table.insert(malformed, r)
 		end
 	end
-	return list
+	return valid, malformed
 end
 
--- Adds a reward (no-op if its TxId is already recorded). Returns (ok, err?).
-function RewardLedger.record(store: Store, key: string, reward: Reward): (boolean, string?)
+local function build(valid: { Reward }, malformed: { any }): any
+	local list = {}
+	for _, r in valid do
+		table.insert(list, r)
+	end
+	for _, r in malformed do
+		table.insert(list, r) -- kept exactly as found
+	end
+	return { Rewards = list }
+end
+
+-- Adds a reward (no-op if its TxId is already recorded). Returns (ok, err?):
+-- err is "LedgerFull", "LedgerCorrupt" or a store error.
+function RewardLedger.record(store: Store, key: string, reward: Reward, maxEntries: number?): (boolean, string?)
+	local limit = maxEntries or DEFAULT_MAX
+	local refusal: string? = nil
 	local ok, err = pcall(function()
 		store:UpdateAsync(key, function(old: any)
-			local list = entriesOf(old)
-			for _, r in list do
+			local valid, malformed = parse(old)
+			if not valid then
+				refusal = "LedgerCorrupt"
+				return nil
+			end
+			for _, r in valid do
 				if r.TxId == reward.TxId then
-					return nil -- already recorded: leave untouched
+					return nil -- already recorded
 				end
 			end
-			if #list >= MAX_ENTRIES then
-				error("reward ledger full")
+			if #valid + #(malformed :: { any }) >= limit then
+				refusal = "LedgerFull"
+				return nil
 			end
-			table.insert(list, reward)
-			return { Rewards = list }
+			table.insert(valid, { TxId = reward.TxId, Amount = reward.Amount, Reason = reward.Reason, At = reward.At, State = "Pending" })
+			return build(valid, malformed :: { any })
 		end)
 	end)
-	return ok, if ok then nil else tostring(err)
+	if not ok then
+		return false, tostring(err)
+	end
+	if refusal then
+		return false, refusal
+	end
+	return true, nil
 end
 
--- Reads the outstanding rewards without changing them. Returns (rewards?, err?).
-function RewardLedger.list(store: Store, key: string): ({ Reward }?, string?)
+-- Reads the outstanding rewards without changing them. Returns (rewards?, err?, malformedCount).
+function RewardLedger.list(store: Store, key: string): ({ Reward }?, string?, number)
 	local result: { Reward }? = nil
+	local malformedCount = 0
+	local corrupt = false
 	local ok, err = pcall(function()
 		store:UpdateAsync(key, function(old: any)
-			result = entriesOf(old)
+			local valid, malformed = parse(old)
+			if not valid then
+				corrupt = true
+				return nil
+			end
+			result = valid
+			malformedCount = #(malformed :: { any })
 			return nil -- read only
 		end)
 	end)
 	if not ok then
-		return nil, tostring(err)
+		return nil, tostring(err), 0
 	end
-	return result or {}, nil
+	if corrupt then
+		return nil, "LedgerCorrupt", 0
+	end
+	return result or {}, nil, malformedCount
 end
 
--- Removes settled rewards by TxId. Returns (ok, err?).
-function RewardLedger.remove(store: Store, key: string, txIds: { string }): (boolean, string?)
+-- Applies a claim's outcome: removes settled rewards, marks blocked ones (with their reason)
+-- and puts the rest back to Pending. Malformed entries are kept. Returns (ok, err?).
+function RewardLedger.update(store: Store, key: string, result: ClaimResult): (boolean, string?)
+	local corrupt = false
 	local ok, err = pcall(function()
 		store:UpdateAsync(key, function(old: any)
-			local list = entriesOf(old)
+			local valid, malformed = parse(old)
+			if not valid then
+				corrupt = true
+				return nil
+			end
 			local kept = {}
-			for _, r in list do
-				if not table.find(txIds, r.TxId) then
+			local changed = false
+			for _, r in valid do
+				if table.find(result.Settled, r.TxId) then
+					changed = true
+				else
+					local blockedNote = result.Blocked[r.TxId]
+					if blockedNote and (r.State ~= "Blocked" or r.Note ~= blockedNote) then
+						r.State = "Blocked"
+						r.Note = blockedNote
+						changed = true
+					elseif not blockedNote and r.State == "Blocked" and table.find(result.Retry, r.TxId) then
+						r.State = "Pending"
+						r.Note = nil
+						changed = true
+					end
 					table.insert(kept, r)
 				end
 			end
-			if #kept == #list then
+			if not changed then
 				return nil
 			end
-			return { Rewards = kept }
+			return build(kept, malformed :: { any })
 		end)
 	end)
-	return ok, if ok then nil else tostring(err)
+	if not ok then
+		return false, tostring(err)
+	end
+	if corrupt then
+		return false, "LedgerCorrupt"
+	end
+	return true, nil
 end
 
--- Applies every outstanding reward to `draft` (a profile copy inside ProfileStore.commit).
--- Already-paid ones (duplicate tx) are skipped. Returns the TxIds that are now settled.
-function RewardLedger.applyAll(draft: Types.Profile, rewards: { Reward }, config: any): { string }
-	local settled = {}
+-- Removes rewards by TxId (settled immediately after payment). Returns (ok, err?).
+function RewardLedger.remove(store: Store, key: string, txIds: { string }): (boolean, string?)
+	return RewardLedger.update(store, key, { Settled = txIds, Blocked = {}, Retry = {} })
+end
+
+-- Lasting refusals: the reward stays in the ledger as Blocked instead of being retried as if
+-- the store were down. Everything else that isn't paid is retried later.
+local LASTING = { BalanceCap = true, InvalidAmount = true, InvalidTransactionId = true, RewardHistoryFull = true }
+
+-- Pays every outstanding reward into `draft` (a profile copy inside a commit). Returns which
+-- were settled (paid now or already paid), which are blocked (with the reason) and which must
+-- simply be retried.
+function RewardLedger.applyAll(draft: Types.Profile, rewards: { Reward }, config: any): ClaimResult
+	local result: ClaimResult = { Settled = {}, Blocked = {}, Retry = {} }
 	for _, r in rewards do
-		local ok, err = EconomyRules.grant(draft, r.Amount, r.TxId, config)
+		local ok, err = EconomyRules.payReward(draft, r.Amount, r.TxId, config)
 		if ok or err == "DuplicateTransaction" then
-			table.insert(settled, r.TxId)
+			table.insert(result.Settled, r.TxId)
+		elseif err and LASTING[err] then
+			result.Blocked[r.TxId] = err
+		else
+			table.insert(result.Retry, r.TxId)
 		end
 	end
-	return settled
+	return result
 end
 
 return RewardLedger
```

## `src/ServerScriptService/Server/Dev/DevCommandRules.luau`

```diff
diff --git a/src/ServerScriptService/Server/Dev/DevCommandRules.luau b/src/ServerScriptService/Server/Dev/DevCommandRules.luau
index 7440e24..0a111e7 100644
--- a/src/ServerScriptService/Server/Dev/DevCommandRules.luau
+++ b/src/ServerScriptService/Server/Dev/DevCommandRules.luau
@@ -20,6 +20,7 @@ export type Command =
 	| { Name: "ClearRobberyCooldown" }
 	| { Name: "SetCashUnavailable", Value: boolean } -- simulates losing cash data mid-session
 	| { Name: "TryRobStore" }
+	| { Name: "AddLedgerReward", Value: number } -- writes a reward straight into the ledger
 	| { Name: "WriteLegacyProfile" } -- stores a v1 cash-only record; rejoin to test migration -- same server checks as the register prompt, minus the prompt's own range limit
 
 local function finite(value: any): boolean
@@ -73,6 +74,11 @@ function DevCommandRules.parse(name: any, value: any): (Command?, string?)
 			return nil, "SetCashUnavailable needs true or false"
 		end
 		return { Name = "SetCashUnavailable", Value = value }, nil
+	elseif name == "AddLedgerReward" then
+		if not finite(value) or value <= 0 or value % 1 ~= 0 then
+			return nil, "AddLedgerReward needs a whole positive amount"
+		end
+		return { Name = "AddLedgerReward", Value = value }, nil
 	elseif name == "WriteLegacyProfile" then
 		return { Name = "WriteLegacyProfile" }, nil
 	elseif name == "TryRobStore" then
```

## `src/ServerScriptService/Server/Dev/DevToolsService.luau`

```diff
diff --git a/src/ServerScriptService/Server/Dev/DevToolsService.luau b/src/ServerScriptService/Server/Dev/DevToolsService.luau
index d4de636..fbf3354 100644
--- a/src/ServerScriptService/Server/Dev/DevToolsService.luau
+++ b/src/ServerScriptService/Server/Dev/DevToolsService.luau
@@ -60,6 +60,8 @@ local function run(player: Player, name: unknown, value: unknown): (boolean, str
 		return true, nil
 	elseif command.Name == "SetCashUnavailable" then
 		return EconomyService.setUnavailableForTesting(player, (command :: any).Value), nil
+	elseif command.Name == "AddLedgerReward" then
+		return EconomyService.addLedgerRewardForTesting(player, (command :: any).Value)
 	elseif command.Name == "WriteLegacyProfile" then
 		return EconomyService.writeLegacyRecordForTesting(player), nil
 	elseif command.Name == "TryRobStore" then
```

## `src/ServerScriptService/Server/Services/DealershipService.luau`

```diff
diff --git a/src/ServerScriptService/Server/Services/DealershipService.luau b/src/ServerScriptService/Server/Services/DealershipService.luau
index 2976430..ca27c12 100644
--- a/src/ServerScriptService/Server/Services/DealershipService.luau
+++ b/src/ServerScriptService/Server/Services/DealershipService.luau
@@ -51,8 +51,14 @@ local function purchase(player: Player, vehicleId: unknown): (boolean, Types.Pur
 		return false, "TooFar"
 	end
 	inFlight[player] = true
-	local ok, err = EconomyService.purchaseVehicle(player, vehicleId, price, EconomyService.newTransactionId("buy:" .. vehicleId))
+	-- The flag is cleared even if the economy call raises (audit remediation): otherwise one
+	-- error would leave this player unable to buy until they rejoin.
+	local called, ok, err = pcall(EconomyService.purchaseVehicle, player, vehicleId, price, EconomyService.newTransactionId("buy:" .. vehicleId))
 	inFlight[player] = nil
+	if not called then
+		warn(`[Dealership] {player.Name}: purchase raised an error: {tostring(ok)}`)
+		return false, "SaveUnconfirmed" -- the outcome is unknown; the next operation reconciles from the store
+	end
 	return ok, err
 end
 
```

## `src/ServerScriptService/Server/Services/EconomyService.luau`

```diff
diff --git a/src/ServerScriptService/Server/Services/EconomyService.luau b/src/ServerScriptService/Server/Services/EconomyService.luau
index 1d0f64d..43f32bc 100644
--- a/src/ServerScriptService/Server/Services/EconomyService.luau
+++ b/src/ServerScriptService/Server/Services/EconomyService.luau
@@ -5,19 +5,16 @@
 --  * If loading fails, the player is marked "Unavailable": no changes, and NOTHING is saved for
 --    them (so a DataStore outage can never overwrite real progress with defaults). Loading is
 --    retried in the background until it succeeds.
---  * WRITE-THROUGH (audit remediation): every grant, deduction and purchase is applied to a copy
---    of the profile and written with ProfileStore.commit BEFORE it takes effect. If the write
---    fails, nothing changes and the caller gets "SaveFailed". So anything this service reports
---    as done is already stored and survives a crash, a failed leave-save or another server
---    taking the lock later.
---  * Changes for one player are serialised (one commit or save at a time), so concurrent
---    requests can't overwrite each other.
---  * Earned rewards (grantReward) are first recorded in a separate reward ledger, then granted.
---    If the grant can't be stored now, the ledger entry is paid on the player's next successful
---    load on any server, exactly once (same transaction id).
---  * Every loaded profile is re-saved every AutosaveInterval to refresh its session lock (a
---    quiet session's lock must never go stale while the player is still here); saved and
---    released on leave and on shutdown. A failed leave-save is retried in the background.
+--  * Every write goes through the player's ProfileSession (audit remediation): one operation at
+--    a time; write-through commits (a change is stored before it takes effect; a failed write
+--    returns SaveFailed with nothing applied); after an ambiguous write nothing is written from
+--    memory until the stored profile has been read back and adopted; operations queued when the
+--    player leaves or the lock is lost never run.
+--  * Earned rewards (grantReward) are first recorded in a separate reward ledger, then paid
+--    write-through with the id kept in the profile's PaidRewards. Anything still in the ledger
+--    is claimed after load and then periodically with bounded backoff, exactly once.
+--  * Every loaded profile is re-saved every AutosaveInterval to refresh its session lock; saved
+--    and released on leave and on shutdown. A failed leave-save is retried in the background.
 local HttpService = game:GetService("HttpService")
 local Players = game:GetService("Players")
 local ReplicatedStorage = game:GetService("ReplicatedStorage")
@@ -31,6 +28,7 @@ local EconomyRules = require(Shared.Economy.EconomyRules)
 local PlayerAttributes = require(Shared.Player.PlayerAttributes)
 local Data = script.Parent.Parent.Data
 local ProfileStore = require(Data.ProfileStore)
+local ProfileSession = require(Data.ProfileSession)
 local RewardLedger = require(Data.RewardLedger)
 local DataStoreAdapter = require(Data.DataStoreAdapter)
 
@@ -39,14 +37,17 @@ local EconomyService = {}
 type Session = {
 	Status: "Loading" | "Loaded" | "Unavailable",
 	Profile: Types.Profile?,
+	Store: ProfileSession.Session?, -- set once loaded
 	Key: string,
 	Leaving: boolean,
-	Busy: boolean, -- a commit or save is in progress for this player
+	NextClaim: number, -- os.clock() time of the next ledger check
+	ClaimFailures: number,
+	Claiming: boolean,
 }
 
 local sessions: { [Player]: Session } = {}
-type Orphan = { Name: string, Profile: Types.Profile, Since: number }
-local orphans: { [string]: Orphan } = {} -- key -> profile whose save on leave failed
+type Orphan = { Name: string, Store: ProfileSession.Session, Since: number }
+local orphans: { [string]: Orphan } = {} -- key -> session whose save on leave failed
 local store: any
 local rewardStore: any
 -- A Studio playtest has no JobId; give each server a unique lock id either way.
@@ -72,85 +73,114 @@ local function rewardKeyFor(key: string): string
 	return `rewards_{key}`
 end
 
--- Runs fn with this player's profile to itself: no other commit or save interleaves.
-local function withLock<T...>(session: Session, fn: () -> T...): T...
-	while session.Busy do
-		task.wait()
-	end
-	session.Busy = true
-	local results = table.pack(pcall(fn))
-	session.Busy = false
-	if not results[1] then
-		error(results[2], 0)
+local function newProfileSession(player: Player, key: string, profile: Types.Profile): ProfileSession.Session
+	return ProfileSession.new(store, key, sessionId, profile, EconomyConfig, {
+		Log = function(text: string)
+			log(`{player.Name}: {text}`)
+		end,
+	})
+end
+
+-- The ProfileSession closed under us (lock lost / taken over): stop treating data as loaded.
+local function checkClosed(player: Player, session: Session)
+	local ps = session.Store
+	if ps and ps.Closed and ps.CloseReason == "LockLost" and session.Status == "Loaded" then
+		session.Status = "Unavailable"
+		publish(player, session)
+		warn(`[Economy] {player.Name}: another server owns this profile now; this server stops changing it`)
 	end
-	return table.unpack(results, 2, results.n)
 end
 
--- Write-through commit for a loaded session. Returns (ok, err): rule errors pass through,
--- store failures become "SaveFailed" (nothing applied). Losing the lock means another server
--- owns this profile now, so this session stops writing.
-local function commit(player: Player, session: Session, label: string, mutate: (Types.Profile) -> (boolean, string?)): (boolean, Types.EconomyError?)
-	local profile = session.Profile :: Types.Profile
-	local lastErr: string? = nil
-	for attempt = 1, EconomyConfig.CommitAttempts do
-		local ok, err, detail = ProfileStore.commit(store, session.Key, sessionId, profile, os.time(), mutate)
-		if ok then
-			return true, nil
-		end
-		if err ~= "StoreError" and err ~= "LockLost" then
-			return false, err :: any -- refused by the rules: nothing to retry
-		end
-		lastErr = err
-		log(`{player.Name}: {label} write attempt {attempt} failed ({err}{if detail then ": " .. detail else ""})`)
-		if err == "LockLost" then
-			session.Status = "Unavailable"
-			publish(player, session)
-			warn(`[Economy] {player.Name}: another server owns this profile; this session stops changing it`)
-			break
-		end
-		if attempt < EconomyConfig.CommitAttempts then
-			task.wait(EconomyConfig.RetryBaseDelay * 2 ^ (attempt - 1))
-		end
+local function scheduleClaim(session: Session, ok: boolean, outstanding: number)
+	if ok then
+		session.ClaimFailures = 0
+		session.NextClaim = os.clock() + (if outstanding > 0 then EconomyConfig.ClaimRetryBase else EconomyConfig.ClaimIdleInterval)
+	else
+		session.ClaimFailures += 1
+		local delay = math.min(EconomyConfig.ClaimRetryBase * 2 ^ (session.ClaimFailures - 1), EconomyConfig.ClaimRetryMax)
+		session.NextClaim = os.clock() + delay
 	end
-	log(`{player.Name}: {label} NOT applied ({lastErr}); nothing changed`)
-	return false, "SaveFailed"
 end
 
--- Pays rewards recorded in the ledger (earned earlier, here or on another server, but not
--- stored then). Runs once after each successful load; safe to repeat.
+-- Pays what the reward ledger still holds (earned earlier, here or elsewhere, but not stored
+-- then), prunes PaidRewards the ledger no longer lists, and marks lasting refusals Blocked.
 local function claimRewards(player: Player, session: Session)
-	local rewards, listErr = RewardLedger.list(rewardStore, rewardKeyFor(session.Key))
+	local ps = session.Store
+	if not ps or session.Claiming or session.Status ~= "Loaded" then
+		return
+	end
+	session.Claiming = true
+	local rewards, listErr, malformed = RewardLedger.list(rewardStore, rewardKeyFor(session.Key))
 	if not rewards then
-		log(`{player.Name}: reward ledger unreadable ({listErr}); will retry on the next load`)
+		log(`{player.Name}: reward ledger unreadable ({listErr}); retrying later`)
+		if listErr == "LedgerCorrupt" then
+			warn(`[Economy] {player.Name}: reward ledger record is corrupt; left untouched for review`)
+		end
+		scheduleClaim(session, false, 0)
+		session.Claiming = false
 		return
 	end
-	if #rewards == 0 then
+	if malformed > 0 then
+		warn(`[Economy] {player.Name}: reward ledger has {malformed} malformed entr(y/ies); kept untouched for review`)
+	end
+	local inLedger = {}
+	for _, r in rewards do
+		table.insert(inLedger, r.TxId)
+	end
+	local needsWrite = #rewards > 0
+	for _, txId in (session.Profile :: Types.Profile).PaidRewards do
+		if not table.find(inLedger, txId) then
+			needsWrite = true -- something to prune
+			break
+		end
+	end
+	if not needsWrite then
+		scheduleClaim(session, true, 0)
+		session.Claiming = false
 		return
 	end
-	local settled: { string } = {}
-	local ok = withLock(session, function()
-		local committed = commit(player, session, "claim rewards", function(draft)
-			settled = RewardLedger.applyAll(draft, rewards, EconomyConfig)
-			return true, nil
-		end)
-		return committed
+	local result: RewardLedger.ClaimResult = { Settled = {}, Blocked = {}, Retry = {} }
+	local ok, err = ProfileSession.commit(ps, function(draft)
+		EconomyRules.prunePaidRewards(draft, inLedger)
+		result = RewardLedger.applyAll(draft, rewards, EconomyConfig)
+		return true, nil
 	end)
+	checkClosed(player, session)
 	if ok then
 		publish(player, session)
-		log(`{player.Name}: paid {#settled} recorded reward(s) -> {(session.Profile :: Types.Profile).Cash}`)
-		RewardLedger.remove(rewardStore, rewardKeyFor(session.Key), settled)
+		if #result.Settled > 0 then
+			log(`{player.Name}: settled {#result.Settled} recorded reward(s) -> cash {(session.Profile :: Types.Profile).Cash}`)
+		end
+		for txId, reason in result.Blocked do
+			warn(`[Economy] {player.Name}: recorded reward {txId} blocked ({reason}); kept in the ledger and retried later`)
+		end
+		local updated = RewardLedger.update(rewardStore, rewardKeyFor(session.Key), result)
+		local outstanding = #rewards - #result.Settled
+		scheduleClaim(session, updated, outstanding)
+	else
+		log(`{player.Name}: claiming recorded rewards failed ({err}); retrying later`)
+		scheduleClaim(session, false, #rewards)
 	end
+	session.Claiming = false
+end
+
+local function adoptLoaded(player: Player, session: Session, profile: Types.Profile)
+	session.Profile = profile
+	session.Store = newProfileSession(player, session.Key, profile)
+	session.Status = "Loaded"
+	session.NextClaim = 0 -- claim right away
+	publish(player, session)
 end
 
 local function tryLoad(player: Player, session: Session): boolean
 	for attempt = 1, EconomyConfig.LoadAttempts do
 		local profile, result, detail = ProfileStore.load(store, session.Key, sessionId, os.time(), EconomyConfig)
 		if profile then
-			session.Profile = profile
-			session.Status = "Loaded"
-			publish(player, session)
+			if player.Parent ~= Players or session.Leaving then
+				return false
+			end
+			adoptLoaded(player, session, profile)
 			log(`{player.Name}: loaded ({result}) cash={profile.Cash}`)
-			task.spawn(claimRewards, player, session)
 			return true
 		end
 		log(`{player.Name}: load attempt {attempt} failed ({result}{if detail then ": " .. detail else ""})`)
@@ -171,63 +201,38 @@ local function loadWithRecovery(player: Player, session: Session)
 	if tryLoad(player, session) then
 		return
 	end
+	if player.Parent ~= Players or session.Leaving then
+		return
+	end
 	session.Status = "Unavailable"
 	publish(player, session)
 	log(`{player.Name}: data unavailable; cash changes disabled and nothing will be saved until it loads`)
-	while player.Parent == Players and session.Status ~= "Loaded" do
+	while player.Parent == Players and not session.Leaving and session.Status ~= "Loaded" do
 		task.wait(EconomyConfig.FailedRetryInterval)
-		if player.Parent == Players and tryLoad(player, session) then
+		if player.Parent == Players and not session.Leaving and tryLoad(player, session) then
 			log(`{player.Name}: recovered after a failed load`)
 		end
 	end
 end
 
--- Returns (saved, lockLost).
-local function saveProfile(name: string, key: string, profile: Types.Profile, release: boolean, attempts: number): (boolean, boolean)
-	for attempt = 1, attempts do
-		local ok, err, detail = ProfileStore.save(store, key, sessionId, profile, os.time(), release)
-		if ok then
-			return true, false
-		end
-		log(`{name}: save attempt {attempt} failed ({err}{if detail then ": " .. detail else ""})`)
-		if err == "LockLost" then
-			return false, true
-		end
-		if attempt < attempts then
-			task.wait(EconomyConfig.RetryBaseDelay * 2 ^ (attempt - 1))
-		end
-	end
-	return false, false
-end
-
-local function save(player: Player, session: Session, release: boolean): boolean
-	return withLock(session, function()
-		if session.Status ~= "Loaded" or not session.Profile then
-			return false -- never write for a profile we didn't load
-		end
-		local ok = saveProfile(player.Name, session.Key, session.Profile :: Types.Profile, release, EconomyConfig.SaveAttempts)
-		return ok
-	end)
-end
-
--- Background retries for profiles whose save on leave failed. Since every cash change is
--- already stored when it happens, this only refreshes/releases the lock; nothing acknowledged
--- depends on it.
+-- Background retries for sessions whose save on leave failed. Every change was already stored
+-- when it happened; this releases the lock (reconciling first if a write was ambiguous).
 local function retryOrphan(key: string, orphan: Orphan)
 	while orphans[key] == orphan do
 		task.wait(EconomyConfig.OrphanRetryInterval)
 		if orphans[key] ~= orphan then
-			return -- the player came back and took the profile over
+			return
 		end
-		local ok, lockLost = saveProfile(orphan.Name, key, orphan.Profile, true, 1)
+		local ok = ProfileSession.save(orphan.Store, true)
 		if ok then
 			orphans[key] = nil
-			log(`{orphan.Name}: saved after leaving (cash={orphan.Profile.Cash})`)
-		elseif lockLost then
+			log(`{orphan.Name}: released after leaving (cash={orphan.Store.Profile.Cash})`)
+		elseif orphan.Store.Closed then
 			orphans[key] = nil
 			log(`{orphan.Name}: another server owns this profile now; nothing to release`)
 		elseif os.clock() - orphan.Since > EconomyConfig.OrphanRetryLimit then
 			orphans[key] = nil
+			ProfileSession.close(orphan.Store, "GaveUp")
 			warn(`[Economy] {orphan.Name}: gave up releasing the lock after {EconomyConfig.OrphanRetryLimit}s (it expires by itself)`)
 		end
 	end
@@ -235,63 +240,59 @@ end
 
 local function loadedSession(player: Player): (Session?, Types.EconomyError?)
 	local session = sessions[player]
-	if not session or player.Parent ~= Players then
+	if not session or player.Parent ~= Players or session.Leaving then
 		return nil, "NotInGame"
 	end
-	if session.Status ~= "Loaded" or not session.Profile then
+	if session.Status ~= "Loaded" or not session.Store then
 		return nil, "DataNotLoaded"
 	end
 	return session, nil
 end
 
-local function change(player: Player, kind: "grant" | "deduct", amount: any, txId: any, reason: string): (boolean, Types.EconomyError?)
+-- One write-through change for a loaded player. Returns (ok, err).
+local function commitChange(player: Player, label: string, mutate: (Types.Profile) -> (boolean, string?)): (boolean, Types.EconomyError?)
 	local session, err = loadedSession(player)
 	if not session then
 		return false, err
 	end
-	local ok, changeErr = withLock(session, function()
-		if session.Status ~= "Loaded" then
-			return false, "DataNotLoaded" :: Types.EconomyError?
-		end
-		return commit(player, session, `{kind} {tostring(amount)}`, function(draft)
-			if kind == "grant" then
-				return EconomyRules.grant(draft, amount, txId, EconomyConfig)
-			end
-			return EconomyRules.deduct(draft, amount, txId, EconomyConfig)
-		end)
-	end)
+	local ok, changeErr, note = ProfileSession.commit(session.Store :: ProfileSession.Session, mutate)
+	checkClosed(player, session)
 	if ok then
 		publish(player, session)
-		log(`{player.Name}: {kind} {amount} ({reason}, tx {txId}) -> {(session.Profile :: Types.Profile).Cash} (stored)`)
+		log(`{player.Name}: {label} -> {(session.Profile :: Types.Profile).Cash} (stored{if note then ", " .. note else ""})`)
 	else
-		log(`{player.Name}: {kind} {tostring(amount)} refused: {changeErr} ({reason}, tx {tostring(txId)})`)
+		log(`{player.Name}: {label} refused: {changeErr}`)
 	end
-	return ok, changeErr
+	return ok, changeErr :: any
 end
 
 -- Server-only API. txId must be unique per real-world event; repeats are refused. Returns true
 -- only once the change is stored.
 function EconomyService.grant(player: Player, amount: number, txId: string, reason: string): (boolean, Types.EconomyError?)
-	return change(player, "grant", amount, txId, reason)
+	return commitChange(player, `grant {tostring(amount)} ({reason}, tx {tostring(txId)})`, function(draft)
+		return EconomyRules.grant(draft, amount, txId, EconomyConfig)
+	end)
 end
 
 function EconomyService.deduct(player: Player, amount: number, txId: string, reason: string): (boolean, Types.EconomyError?)
-	return change(player, "deduct", amount, txId, reason)
+	return commitChange(player, `deduct {tostring(amount)} ({reason}, tx {tostring(txId)})`, function(draft)
+		return EconomyRules.deduct(draft, amount, txId, EconomyConfig)
+	end)
 end
 
 -- A reward the player has EARNED (robbery payout). Recorded in the reward ledger first, then
--- granted write-through. Returns (paid, err, recorded): if not paid but recorded, the reward
--- will be paid on the player's next successful load (any server), never twice.
+-- paid write-through (its id kept in PaidRewards). Returns (paid, err, recorded): if not paid but
+-- recorded, the periodic/next-load claim pays it, never twice.
 function EconomyService.grantReward(player: Player, amount: number, txId: string, reason: string): (boolean, Types.EconomyError?, boolean)
-	local recorded, recordErr = RewardLedger.record(rewardStore, rewardKeyFor(keyFor(player)), { TxId = txId, Amount = amount, Reason = reason, At = os.time() })
+	local recorded, recordErr = RewardLedger.record(rewardStore, rewardKeyFor(keyFor(player)), { TxId = txId, Amount = amount, Reason = reason, At = os.time() }, EconomyConfig.LedgerMaxEntries)
 	if not recorded then
-		log(`{player.Name}: reward {txId} could not be recorded in the ledger ({recordErr})`)
+		warn(`[Economy] {player.Name}: reward {txId} could not be recorded in the ledger ({recordErr}); paying directly`)
 	end
-	local paid, err = change(player, "grant", amount, txId, reason)
+	local paid, err = commitChange(player, `reward {amount} ({reason}, tx {txId})`, function(draft)
+		return EconomyRules.payReward(draft, amount, txId, EconomyConfig)
+	end)
 	if paid or err == "DuplicateTransaction" then
-		-- Settled now (or earlier): clear it from the ledger. If this fails, the next load's
-		-- claim finds it already paid (duplicate tx) and clears it then.
-		RewardLedger.remove(rewardStore, rewardKeyFor(keyFor(player)), { txId })
+		RewardLedger.remove(rewardStore, rewardKeyFor(keyFor(player)), { txId }) -- best effort
 	end
 	return paid, err, recorded
 end
@@ -321,29 +322,16 @@ function EconomyService.ownsVehicle(player: Player, vehicleId: string): boolean
 	return session ~= nil and session.Status == "Loaded" and session.Profile ~= nil and EconomyRules.ownsVehicle(session.Profile, vehicleId)
 end
 
--- Server-only purchase: the price and the ownership are applied together to a profile copy and
--- stored in one write; only then does the purchase take effect and return true. A failed write
--- returns "SaveFailed" with nothing charged and no car.
+-- Server-only purchase: price and ownership are stored together in one write BEFORE the
+-- purchase takes effect. SaveFailed: nothing charged. SaveUnconfirmed: the write's outcome
+-- couldn't be checked; the next operation reconciles, so it is applied at most once.
 function EconomyService.purchaseVehicle(player: Player, vehicleId: string, price: number, txId: string): (boolean, Types.EconomyError?)
-	local session, err = loadedSession(player)
-	if not session then
-		return false, err
+	if RunService:IsStudio() and Workspace:GetAttribute("SimulatePurchaseError") == true then
+		error("Simulated purchase error (Studio test)") -- tests that callers clean up after errors
 	end
-	local ok, buyErr = withLock(session, function()
-		if session.Status ~= "Loaded" then
-			return false, "DataNotLoaded" :: Types.EconomyError?
-		end
-		return commit(player, session, `purchase {tostring(vehicleId)}`, function(draft)
-			return EconomyRules.purchaseVehicle(draft, vehicleId, price, txId, EconomyConfig)
-		end)
+	return commitChange(player, `purchase {tostring(vehicleId)} for {tostring(price)} (tx {tostring(txId)})`, function(draft)
+		return EconomyRules.purchaseVehicle(draft, vehicleId, price, txId, EconomyConfig)
 	end)
-	if ok then
-		publish(player, session)
-		log(`{player.Name}: bought {vehicleId} for {price} (tx {txId}) -> cash {(session.Profile :: Types.Profile).Cash} (stored)`)
-	else
-		log(`{player.Name}: purchase {tostring(vehicleId)} for {tostring(price)} refused: {buyErr} (tx {tostring(txId)})`)
-	end
-	return ok, buyErr
 end
 
 -- Unique transaction id helper for server systems.
@@ -355,7 +343,25 @@ end
 function EconomyService.saveNowForTesting(player: Player): boolean
 	assert(RunService:IsStudio(), "Studio-only")
 	local session = sessions[player]
-	return session ~= nil and save(player, session, false)
+	return session ~= nil and session.Store ~= nil and (ProfileSession.save(session.Store :: ProfileSession.Session, false))
+end
+
+-- Studio test hook: writes a reward straight into this player's ledger (as if another server
+-- had recorded it but couldn't pay it), for testing the periodic claim.
+function EconomyService.addLedgerRewardForTesting(player: Player, amount: number): (boolean, string?)
+	assert(RunService:IsStudio(), "Studio-only")
+	return RewardLedger.record(rewardStore, rewardKeyFor(keyFor(player)), { TxId = EconomyService.newTransactionId("test"), Amount = amount, Reason = "Studio ledger test", At = os.time() }, EconomyConfig.LedgerMaxEntries)
+end
+
+-- Studio test hook: run the ledger claim now.
+function EconomyService.claimNowForTesting(player: Player): boolean
+	assert(RunService:IsStudio(), "Studio-only")
+	local session = sessions[player]
+	if not session then
+		return false
+	end
+	claimRewards(player, session)
+	return true
 end
 
 -- Studio test hook: pretend this player's cash data just became unavailable (true) or came
@@ -377,7 +383,7 @@ end
 function EconomyService.writeLegacyRecordForTesting(player: Player): boolean
 	assert(RunService:IsStudio(), "Studio-only")
 	local session = sessions[player]
-	if not session or session.Status ~= "Loaded" or not session.Profile then
+	if not session or session.Status ~= "Loaded" or not session.Profile or not session.Store then
 		return false
 	end
 	local profile = session.Profile :: Types.Profile
@@ -387,6 +393,7 @@ function EconomyService.writeLegacyRecordForTesting(player: Player): boolean
 		end)
 	end)
 	if ok then
+		ProfileSession.close(session.Store :: ProfileSession.Session, "TestLegacy")
 		session.Status = "Unavailable" -- nothing more is saved this session
 		publish(player, session)
 		log(`{player.Name}: Studio test: stored record rewritten as version 1 (cash={profile.Cash}); rejoin to migrate`)
@@ -395,18 +402,29 @@ function EconomyService.writeLegacyRecordForTesting(player: Player): boolean
 end
 
 local function onPlayerAdded(player: Player)
-	local session: Session = { Status = "Loading", Profile = nil, Key = keyFor(player), Leaving = false, Busy = false }
+	local session: Session = {
+		Status = "Loading",
+		Profile = nil,
+		Store = nil,
+		Key = keyFor(player),
+		Leaving = false,
+		NextClaim = math.huge,
+		ClaimFailures = 0,
+		Claiming = false,
+	}
 	sessions[player] = session
 	local orphan = orphans[session.Key]
-	if orphan then
-		-- Rejoined this server before its leave-save went through: this server still holds the
-		-- lock and the copy matches what was stored by the write-through commits.
+	if orphan and not orphan.Store.Closed then
+		-- Rejoined this server before its leave-save went through: it still holds the lock and
+		-- the session's profile matches what was stored by the write-through commits.
 		orphans[session.Key] = nil
-		session.Profile = orphan.Profile
+		orphan.Store.Leaving = false
+		session.Profile = orphan.Store.Profile
+		session.Store = orphan.Store
 		session.Status = "Loaded"
+		session.NextClaim = 0
 		publish(player, session)
-		log(`{player.Name}: rejoined; using the profile kept on this server (cash={orphan.Profile.Cash})`)
-		task.spawn(claimRewards, player, session)
+		log(`{player.Name}: rejoined; using the profile kept on this server (cash={orphan.Store.Profile.Cash})`)
 		return
 	end
 	publish(player, session)
@@ -419,20 +437,28 @@ local function onPlayerRemoving(player: Player)
 		return
 	end
 	session.Leaving = true
-	if session.Status == "Loaded" then
-		local profile = session.Profile :: Types.Profile
-		if save(player, session, true) then
-			log(`{player.Name}: saved on leave (cash={profile.Cash})`)
-		elseif sessions[player] == session then
-			local orphan: Orphan = { Name = player.Name, Profile = profile, Since = os.clock() }
+	local ps = session.Store
+	if session.Status == "Loaded" and ps then
+		-- From here no queued or new commit may run; only the final save.
+		ProfileSession.beginLeave(ps)
+		local ok = ProfileSession.save(ps, true)
+		if ok then
+			log(`{player.Name}: saved on leave (cash={ps.Profile.Cash})`)
+		elseif not ps.Closed then
+			local orphan: Orphan = { Name = player.Name, Store = ps, Since = os.clock() }
 			orphans[session.Key] = orphan
 			warn(`[Economy] {player.Name}: save on leave failed; retrying in the background (every change was already stored when it happened)`)
 			task.spawn(retryOrphan, session.Key, orphan)
 		end
 	else
+		if ps then
+			ProfileSession.close(ps, "Left")
+		end
 		log(`{player.Name}: left with data {session.Status}; nothing saved (protects stored progress)`)
 	end
-	sessions[player] = nil
+	if sessions[player] == session then
+		sessions[player] = nil
+	end
 end
 
 function EconomyService.init()
@@ -464,9 +490,9 @@ function EconomyService.start()
 		for key, orphan in orphans do
 			pending += 1
 			task.spawn(function()
-				if saveProfile(orphan.Name, key, orphan.Profile, true, 1) then
+				if ProfileSession.save(orphan.Store, true) then
 					orphans[key] = nil
-					log(`{orphan.Name}: saved at shutdown (cash={orphan.Profile.Cash})`)
+					log(`{orphan.Name}: released at shutdown (cash={orphan.Store.Profile.Cash})`)
 				end
 				pending -= 1
 			end)
@@ -477,13 +503,29 @@ function EconomyService.start()
 		end
 	end)
 	-- Lock heartbeat: re-save every loaded profile so its session lock stays fresh while the
-	-- player is here (a lock older than SessionLockTimeout could be claimed by another server).
+	-- player is here (reconciling first if a write was ambiguous).
 	task.spawn(function()
 		while true do
 			task.wait(EconomyConfig.AutosaveInterval)
 			for player, session in sessions do
-				if session.Status == "Loaded" and not session.Leaving then
-					task.spawn(save, player, session, false)
+				local ps = session.Store
+				if session.Status == "Loaded" and not session.Leaving and ps then
+					task.spawn(function()
+						ProfileSession.save(ps, false)
+						checkClosed(player, session)
+					end)
+				end
+			end
+		end
+	end)
+	-- Reward ledger claims: right after load, then periodically with bounded backoff.
+	task.spawn(function()
+		while true do
+			task.wait(2)
+			local now = os.clock()
+			for player, session in sessions do
+				if session.Status == "Loaded" and not session.Leaving and not session.Claiming and now >= session.NextClaim then
+					task.spawn(claimRewards, player, session)
 				end
 			end
 		end
```

## `src/ServerStorage/Tests/EconomyRules.spec.luau`

```diff
diff --git a/src/ServerStorage/Tests/EconomyRules.spec.luau b/src/ServerStorage/Tests/EconomyRules.spec.luau
index a01d03f..e330d92 100644
--- a/src/ServerStorage/Tests/EconomyRules.spec.luau
+++ b/src/ServerStorage/Tests/EconomyRules.spec.luau
@@ -76,7 +76,7 @@ return {
 		Assert.equal(p.Cash, C.MaxBalance - 10)
 	end,
 	["valid saved data is kept exactly; malformed data is refused, never reset"] = function()
-		local saved = { Version = 2, Cash = 12345, RecentTransactions = { "x", "y", 5 }, OwnedVehicles = { "Coupe" } }
+		local saved = { Version = 3, Cash = 12345, RecentTransactions = { "x", "y", 5 }, OwnedVehicles = { "Coupe" }, PaidRewards = {} }
 		local p, kind = EconomyRules.validateSaved(saved, C)
 		Assert.equal(kind, "Existing")
 		Assert.equal(p.Cash, 12345, "not reset to starting cash")
@@ -107,15 +107,16 @@ return {
 		local p = EconomyRules.validateSaved({ Version = 1, Cash = 5, OwnedVehicles = { "Muscle" } }, C)
 		Assert.equal(EconomyRules.ownsVehicle(p, "Muscle"), false)
 	end,
-	["v2 ownership is kept; junk is dropped; damaged or newer records are refused untouched"] = function()
-		local p, kind = EconomyRules.validateSaved({ Version = 2, Cash = 1, RecentTransactions = {}, OwnedVehicles = { "Muscle", 7, "Muscle", "" } }, C)
+	["saved ownership is kept; junk is dropped; damaged or newer records are refused untouched"] = function()
+		local p, kind = EconomyRules.validateSaved({ Version = 3, Cash = 1, RecentTransactions = {}, OwnedVehicles = { "Muscle", 7, "Muscle", "" }, PaidRewards = {} }, C)
 		Assert.equal(kind, "Existing")
 		Assert.equal(EconomyRules.ownsVehicle(p, "Muscle"), true)
 		Assert.equal(EconomyRules.ownsVehicle(p, "Coupe"), true, "starter is always owned")
 		Assert.equal(#p.OwnedVehicles, 2, "duplicates and junk removed")
 		for _, bad in {
 			{ Version = 2, Cash = 1, RecentTransactions = {} }, -- v2 without its list
-			{ Version = 3, Cash = 1, RecentTransactions = {}, OwnedVehicles = {} }, -- newer schema
+			{ Version = 3, Cash = 1, RecentTransactions = {}, OwnedVehicles = {} }, -- v3 without its paid-reward list
+			{ Version = 4, Cash = 1, RecentTransactions = {}, OwnedVehicles = {}, PaidRewards = {} }, -- newer schema
 			{ Version = 0, Cash = 1 },
 			{ Version = 1.5, Cash = 1 },
 		} do
@@ -155,6 +156,45 @@ return {
 		end
 		Assert.equal(p.Cash, 14999)
 	end,
+	["v2 profiles migrate to v3 keeping cash, cars and history, with no paid rewards yet"] = function()
+		local p, kind = EconomyRules.validateSaved({ Version = 2, Cash = 800, RecentTransactions = { "buy:1" }, OwnedVehicles = { "Coupe", "Muscle" } }, C)
+		Assert.equal(kind, "Migrated")
+		Assert.equal(p.Version, 3)
+		Assert.equal(p.Cash, 800)
+		Assert.equal(EconomyRules.ownsVehicle(p, "Muscle"), true)
+		Assert.equal(p.RecentTransactions[1], "buy:1")
+		Assert.equal(#p.PaidRewards, 0)
+	end,
+	["a ledger reward pays once and stays blocked from paying again after 200+ later transactions"] = function()
+		local p = fresh()
+		Assert.equal((EconomyRules.payReward(p, 2000, "robbery:old", C)), true)
+		for i = 1, C.RecentTransactionLimit + 50 do
+			assert(EconomyRules.grant(p, 1, "g" .. i, C))
+		end
+		Assert.equal(EconomyRules.hasTransaction(p, "robbery:old"), false, "aged out of the recent ids")
+		local cash = p.Cash
+		local ok, err = EconomyRules.payReward(p, 2000, "robbery:old", C)
+		Assert.equal(ok, false)
+		Assert.equal(err, "DuplicateTransaction")
+		Assert.equal(p.Cash, cash)
+	end,
+	["paid-reward ids are pruned only once the ledger no longer lists them"] = function()
+		local p = fresh()
+		assert(EconomyRules.payReward(p, 10, "r1", C))
+		assert(EconomyRules.payReward(p, 10, "r2", C))
+		Assert.equal(EconomyRules.prunePaidRewards(p, { "r1" }), 1)
+		Assert.equal(table.find(p.PaidRewards, "r1") ~= nil, true, "still in the ledger: kept")
+		Assert.equal(table.find(p.PaidRewards, "r2"), nil)
+	end,
+	["a full paid-reward history refuses explicitly instead of forgetting"] = function()
+		local p = fresh()
+		for i = 1, C.MaxPaidRewards do
+			p.PaidRewards[i] = "x" .. i
+		end
+		local ok, err = EconomyRules.payReward(p, 10, "r-new", C)
+		Assert.equal(ok, false)
+		Assert.equal(err, "RewardHistoryFull")
+	end,
 	["session locks: own or stale locks can be claimed, live foreign locks cannot"] = function()
 		local T = C.SessionLockTimeout
 		Assert.equal(EconomyRules.canClaimLock(nil, "me", 1000, T), true)
```

## `src/ServerStorage/Tests/ProfileSession.spec.luau`

```diff
diff --git a/src/ServerStorage/Tests/ProfileSession.spec.luau b/src/ServerStorage/Tests/ProfileSession.spec.luau
new file mode 100644
index 0000000..52e6ce6
--- /dev/null
+++ b/src/ServerStorage/Tests/ProfileSession.spec.luau
@@ -0,0 +1,212 @@
+-- ProfileSession (audit remediation): ambiguous writes are reconciled from the store before
+-- anything else is written, and queued operations never run after the player leaves or the
+-- lock is lost. Uses a fake store that can fail, store-then-error, and yield mid-write.
+local ReplicatedStorage = game:GetService("ReplicatedStorage")
+local ServerScriptService = game:GetService("ServerScriptService")
+local HttpService = game:GetService("HttpService")
+local ProfileSession = require(ServerScriptService.Server.Data.ProfileSession)
+local ProfileStore = require(ServerScriptService.Server.Data.ProfileStore)
+local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
+local EconomyRules = require(ReplicatedStorage.Shared.Economy.EconomyRules)
+local Assert = require(script.Parent.Assert)
+
+local C = EconomyConfig
+
+local function deepCopy(value)
+	if value == nil then
+		return nil
+	end
+	return HttpService:JSONDecode(HttpService:JSONEncode(value))
+end
+
+-- Fail: every call errors. CommitThenError = n: the next n writes are stored, then error.
+-- Yield = seconds: each call waits (lets other operations queue up).
+local function fakeStore()
+	local data = {}
+	local store = { Fail = false, CommitThenError = 0, Yield = 0, Writes = 0, Data = data }
+	function store.UpdateAsync(self, key, transform)
+		if self.Yield > 0 then
+			task.wait(self.Yield)
+		end
+		if self.Fail then
+			error("simulated outage")
+		end
+		local result = transform(deepCopy(data[key]))
+		if result ~= nil then
+			data[key] = deepCopy(result)
+			self.Writes += 1
+			if self.CommitThenError > 0 then
+				self.CommitThenError -= 1
+				error("simulated ambiguous write (stored, then errored)")
+			end
+		end
+		return deepCopy(result)
+	end
+	return store
+end
+
+local function session(store, cash: number?)
+	local profile = assert(ProfileStore.load(store, "k", "A", 1000, C))
+	if cash then
+		profile.Cash = cash
+		assert(ProfileStore.save(store, "k", "A", profile, 1000, false))
+	end
+	return ProfileSession.new(store, "k", "A", profile, C, { Wait = function() end, Now = function() return 1001 end })
+end
+
+local function buy(s, tx: string)
+	return ProfileSession.commit(s, function(draft)
+		return EconomyRules.purchaseVehicle(draft, "Muscle", 15000, tx, C)
+	end)
+end
+
+return {
+	["ambiguous write: stored-then-errored purchase is detected and counted once"] = function()
+		local store = fakeStore()
+		local s = session(store, 20000)
+		store.CommitThenError = 1
+		local ok, err, note = buy(s, "buy:1")
+		Assert.equal(ok, true, tostring(err))
+		Assert.equal(note, "AlreadyApplied")
+		Assert.equal(s.Profile.Cash, 5000)
+		Assert.equal(EconomyRules.ownsVehicle(s.Profile, "Muscle"), true)
+		Assert.equal(store.Data.k.Profile.Cash, 5000, "charged exactly once in the store")
+		Assert.equal(s.Stale, false)
+	end,
+	["ambiguous write + unreadable store: stale memory never overwrites the stored change"] = function()
+		local store = fakeStore()
+		local s = session(store, 20000)
+		store.CommitThenError = 1
+		-- after the ambiguous write, the store stays down for the rest of this commit
+		local realUpdate = store.UpdateAsync
+		local calls = 0
+		store.UpdateAsync = function(self, key, transform)
+			calls += 1
+			if calls > 1 then
+				error("still down")
+			end
+			return realUpdate(self, key, transform)
+		end
+		local ok, err = buy(s, "buy:1")
+		Assert.equal(ok, false)
+		Assert.equal(err, "SaveUnconfirmed")
+		Assert.equal(s.Stale, true)
+		Assert.equal(s.Profile.Cash, 20000, "memory doesn't know yet")
+		Assert.equal(store.Data.k.Profile.Cash, 5000, "but the store has it")
+		-- store back: a heartbeat must reconcile first, not write the stale copy over the store
+		store.UpdateAsync = realUpdate
+		Assert.equal((ProfileSession.save(s, false)), true)
+		Assert.equal(store.Data.k.Profile.Cash, 5000, "stored purchase survived the heartbeat")
+		Assert.equal(s.Profile.Cash, 5000, "memory adopted the stored truth")
+		Assert.equal(EconomyRules.ownsVehicle(s.Profile, "Muscle"), true)
+		-- the client retries the same purchase: never charged twice
+		local ok2, err2 = buy(s, "buy:2")
+		Assert.equal(ok2, false)
+		Assert.equal(err2, "AlreadyOwned")
+		Assert.equal(store.Data.k.Profile.Cash, 5000)
+	end,
+	["ambiguous write that did NOT store: retried once, applied once"] = function()
+		local store = fakeStore()
+		local s = session(store, 20000)
+		local realUpdate = store.UpdateAsync
+		local first = true
+		store.UpdateAsync = function(self, key, transform)
+			if first then
+				first = false
+				error("failed before storing")
+			end
+			return realUpdate(self, key, transform)
+		end
+		local ok, err, note = buy(s, "buy:1")
+		Assert.equal(ok, true, tostring(err))
+		Assert.equal(note, nil)
+		Assert.equal(store.Data.k.Profile.Cash, 5000)
+	end,
+	["an unreachable store reports SaveUnconfirmed and nothing is applied"] = function()
+		local store = fakeStore()
+		local s = session(store, 20000)
+		store.Fail = true
+		local ok, err = buy(s, "buy:1")
+		Assert.equal(ok, false)
+		Assert.equal(err, "SaveUnconfirmed", "the store can't even be read: outcome unknown")
+		store.Fail = false
+		Assert.equal((ProfileSession.save(s, false)), true)
+		Assert.equal(store.Data.k.Profile.Cash, 20000)
+		Assert.equal(EconomyRules.ownsVehicle(s.Profile, "Muscle"), false)
+	end,
+	["operations queued when the player leaves never run"] = function()
+		local store = fakeStore()
+		local s = session(store, 20000)
+		store.Yield = 0.1
+		local results = {}
+		task.spawn(function()
+			results.a = table.pack(ProfileSession.commit(s, function(draft)
+				return EconomyRules.grant(draft, 100, "g1", C)
+			end))
+		end)
+		task.wait() -- A is now writing
+		task.spawn(function()
+			results.b = table.pack(ProfileSession.commit(s, function(draft)
+				return EconomyRules.grant(draft, 100, "g2", C)
+			end))
+		end)
+		ProfileSession.beginLeave(s)
+		local t0 = os.clock()
+		while (not results.a or not results.b) and os.clock() - t0 < 3 do
+			task.wait(0.05)
+		end
+		Assert.equal(results.a[1], true, "the operation already writing finishes")
+		Assert.equal(results.b[1], false)
+		Assert.equal(results.b[2], "SessionClosed")
+		Assert.equal(EconomyRules.hasTransaction(s.Profile, "g2"), false)
+		Assert.equal(table.find(store.Data.k.Profile.RecentTransactions, "g2"), nil, "never written")
+		-- the final save may still run, and closes the session
+		store.Yield = 0
+		Assert.equal((ProfileSession.save(s, true)), true)
+		Assert.equal(s.Closed, true)
+		local ok, err = ProfileSession.commit(s, function(draft)
+			return EconomyRules.grant(draft, 1, "late", C)
+		end)
+		Assert.equal(ok, false)
+		Assert.equal(err, "SessionClosed")
+	end,
+	["another server taking the lock closes the session; queued operations don't run"] = function()
+		local store = fakeStore()
+		local s = session(store, 20000)
+		store.Yield = 0.1
+		local results = {}
+		task.spawn(function()
+			results.a = table.pack(ProfileSession.commit(s, function(draft)
+				return EconomyRules.grant(draft, 100, "g1", C)
+			end))
+		end)
+		task.wait()
+		task.spawn(function()
+			results.b = table.pack(ProfileSession.commit(s, function(draft)
+				return EconomyRules.grant(draft, 100, "g2", C)
+			end))
+		end)
+		-- server B takes over while A's write is in flight
+		store.Data.k.Lock = { Id = "B", At = 5000 }
+		local t0 = os.clock()
+		while (not results.a or not results.b) and os.clock() - t0 < 3 do
+			task.wait(0.05)
+		end
+		Assert.equal(results.a[1], false)
+		Assert.equal(results.a[2], "SessionClosed")
+		Assert.equal(results.a[3], "LockLost")
+		Assert.equal(results.b[2], "SessionClosed")
+		Assert.equal(s.Closed, true)
+		Assert.equal(store.Data.k.Lock.Id, "B", "B's ownership untouched")
+		Assert.equal(store.Data.k.Profile.Cash, 20000, "nothing written over B")
+	end,
+	["a heartbeat after the lock moved closes the session instead of writing"] = function()
+		local store = fakeStore()
+		local s = session(store, 20000)
+		store.Data.k.Lock = { Id = "B", At = 5000 }
+		local ok, err = ProfileSession.save(s, false)
+		Assert.equal(ok, false)
+		Assert.equal(err, "LockLost")
+		Assert.equal(s.Closed, true)
+	end,
+}
```

## `src/ServerStorage/Tests/RewardLedger.spec.luau`

```diff
diff --git a/src/ServerStorage/Tests/RewardLedger.spec.luau b/src/ServerStorage/Tests/RewardLedger.spec.luau
index ed69b5a..169b0ed 100644
--- a/src/ServerStorage/Tests/RewardLedger.spec.luau
+++ b/src/ServerStorage/Tests/RewardLedger.spec.luau
@@ -1,5 +1,6 @@
 -- Durable reward ledger (audit remediation): earned rewards survive failed profile saves,
--- disconnects and server crashes, and are paid exactly once.
+-- disconnects and server crashes, are paid exactly once (also after 200+ later transactions),
+-- and invalid states (BalanceCap, malformed data, a full ledger) are handled explicitly.
 local ReplicatedStorage = game:GetService("ReplicatedStorage")
 local ServerScriptService = game:GetService("ServerScriptService")
 local HttpService = game:GetService("HttpService")
@@ -38,18 +39,33 @@ local function reward(tx: string, amount: number?)
 	return { TxId = tx, Amount = amount or 2000, Reason = "store robbery", At = 1 }
 end
 
--- What EconomyService does on a load: pay everything recorded, then clear it.
+-- What EconomyService.claimRewards does: pay what the ledger holds, prune PaidRewards the
+-- ledger no longer lists, then settle/block entries in the ledger.
 local function claim(profiles, rewards, profile, sessionId, now)
-	local list = assert(RewardLedger.list(rewards, "r"))
-	local settled = {}
+	local list = RewardLedger.list(rewards, "r")
+	if not list then
+		return false, nil
+	end
+	local inLedger = {}
+	for _, r in list do
+		table.insert(inLedger, r.TxId)
+	end
+	local result = { Settled = {}, Blocked = {}, Retry = {} }
 	local ok = ProfileStore.commit(profiles, "k", sessionId, profile, now, function(draft)
-		settled = RewardLedger.applyAll(draft, list, C)
+		EconomyRules.prunePaidRewards(draft, inLedger)
+		result = RewardLedger.applyAll(draft, list, C)
 		return true, nil
 	end)
 	if ok then
-		RewardLedger.remove(rewards, "r", settled)
+		RewardLedger.update(rewards, "r", result)
 	end
-	return ok
+	return ok, result
+end
+
+local function pay(profiles, profile, tx, amount, now)
+	return ProfileStore.commit(profiles, "k", "A", profile, now, function(draft)
+		return EconomyRules.payReward(draft, amount, tx, C)
+	end)
 end
 
 return {
@@ -63,37 +79,37 @@ return {
 		local profiles, rewards = fakeStore(), fakeStore()
 		local a = ProfileStore.load(profiles, "k", "A", 1000, C)
 		local startCash = a.Cash
-		-- escape: ledger write succeeds, profile write fails
 		assert(RewardLedger.record(rewards, "r", reward("robbery:1")))
 		profiles.Fail = true
-		local ok = ProfileStore.commit(profiles, "k", "A", a, 1001, function(draft)
-			return EconomyRules.grant(draft, 2000, "robbery:1", C)
-		end)
-		Assert.equal(ok, false)
-		Assert.equal(profiles.Data.k.Profile.Cash, startCash)
-		-- server A dies; later server B loads after the lock expires and claims the ledger
+		Assert.equal((pay(profiles, a, "robbery:1", 2000, 1001)), false)
 		profiles.Fail = false
 		local b = ProfileStore.load(profiles, "k", "B", 1001 + C.SessionLockTimeout + 1, C)
-		Assert.equal(claim(profiles, rewards, b, "B", 1300), true)
+		Assert.equal((claim(profiles, rewards, b, "B", 1300)), true)
 		Assert.equal(b.Cash, startCash + 2000)
-		Assert.equal(profiles.Data.k.Profile.Cash, startCash + 2000)
 		Assert.equal(#assert(RewardLedger.list(rewards, "r")), 0, "ledger cleared")
-		-- claiming again (another rejoin) pays nothing more
-		Assert.equal(claim(profiles, rewards, b, "B", 1301), true)
-		Assert.equal(b.Cash, startCash + 2000)
+		Assert.equal((claim(profiles, rewards, b, "B", 1301)), true)
+		Assert.equal(b.Cash, startCash + 2000, "a second claim pays nothing")
 	end,
-	["a reward already paid but not cleared from the ledger is never paid twice"] = function()
+	["dedupe beyond 200 transactions: a paid reward left in the ledger never pays again"] = function()
 		local profiles, rewards = fakeStore(), fakeStore()
 		local a = ProfileStore.load(profiles, "k", "A", 1000, C)
-		assert(RewardLedger.record(rewards, "r", reward("robbery:1")))
-		assert(ProfileStore.commit(profiles, "k", "A", a, 1001, function(draft)
-			return EconomyRules.grant(draft, 2000, "robbery:1", C)
-		end))
-		-- the ledger removal failed (outage), so the entry is still there on the next load
+		assert(RewardLedger.record(rewards, "r", reward("robbery:old")))
+		assert(pay(profiles, a, "robbery:old", 2000, 1001))
+		-- the ledger removal failed, so the entry is still there; then lots of other activity
+		for i = 1, C.RecentTransactionLimit + 50 do
+			assert(ProfileStore.commit(profiles, "k", "A", a, 1002 + i, function(draft)
+				return EconomyRules.grant(draft, 1, "g" .. i, C)
+			end))
+		end
+		Assert.equal(EconomyRules.hasTransaction(a, "robbery:old"), false, "aged out of the recent ids")
 		local cash = a.Cash
-		Assert.equal(claim(profiles, rewards, a, "A", 1002), true)
-		Assert.equal(a.Cash, cash, "duplicate transaction: not paid again")
-		Assert.equal(#assert(RewardLedger.list(rewards, "r")), 0, "and now cleared")
+		Assert.equal((claim(profiles, rewards, a, "A", 2000)), true)
+		Assert.equal(a.Cash, cash, "not paid again (PaidRewards)")
+		Assert.equal(#assert(RewardLedger.list(rewards, "r")), 0, "settled and cleared")
+		-- next claim prunes the paid id now that the ledger no longer lists it
+		Assert.equal((claim(profiles, rewards, a, "A", 2001)), true)
+		Assert.equal(table.find(a.PaidRewards, "robbery:old"), nil, "pruned")
+		Assert.equal(table.find(profiles.Data.k.Profile.PaidRewards, "robbery:old"), nil)
 	end,
 	["claim during a profile outage pays nothing and keeps the ledger entry"] = function()
 		local profiles, rewards = fakeStore(), fakeStore()
@@ -101,25 +117,83 @@ return {
 		local cash = a.Cash
 		assert(RewardLedger.record(rewards, "r", reward("robbery:1")))
 		profiles.Fail = true
-		Assert.equal(claim(profiles, rewards, a, "A", 1001), false)
+		Assert.equal((claim(profiles, rewards, a, "A", 1001)), false)
 		Assert.equal(a.Cash, cash)
 		Assert.equal(#assert(RewardLedger.list(rewards, "r")), 1, "still recorded for the next try")
 	end,
-	["several recorded rewards are paid together and each once"] = function()
+	["recovery: an unreadable ledger is retried and pays once it can be read"] = function()
 		local profiles, rewards = fakeStore(), fakeStore()
 		local a = ProfileStore.load(profiles, "k", "A", 1000, C)
 		local cash = a.Cash
-		assert(RewardLedger.record(rewards, "r", reward("robbery:1", 2000)))
-		assert(RewardLedger.record(rewards, "r", reward("robbery:2", 2000)))
-		Assert.equal(claim(profiles, rewards, a, "A", 1001), true)
-		Assert.equal(a.Cash, cash + 4000)
+		assert(RewardLedger.record(rewards, "r", reward("robbery:1", 500)))
+		rewards.Fail = true
+		local list, err = RewardLedger.list(rewards, "r")
+		Assert.equal(list, nil)
+		Assert.truthy(err ~= nil, "unreadable is reported")
+		Assert.equal((claim(profiles, rewards, a, "A", 1001)), false)
+		rewards.Fail = false
+		Assert.equal((claim(profiles, rewards, a, "A", 1031)), true)
+		Assert.equal(a.Cash, cash + 500)
 	end,
-	["a ledger outage is reported, not hidden"] = function()
+	["BalanceCap: the reward is kept as Blocked (not dropped, not paid) and paid once it fits"] = function()
+		local profiles, rewards = fakeStore(), fakeStore()
+		local a = ProfileStore.load(profiles, "k", "A", 1000, C)
+		assert(ProfileStore.commit(profiles, "k", "A", a, 1000, function(draft)
+			draft.Cash = C.MaxBalance - 100
+			return true, nil
+		end))
+		assert(RewardLedger.record(rewards, "r", reward("robbery:big", 2000)))
+		local ok, result = claim(profiles, rewards, a, "A", 1001)
+		Assert.equal(ok, true)
+		Assert.equal(result.Blocked["robbery:big"], "BalanceCap")
+		Assert.equal(a.Cash, C.MaxBalance - 100)
+		local entry = assert(RewardLedger.list(rewards, "r"))[1]
+		Assert.equal(entry.State, "Blocked")
+		Assert.equal(entry.Note, "BalanceCap")
+		-- the player spends; the next claim pays it
+		assert(ProfileStore.commit(profiles, "k", "A", a, 1002, function(draft)
+			return EconomyRules.deduct(draft, 5000, "spend", C)
+		end))
+		Assert.equal((claim(profiles, rewards, a, "A", 1003)), true)
+		Assert.equal(a.Cash, C.MaxBalance - 100 - 5000 + 2000)
+		Assert.equal(#assert(RewardLedger.list(rewards, "r")), 0)
+	end,
+	["a full ledger refuses new rewards explicitly"] = function()
 		local rewards = fakeStore()
-		rewards.Fail = true
+		for i = 1, 3 do
+			assert(RewardLedger.record(rewards, "r", reward("r" .. i), 3))
+		end
+		local ok, err = RewardLedger.record(rewards, "r", reward("r4"), 3)
+		Assert.equal(ok, false)
+		Assert.equal(err, "LedgerFull")
+		Assert.equal(#assert(RewardLedger.list(rewards, "r")), 3, "nothing dropped")
+	end,
+	["a corrupt ledger record is never overwritten; malformed entries are kept"] = function()
+		local rewards = fakeStore()
+		rewards.Data.r = "garbage"
 		local ok, err = RewardLedger.record(rewards, "r", reward("robbery:1"))
 		Assert.equal(ok, false)
-		Assert.truthy(err ~= nil)
-		Assert.equal((RewardLedger.list(rewards, "r")), nil)
+		Assert.equal(err, "LedgerCorrupt")
+		Assert.equal(rewards.Data.r, "garbage", "untouched")
+		local list, listErr = RewardLedger.list(rewards, "r")
+		Assert.equal(list, nil)
+		Assert.equal(listErr, "LedgerCorrupt")
+		-- a record with one malformed entry: the entry survives every rewrite
+		rewards.Data.r2 = { Rewards = { { TxId = 5 }, reward("robbery:2") } }
+		local valid, _, malformed = RewardLedger.list(rewards, "r2")
+		Assert.equal(#assert(valid), 1)
+		Assert.equal(malformed, 1)
+		assert(RewardLedger.remove(rewards, "r2", { "robbery:2" }))
+		Assert.equal(#rewards.Data.r2.Rewards, 1)
+		Assert.equal(rewards.Data.r2.Rewards[1].TxId, 5, "malformed entry kept as found")
+	end,
+	["several recorded rewards are paid together and each once"] = function()
+		local profiles, rewards = fakeStore(), fakeStore()
+		local a = ProfileStore.load(profiles, "k", "A", 1000, C)
+		local cash = a.Cash
+		assert(RewardLedger.record(rewards, "r", reward("robbery:1", 2000)))
+		assert(RewardLedger.record(rewards, "r", reward("robbery:2", 2000)))
+		Assert.equal((claim(profiles, rewards, a, "A", 1001)), true)
+		Assert.equal(a.Cash, cash + 4000)
 	end,
 }
```

## `src/StarterPlayer/StarterPlayerScripts/Client/Controllers/DealershipController.luau`

```diff
diff --git a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/DealershipController.luau b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/DealershipController.luau
index bc99ddf..9ec3e43 100644
--- a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/DealershipController.luau
+++ b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/DealershipController.luau
@@ -30,6 +30,8 @@ local RESULT_TEXT: { [string]: string } = {
 	DuplicateTransaction = "That purchase was already processed.",
 	TooManyVehicles = "Your garage is full.",
 	SaveFailed = "Couldn't save your purchase right now. Nothing was charged; try again.",
+	SaveUnconfirmed = "We couldn't confirm your purchase. If it went through, the car will appear in your garage; you'll never be charged twice.",
+	SessionClosed = "Your data is no longer active on this server. Please rejoin.",
 	NetworkError = "Couldn't reach the server. Nothing was charged.",
 }
 
```
