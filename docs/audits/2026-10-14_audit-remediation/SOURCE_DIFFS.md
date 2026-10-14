# Source diffs: 2026-10-14_audit-remediation

Commit range `5bdb1c9..882e857` (Studio snapshot in `src/`, byte-identical to the Outlaw City place 132163592957463).

Two kinds of section:
- **Changed** modules show the remediation diff.
- **Unchanged** modules show the full current source, so their concurrency, idempotency and lost-update behaviour can be checked: EconomyRules, DealershipService, VehicleService, PoliceDriveRules and EconomyRules.spec. The auditor asked about all of these.

## EconomyRules (unchanged in this range: full current source)
`src/ReplicatedStorage/Shared/Economy/EconomyRules.luau`

```lua
--!strict
-- Pure economy rules: amount and transaction-id validation, grants, deductions, duplicate
-- protection, profile creation/validation and session-lock claims. No Instances, no clocks.
-- Unit-tested in ServerStorage.Tests.EconomyRules.spec.
local Types = require(script.Parent.Parent.Types)

local EconomyRules = {}

type Config = {
	StartingCash: number,
	MaxBalance: number,
	MaxTransaction: number,
	RecentTransactionLimit: number,
	TransactionIdMaxLength: number,
	ProfileVersion: number,
	StarterVehicles: { string },
	MaxOwnedVehicles: number,
	VehicleIdMaxLength: number,
}

local function isWholeFinite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge and n % 1 == 0
end

-- Amounts must be whole, finite, positive and no bigger than MaxTransaction.
function EconomyRules.validateAmount(amount: any, config: Config): (boolean, Types.EconomyError?)
	if not isWholeFinite(amount) or amount <= 0 or amount > config.MaxTransaction then
		return false, "InvalidAmount"
	end
	return true, nil
end

function EconomyRules.validateTransactionId(txId: any, config: Config): (boolean, Types.EconomyError?)
	if type(txId) ~= "string" or #txId == 0 or #txId > config.TransactionIdMaxLength then
		return false, "InvalidTransactionId"
	end
	return true, nil
end

function EconomyRules.newProfile(config: Config): Types.Profile
	return {
		Version = config.ProfileVersion,
		Cash = config.StartingCash,
		RecentTransactions = {},
		OwnedVehicles = table.clone(config.StarterVehicles),
	}
end

-- Checks saved data. nil (never saved) -> a new profile with starting cash. Valid data is
-- returned as-is (never reset to defaults). Anything malformed is reported as corrupt so the
-- caller refuses to load and never overwrites it.
function EconomyRules.validateSaved(saved: any, config: Config): (Types.Profile?, string?)
	if saved == nil then
		return EconomyRules.newProfile(config), "New"
	end
	if type(saved) ~= "table" or not isWholeFinite(saved.Cash) or saved.Cash < 0 or saved.Cash > config.MaxBalance then
		return nil, "Corrupt"
	end
	-- Version 1 records (cash only) predate the field being required.
	local version = if saved.Version == nil then 1 else saved.Version
	if not isWholeFinite(version) or version < 1 or version > config.ProfileVersion then
		return nil, "Corrupt" -- unknown or newer schema: never guess, never downgrade
	end
	local recent = {}
	if type(saved.RecentTransactions) == "table" then
		for _, txId in saved.RecentTransactions do
			if type(txId) == "string" then
				table.insert(recent, txId)
			end
		end
	end
	-- Ownership: starters always; from v2 on, the saved list (it must be a list).
	local owned = table.clone(config.StarterVehicles)
	if version >= 2 then
		if type(saved.OwnedVehicles) ~= "table" then
			return nil, "Corrupt" -- a v2 record without its ownership list is damaged, not empty
		end
		for _, vehicleId in saved.OwnedVehicles do
			if
				type(vehicleId) == "string"
				and #vehicleId > 0
				and #vehicleId <= config.VehicleIdMaxLength
				and not table.find(owned, vehicleId)
				and #owned < config.MaxOwnedVehicles
			then
				table.insert(owned, vehicleId)
			end
		end
	end
	return {
		Version = config.ProfileVersion,
		Cash = saved.Cash,
		RecentTransactions = recent,
		OwnedVehicles = owned,
	}, if version < config.ProfileVersion then "Migrated" else "Existing"
end

function EconomyRules.hasTransaction(profile: Types.Profile, txId: string): boolean
	return table.find(profile.RecentTransactions, txId) ~= nil
end

local function remember(profile: Types.Profile, txId: string, config: Config)
	table.insert(profile.RecentTransactions, txId)
	while #profile.RecentTransactions > config.RecentTransactionLimit do
		table.remove(profile.RecentTransactions, 1)
	end
end

local function precheck(profile: Types.Profile, amount: any, txId: any, config: Config): (boolean, Types.EconomyError?)
	local ok, err = EconomyRules.validateAmount(amount, config)
	if not ok then
		return false, err
	end
	ok, err = EconomyRules.validateTransactionId(txId, config)
	if not ok then
		return false, err
	end
	if EconomyRules.hasTransaction(profile, txId) then
		return false, "DuplicateTransaction"
	end
	return true, nil
end

function EconomyRules.canAfford(profile: Types.Profile, amount: number): boolean
	return isWholeFinite(amount) and amount >= 0 and profile.Cash >= amount
end

-- Adds cash once per transaction id. Never exceeds MaxBalance.
function EconomyRules.grant(profile: Types.Profile, amount: any, txId: any, config: Config): (boolean, Types.EconomyError?)
	local ok, err = precheck(profile, amount, txId, config)
	if not ok then
		return false, err
	end
	if profile.Cash + amount > config.MaxBalance then
		return false, "BalanceCap"
	end
	profile.Cash += amount
	remember(profile, txId, config)
	return true, nil
end

-- Removes cash once per transaction id; refuses if the balance is too small (purchases).
function EconomyRules.deduct(profile: Types.Profile, amount: any, txId: any, config: Config): (boolean, Types.EconomyError?)
	local ok, err = precheck(profile, amount, txId, config)
	if not ok then
		return false, err
	end
	if not EconomyRules.canAfford(profile, amount) then
		return false, "InsufficientFunds"
	end
	profile.Cash -= amount
	remember(profile, txId, config)
	return true, nil
end

function EconomyRules.ownsVehicle(profile: Types.Profile, vehicleId: string): boolean
	return table.find(profile.OwnedVehicles, vehicleId) ~= nil
end

-- Buys a vehicle: takes the price AND records ownership in one step on the same profile, so
-- they are always saved together (never cash without the car, never the car without cash).
-- The price comes from server config, never from the client.
function EconomyRules.purchaseVehicle(profile: Types.Profile, vehicleId: any, price: any, txId: any, config: Config): (boolean, Types.EconomyError?)
	if type(vehicleId) ~= "string" or #vehicleId == 0 or #vehicleId > config.VehicleIdMaxLength then
		return false, "InvalidVehicle"
	end
	local ok, err = precheck(profile, price, txId, config)
	if not ok then
		return false, err
	end
	if EconomyRules.ownsVehicle(profile, vehicleId) then
		return false, "AlreadyOwned"
	end
	if #profile.OwnedVehicles >= config.MaxOwnedVehicles then
		return false, "TooManyVehicles"
	end
	if not EconomyRules.canAfford(profile, price) then
		return false, "InsufficientFunds"
	end
	profile.Cash -= price
	table.insert(profile.OwnedVehicles, vehicleId)
	remember(profile, txId, config)
	return true, nil
end

-- Session lock: a server may claim a record when it is unlocked, already its own, or the
-- other server's lock is older than `timeout` seconds (that server crashed or hung).
function EconomyRules.canClaimLock(lock: any, sessionId: string, now: number, timeout: number): boolean
	if type(lock) ~= "table" or type(lock.Id) ~= "string" then
		return true
	end
	if lock.Id == sessionId then
		return true
	end
	return type(lock.At) ~= "number" or now - lock.At > timeout
end

return EconomyRules
```

## EconomyService (changed)
`src/ServerScriptService/Server/Services/EconomyService.luau`

```diff
diff --git a/src/ServerScriptService/Server/Services/EconomyService.luau b/src/ServerScriptService/Server/Services/EconomyService.luau
index 51bf17d..1d0f64d 100644
--- a/src/ServerScriptService/Server/Services/EconomyService.luau
+++ b/src/ServerScriptService/Server/Services/EconomyService.luau
@@ -1,18 +1,23 @@
 --!strict
--- The ONE place player cash changes. Server-authoritative balances, persisted in a DataStore.
+-- The ONE place player cash and vehicle ownership change. Server-authoritative, persisted in a
+-- DataStore.
 --  * Load on join with retries + exponential backoff and a session lock (ProfileStore).
---  * If loading fails, the player is marked "Unavailable": no cash changes, and NOTHING is
---    saved for them (so a DataStore outage can never overwrite real progress with defaults).
---    Loading is retried in the background until it succeeds.
---  * grant/deduct go through EconomyRules (whole positive amounts, caps, duplicate
---    transaction ids, insufficient funds). There is no client remote that changes cash.
---  * Autosave every AutosaveInterval for changed profiles; save + release on leave and on
---    server shutdown.
---  * If the save on leave fails, the profile is kept as an "orphan" and its save retried in
---    the background (and at shutdown), so cash already earned isn't silently dropped. A
---    player who rejoins this server before it saves gets that newer profile back.
--- Future systems (robbery rewards, vehicle purchases) call grant/deduct with their own
--- unique transaction ids, e.g. "robbery:<serverJob>:<n>", so retries can't pay twice.
+--  * If loading fails, the player is marked "Unavailable": no changes, and NOTHING is saved for
+--    them (so a DataStore outage can never overwrite real progress with defaults). Loading is
+--    retried in the background until it succeeds.
+--  * WRITE-THROUGH (audit remediation): every grant, deduction and purchase is applied to a copy
+--    of the profile and written with ProfileStore.commit BEFORE it takes effect. If the write
+--    fails, nothing changes and the caller gets "SaveFailed". So anything this service reports
+--    as done is already stored and survives a crash, a failed leave-save or another server
+--    taking the lock later.
+--  * Changes for one player are serialised (one commit or save at a time), so concurrent
+--    requests can't overwrite each other.
+--  * Earned rewards (grantReward) are first recorded in a separate reward ledger, then granted.
+--    If the grant can't be stored now, the ledger entry is paid on the player's next successful
+--    load on any server, exactly once (same transaction id).
+--  * Every loaded profile is re-saved every AutosaveInterval to refresh its session lock (a
+--    quiet session's lock must never go stale while the player is still here); saved and
+--    released on leave and on shutdown. A failed leave-save is retried in the background.
 local HttpService = game:GetService("HttpService")
 local Players = game:GetService("Players")
 local ReplicatedStorage = game:GetService("ReplicatedStorage")
@@ -26,6 +31,7 @@ local EconomyRules = require(Shared.Economy.EconomyRules)
 local PlayerAttributes = require(Shared.Player.PlayerAttributes)
 local Data = script.Parent.Parent.Data
 local ProfileStore = require(Data.ProfileStore)
+local RewardLedger = require(Data.RewardLedger)
 local DataStoreAdapter = require(Data.DataStoreAdapter)
 
 local EconomyService = {}
@@ -33,15 +39,16 @@ local EconomyService = {}
 type Session = {
 	Status: "Loading" | "Loaded" | "Unavailable",
 	Profile: Types.Profile?,
-	Dirty: boolean,
 	Key: string,
 	Leaving: boolean,
+	Busy: boolean, -- a commit or save is in progress for this player
 }
 
 local sessions: { [Player]: Session } = {}
 type Orphan = { Name: string, Profile: Types.Profile, Since: number }
 local orphans: { [string]: Orphan } = {} -- key -> profile whose save on leave failed
 local store: any
+local rewardStore: any
 -- A Studio playtest has no JobId; give each server a unique lock id either way.
 local sessionId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)
 
@@ -61,6 +68,80 @@ local function keyFor(player: Player): string
 	return `player_{player.UserId}`
 end
 
+local function rewardKeyFor(key: string): string
+	return `rewards_{key}`
+end
+
+-- Runs fn with this player's profile to itself: no other commit or save interleaves.
+local function withLock<T...>(session: Session, fn: () -> T...): T...
+	while session.Busy do
+		task.wait()
+	end
+	session.Busy = true
+	local results = table.pack(pcall(fn))
+	session.Busy = false
+	if not results[1] then
+		error(results[2], 0)
+	end
+	return table.unpack(results, 2, results.n)
+end
+
+-- Write-through commit for a loaded session. Returns (ok, err): rule errors pass through,
+-- store failures become "SaveFailed" (nothing applied). Losing the lock means another server
+-- owns this profile now, so this session stops writing.
+local function commit(player: Player, session: Session, label: string, mutate: (Types.Profile) -> (boolean, string?)): (boolean, Types.EconomyError?)
+	local profile = session.Profile :: Types.Profile
+	local lastErr: string? = nil
+	for attempt = 1, EconomyConfig.CommitAttempts do
+		local ok, err, detail = ProfileStore.commit(store, session.Key, sessionId, profile, os.time(), mutate)
+		if ok then
+			return true, nil
+		end
+		if err ~= "StoreError" and err ~= "LockLost" then
+			return false, err :: any -- refused by the rules: nothing to retry
+		end
+		lastErr = err
+		log(`{player.Name}: {label} write attempt {attempt} failed ({err}{if detail then ": " .. detail else ""})`)
+		if err == "LockLost" then
+			session.Status = "Unavailable"
+			publish(player, session)
+			warn(`[Economy] {player.Name}: another server owns this profile; this session stops changing it`)
+			break
+		end
+		if attempt < EconomyConfig.CommitAttempts then
+			task.wait(EconomyConfig.RetryBaseDelay * 2 ^ (attempt - 1))
+		end
+	end
+	log(`{player.Name}: {label} NOT applied ({lastErr}); nothing changed`)
+	return false, "SaveFailed"
+end
+
+-- Pays rewards recorded in the ledger (earned earlier, here or on another server, but not
+-- stored then). Runs once after each successful load; safe to repeat.
+local function claimRewards(player: Player, session: Session)
+	local rewards, listErr = RewardLedger.list(rewardStore, rewardKeyFor(session.Key))
+	if not rewards then
+		log(`{player.Name}: reward ledger unreadable ({listErr}); will retry on the next load`)
+		return
+	end
+	if #rewards == 0 then
+		return
+	end
+	local settled: { string } = {}
+	local ok = withLock(session, function()
+		local committed = commit(player, session, "claim rewards", function(draft)
+			settled = RewardLedger.applyAll(draft, rewards, EconomyConfig)
+			return true, nil
+		end)
+		return committed
+	end)
+	if ok then
+		publish(player, session)
+		log(`{player.Name}: paid {#settled} recorded reward(s) -> {(session.Profile :: Types.Profile).Cash}`)
+		RewardLedger.remove(rewardStore, rewardKeyFor(session.Key), settled)
+	end
+end
+
 local function tryLoad(player: Player, session: Session): boolean
 	for attempt = 1, EconomyConfig.LoadAttempts do
 		local profile, result, detail = ProfileStore.load(store, session.Key, sessionId, os.time(), EconomyConfig)
@@ -69,6 +150,7 @@ local function tryLoad(player: Player, session: Session): boolean
 			session.Status = "Loaded"
 			publish(player, session)
 			log(`{player.Name}: loaded ({result}) cash={profile.Cash}`)
+			task.spawn(claimRewards, player, session)
 			return true
 		end
 		log(`{player.Name}: load attempt {attempt} failed ({result}{if detail then ": " .. detail else ""})`)
@@ -119,17 +201,18 @@ local function saveProfile(name: string, key: string, profile: Types.Profile, re
 end
 
 local function save(player: Player, session: Session, release: boolean): boolean
-	if session.Status ~= "Loaded" or not session.Profile then
-		return false -- never write for a profile we didn't load
-	end
-	local ok = saveProfile(player.Name, session.Key, session.Profile :: Types.Profile, release, EconomyConfig.SaveAttempts)
-	if ok then
-		session.Dirty = false
-	end
-	return ok
+	return withLock(session, function()
+		if session.Status ~= "Loaded" or not session.Profile then
+			return false -- never write for a profile we didn't load
+		end
+		local ok = saveProfile(player.Name, session.Key, session.Profile :: Types.Profile, release, EconomyConfig.SaveAttempts)
+		return ok
+	end)
 end
 
--- Background retries for profiles whose save on leave failed.
+-- Background retries for profiles whose save on leave failed. Since every cash change is
+-- already stored when it happens, this only refreshes/releases the lock; nothing acknowledged
+-- depends on it.
 local function retryOrphan(key: string, orphan: Orphan)
 	while orphans[key] == orphan do
 		task.wait(EconomyConfig.OrphanRetryInterval)
@@ -142,40 +225,52 @@ local function retryOrphan(key: string, orphan: Orphan)
 			log(`{orphan.Name}: saved after leaving (cash={orphan.Profile.Cash})`)
 		elseif lockLost then
 			orphans[key] = nil
-			warn(`[Economy] {orphan.Name}: another server owns this profile now; unsaved changes dropped (cash={orphan.Profile.Cash})`)
+			log(`{orphan.Name}: another server owns this profile now; nothing to release`)
 		elseif os.clock() - orphan.Since > EconomyConfig.OrphanRetryLimit then
 			orphans[key] = nil
-			warn(`[Economy] {orphan.Name}: gave up saving after {EconomyConfig.OrphanRetryLimit}s; unsaved cash={orphan.Profile.Cash}`)
+			warn(`[Economy] {orphan.Name}: gave up releasing the lock after {EconomyConfig.OrphanRetryLimit}s (it expires by itself)`)
 		end
 	end
 end
 
-local function change(player: Player, kind: "grant" | "deduct", amount: any, txId: any, reason: string): (boolean, Types.EconomyError?)
+local function loadedSession(player: Player): (Session?, Types.EconomyError?)
 	local session = sessions[player]
 	if not session or player.Parent ~= Players then
-		return false, "NotInGame"
+		return nil, "NotInGame"
 	end
 	if session.Status ~= "Loaded" or not session.Profile then
-		return false, "DataNotLoaded"
+		return nil, "DataNotLoaded"
 	end
-	local profile = session.Profile :: Types.Profile
-	local ok, err
-	if kind == "grant" then
-		ok, err = EconomyRules.grant(profile, amount, txId, EconomyConfig)
-	else
-		ok, err = EconomyRules.deduct(profile, amount, txId, EconomyConfig)
+	return session, nil
+end
+
+local function change(player: Player, kind: "grant" | "deduct", amount: any, txId: any, reason: string): (boolean, Types.EconomyError?)
+	local session, err = loadedSession(player)
+	if not session then
+		return false, err
 	end
+	local ok, changeErr = withLock(session, function()
+		if session.Status ~= "Loaded" then
+			return false, "DataNotLoaded" :: Types.EconomyError?
+		end
+		return commit(player, session, `{kind} {tostring(amount)}`, function(draft)
+			if kind == "grant" then
+				return EconomyRules.grant(draft, amount, txId, EconomyConfig)
+			end
+			return EconomyRules.deduct(draft, amount, txId, EconomyConfig)
+		end)
+	end)
 	if ok then
-		session.Dirty = true
 		publish(player, session)
-		log(`{player.Name}: {kind} {amount} ({reason}, tx {txId}) -> {profile.Cash}`)
+		log(`{player.Name}: {kind} {amount} ({reason}, tx {txId}) -> {(session.Profile :: Types.Profile).Cash} (stored)`)
 	else
-		log(`{player.Name}: {kind} {tostring(amount)} refused: {err} ({reason}, tx {tostring(txId)})`)
+		log(`{player.Name}: {kind} {tostring(amount)} refused: {changeErr} ({reason}, tx {tostring(txId)})`)
 	end
-	return ok, err
+	return ok, changeErr
 end
 
--- Server-only API. txId must be unique per real-world event; repeats are refused.
+-- Server-only API. txId must be unique per real-world event; repeats are refused. Returns true
+-- only once the change is stored.
 function EconomyService.grant(player: Player, amount: number, txId: string, reason: string): (boolean, Types.EconomyError?)
 	return change(player, "grant", amount, txId, reason)
 end
@@ -184,6 +279,23 @@ function EconomyService.deduct(player: Player, amount: number, txId: string, rea
 	return change(player, "deduct", amount, txId, reason)
 end
 
+-- A reward the player has EARNED (robbery payout). Recorded in the reward ledger first, then
+-- granted write-through. Returns (paid, err, recorded): if not paid but recorded, the reward
+-- will be paid on the player's next successful load (any server), never twice.
+function EconomyService.grantReward(player: Player, amount: number, txId: string, reason: string): (boolean, Types.EconomyError?, boolean)
+	local recorded, recordErr = RewardLedger.record(rewardStore, rewardKeyFor(keyFor(player)), { TxId = txId, Amount = amount, Reason = reason, At = os.time() })
+	if not recorded then
+		log(`{player.Name}: reward {txId} could not be recorded in the ledger ({recordErr})`)
+	end
+	local paid, err = change(player, "grant", amount, txId, reason)
+	if paid or err == "DuplicateTransaction" then
+		-- Settled now (or earlier): clear it from the ledger. If this fails, the next load's
+		-- claim finds it already paid (duplicate tx) and clears it then.
+		RewardLedger.remove(rewardStore, rewardKeyFor(keyFor(player)), { txId })
+	end
+	return paid, err, recorded
+end
+
 function EconomyService.getBalance(player: Player): number?
 	local session = sessions[player]
 	return if session and session.Status == "Loaded" and session.Profile then session.Profile.Cash else nil
@@ -209,31 +321,29 @@ function EconomyService.ownsVehicle(player: Player, vehicleId: string): boolean
 	return session ~= nil and session.Status == "Loaded" and session.Profile ~= nil and EconomyRules.ownsVehicle(session.Profile, vehicleId)
 end
 
--- Server-only purchase: price and ownership change together on the profile, then it is saved
--- right away (and again by autosave/leave if that save fails; both always travel together).
+-- Server-only purchase: the price and the ownership are applied together to a profile copy and
+-- stored in one write; only then does the purchase take effect and return true. A failed write
+-- returns "SaveFailed" with nothing charged and no car.
 function EconomyService.purchaseVehicle(player: Player, vehicleId: string, price: number, txId: string): (boolean, Types.EconomyError?)
-	local session = sessions[player]
-	if not session or player.Parent ~= Players then
-		return false, "NotInGame"
-	end
-	if session.Status ~= "Loaded" or not session.Profile then
-		return false, "DataNotLoaded"
-	end
-	local profile = session.Profile :: Types.Profile
-	local ok, err = EconomyRules.purchaseVehicle(profile, vehicleId, price, txId, EconomyConfig)
-	if not ok then
-		log(`{player.Name}: purchase {tostring(vehicleId)} for {tostring(price)} refused: {err} (tx {tostring(txId)})`)
+	local session, err = loadedSession(player)
+	if not session then
 		return false, err
 	end
-	session.Dirty = true
-	publish(player, session)
-	log(`{player.Name}: bought {vehicleId} for {price} (tx {txId}) -> cash {profile.Cash}`)
-	task.spawn(function()
-		if save(player, session, false) then
-			log(`{player.Name}: purchase saved`)
+	local ok, buyErr = withLock(session, function()
+		if session.Status ~= "Loaded" then
+			return false, "DataNotLoaded" :: Types.EconomyError?
 		end
+		return commit(player, session, `purchase {tostring(vehicleId)}`, function(draft)
+			return EconomyRules.purchaseVehicle(draft, vehicleId, price, txId, EconomyConfig)
+		end)
 	end)
-	return true, nil
+	if ok then
+		publish(player, session)
+		log(`{player.Name}: bought {vehicleId} for {price} (tx {txId}) -> cash {(session.Profile :: Types.Profile).Cash} (stored)`)
+	else
+		log(`{player.Name}: purchase {tostring(vehicleId)} for {tostring(price)} refused: {buyErr} (tx {tostring(txId)})`)
+	end
+	return ok, buyErr
 end
 
 -- Unique transaction id helper for server systems.
@@ -285,18 +395,18 @@ function EconomyService.writeLegacyRecordForTesting(player: Player): boolean
 end
 
 local function onPlayerAdded(player: Player)
-	local session: Session = { Status = "Loading", Profile = nil, Dirty = false, Key = keyFor(player), Leaving = false }
+	local session: Session = { Status = "Loading", Profile = nil, Key = keyFor(player), Leaving = false, Busy = false }
 	sessions[player] = session
 	local orphan = orphans[session.Key]
 	if orphan then
-		-- Rejoined this server before its unsaved profile was written: that copy is the newest
-		-- data and this server still holds the lock, so use it instead of the stored record.
+		-- Rejoined this server before its leave-save went through: this server still holds the
+		-- lock and the copy matches what was stored by the write-through commits.
 		orphans[session.Key] = nil
 		session.Profile = orphan.Profile
 		session.Status = "Loaded"
-		session.Dirty = true
 		publish(player, session)
-		log(`{player.Name}: rejoined; using the unsaved profile kept on this server (cash={orphan.Profile.Cash})`)
+		log(`{player.Name}: rejoined; using the profile kept on this server (cash={orphan.Profile.Cash})`)
+		task.spawn(claimRewards, player, session)
 		return
 	end
 	publish(player, session)
@@ -316,7 +426,7 @@ local function onPlayerRemoving(player: Player)
 		elseif sessions[player] == session then
 			local orphan: Orphan = { Name = player.Name, Profile = profile, Since = os.clock() }
 			orphans[session.Key] = orphan
-			warn(`[Economy] {player.Name}: save on leave failed; keeping the profile and retrying (cash={profile.Cash})`)
+			warn(`[Economy] {player.Name}: save on leave failed; retrying in the background (every change was already stored when it happened)`)
 			task.spawn(retryOrphan, session.Key, orphan)
 		end
 	else
@@ -327,6 +437,7 @@ end
 
 function EconomyService.init()
 	store = DataStoreAdapter.get(EconomyConfig.DataStoreName)
+	rewardStore = DataStoreAdapter.get(EconomyConfig.RewardStoreName)
 	if RunService:IsStudio() and Workspace:GetAttribute("SimulateDataStoreFailureOnStart") == true then
 		DataStoreAdapter.setSimulatedFailure(true)
 		log("Studio test: simulating DataStore failure from server start")
@@ -365,11 +476,13 @@ function EconomyService.start()
 			task.wait(0.1)
 		end
 	end)
+	-- Lock heartbeat: re-save every loaded profile so its session lock stays fresh while the
+	-- player is here (a lock older than SessionLockTimeout could be claimed by another server).
 	task.spawn(function()
 		while true do
 			task.wait(EconomyConfig.AutosaveInterval)
 			for player, session in sessions do
-				if session.Dirty and not session.Leaving then
+				if session.Status == "Loaded" and not session.Leaving then
 					task.spawn(save, player, session, false)
 				end
 			end
```

## ProfileStore (changed)
`src/ServerScriptService/Server/Data/ProfileStore.luau`

```diff
diff --git a/src/ServerScriptService/Server/Data/ProfileStore.luau b/src/ServerScriptService/Server/Data/ProfileStore.luau
index 9b1cba2..56da08a 100644
--- a/src/ServerScriptService/Server/Data/ProfileStore.luau
+++ b/src/ServerScriptService/Server/Data/ProfileStore.luau
@@ -49,6 +49,45 @@ function ProfileStore.load(store: Store, key: string, sessionId: string, now: nu
 	return profile, outcome :: any, nil
 end
 
+local function copyProfile(profile: Types.Profile): Types.Profile
+	return {
+		Version = profile.Version,
+		Cash = profile.Cash,
+		RecentTransactions = table.clone(profile.RecentTransactions),
+		OwnedVehicles = table.clone(profile.OwnedVehicles),
+	}
+end
+
+-- Write-through change (audit remediation): applies `mutate` to a COPY of `profile`, writes
+-- that copy in one UpdateAsync while this session owns the lock, and only then copies it into
+-- `profile`. If the rule refuses or the write fails, `profile` is left exactly as it was, so a
+-- change the caller acknowledges is always already stored. Callers must serialise commits for
+-- one profile (EconomyService does, per player).
+-- Returns (ok, err, detail): err is the rule's error, "StoreError" or "LockLost".
+function ProfileStore.commit(
+	store: Store,
+	key: string,
+	sessionId: string,
+	profile: Types.Profile,
+	now: number,
+	mutate: (Types.Profile) -> (boolean, string?)
+): (boolean, string?, string?)
+	local draft = copyProfile(profile)
+	local ok, err = mutate(draft)
+	if not ok then
+		return false, err, nil
+	end
+	local saved, saveErr, detail = ProfileStore.save(store, key, sessionId, draft, now, false)
+	if not saved then
+		return false, saveErr, detail
+	end
+	profile.Version = draft.Version
+	profile.Cash = draft.Cash
+	profile.RecentTransactions = draft.RecentTransactions
+	profile.OwnedVehicles = draft.OwnedVehicles
+	return true, nil, nil
+end
+
 -- Writes the profile if this session still owns the lock. `release` drops the lock (leaving).
 function ProfileStore.save(store: Store, key: string, sessionId: string, profile: Types.Profile, now: number, release: boolean): (boolean, SaveError?, string?)
 	local owned = false
```

## RewardLedger (new) (changed)
`src/ServerScriptService/Server/Data/RewardLedger.luau`

```diff
diff --git a/src/ServerScriptService/Server/Data/RewardLedger.luau b/src/ServerScriptService/Server/Data/RewardLedger.luau
new file mode 100644
index 0000000..12317a6
--- /dev/null
+++ b/src/ServerScriptService/Server/Data/RewardLedger.luau
@@ -0,0 +1,100 @@
+--!strict
+-- Durable record of earned-but-unpaid rewards (audit remediation). Kept in its OWN DataStore
+-- (EconomyConfig.RewardStoreName), separate from the player profile, so a reward survives a
+-- failed profile save, a disconnect or a server crash. Each entry carries the reward's stable
+-- transaction id, so paying it later (on any server, on the player's next load) can never pay
+-- twice: the profile's duplicate-transaction guard refuses a second grant.
+-- Record: { Rewards = { { TxId: string, Amount: number, Reason: string, At: number } } }
+-- Unit-tested with a fake store in ServerStorage.Tests.RewardLedger.spec.
+local ReplicatedStorage = game:GetService("ReplicatedStorage")
+local Types = require(ReplicatedStorage.Shared.Types)
+local EconomyRules = require(ReplicatedStorage.Shared.Economy.EconomyRules)
+
+local RewardLedger = {}
+
+export type Reward = { TxId: string, Amount: number, Reason: string, At: number }
+export type Store = { UpdateAsync: (self: any, key: string, transform: (any) -> any) -> any }
+
+local MAX_ENTRIES = 50
+
+local function entriesOf(record: any): { Reward }
+	local list = {}
+	if type(record) == "table" and type(record.Rewards) == "table" then
+		for _, r in record.Rewards do
+			if type(r) == "table" and type(r.TxId) == "string" and type(r.Amount) == "number" then
+				table.insert(list, { TxId = r.TxId, Amount = r.Amount, Reason = tostring(r.Reason or ""), At = tonumber(r.At) or 0 })
+			end
+		end
+	end
+	return list
+end
+
+-- Adds a reward (no-op if its TxId is already recorded). Returns (ok, err?).
+function RewardLedger.record(store: Store, key: string, reward: Reward): (boolean, string?)
+	local ok, err = pcall(function()
+		store:UpdateAsync(key, function(old: any)
+			local list = entriesOf(old)
+			for _, r in list do
+				if r.TxId == reward.TxId then
+					return nil -- already recorded: leave untouched
+				end
+			end
+			if #list >= MAX_ENTRIES then
+				error("reward ledger full")
+			end
+			table.insert(list, reward)
+			return { Rewards = list }
+		end)
+	end)
+	return ok, if ok then nil else tostring(err)
+end
+
+-- Reads the outstanding rewards without changing them. Returns (rewards?, err?).
+function RewardLedger.list(store: Store, key: string): ({ Reward }?, string?)
+	local result: { Reward }? = nil
+	local ok, err = pcall(function()
+		store:UpdateAsync(key, function(old: any)
+			result = entriesOf(old)
+			return nil -- read only
+		end)
+	end)
+	if not ok then
+		return nil, tostring(err)
+	end
+	return result or {}, nil
+end
+
+-- Removes settled rewards by TxId. Returns (ok, err?).
+function RewardLedger.remove(store: Store, key: string, txIds: { string }): (boolean, string?)
+	local ok, err = pcall(function()
+		store:UpdateAsync(key, function(old: any)
+			local list = entriesOf(old)
+			local kept = {}
+			for _, r in list do
+				if not table.find(txIds, r.TxId) then
+					table.insert(kept, r)
+				end
+			end
+			if #kept == #list then
+				return nil
+			end
+			return { Rewards = kept }
+		end)
+	end)
+	return ok, if ok then nil else tostring(err)
+end
+
+-- Applies every outstanding reward to `draft` (a profile copy inside ProfileStore.commit).
+-- Already-paid ones (duplicate tx) are skipped. Returns the TxIds that are now settled.
+function RewardLedger.applyAll(draft: Types.Profile, rewards: { Reward }, config: any): { string }
+	local settled = {}
+	for _, r in rewards do
+		local ok, err = EconomyRules.grant(draft, r.Amount, r.TxId, config)
+		if ok or err == "DuplicateTransaction" then
+			table.insert(settled, r.TxId)
+		end
+	end
+	return settled
+end
+
+return RewardLedger
```

## DealershipService (unchanged in this range: full current source)
`src/ServerScriptService/Server/Services/DealershipService.luau`

```lua
--!strict
-- Server authority for the dealership (Phase 4C). The client's shop window only asks
-- RequestPurchaseVehicle(vehicleId); this service checks everything on the server:
-- known catalogue car (price from DealershipConfig, never the client), one request at a time
-- per player plus a rate limit, alive, not jailed, standing at the sales desk, and then
-- EconomyService.purchaseVehicle takes the price and records ownership in one step with a
-- fresh server transaction id. Owning the car already refuses a second charge.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Remotes = require(Shared.Net.Remotes)
local DealershipConfig = require(Shared.Config.DealershipConfig)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local RateLimiter = require(script.Parent.Parent.Util.RateLimiter)
local WorldService = require(script.Parent.WorldService)
local JailService = require(script.Parent.JailService)
local EconomyService = require(script.Parent.EconomyService)

local DealershipService = {}

local desk: BasePart? = nil
local limiter = RateLimiter.new(DealershipConfig.RequestInterval)
local inFlight: { [Player]: boolean } = {}

local function purchase(player: Player, vehicleId: unknown): (boolean, Types.PurchaseError?)
	if typeof(vehicleId) ~= "string" or #vehicleId == 0 or #vehicleId > EconomyConfig.VehicleIdMaxLength then
		return false, "BadRequest"
	end
	local price = DealershipConfig.priceOf(vehicleId)
	if not price then
		return false, "NotForSale"
	end
	if inFlight[player] then
		return false, "Busy"
	end
	if not limiter:tryConsume(player.UserId) then
		return false, "Cooldown"
	end
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not humanoid or humanoid.Health <= 0 or not root or not root:IsA("BasePart") then
		return false, "NotAlive"
	end
	if JailService.isJailed(player) then
		return false, "Jailed"
	end
	if not desk or (root.Position - desk.Position).Magnitude > DealershipConfig.InteractDistance + DealershipConfig.DistanceSlack then
		return false, "TooFar"
	end
	inFlight[player] = true
	local ok, err = EconomyService.purchaseVehicle(player, vehicleId, price, EconomyService.newTransactionId("buy:" .. vehicleId))
	inFlight[player] = nil
	return ok, err
end

function DealershipService.init()
	local folder = WorldService.getDealership()
	local part = folder and folder:FindFirstChild("DealerDesk")
	if part and part:IsA("BasePart") then
		desk = part
	else
		warn("[Dealership] no City.Dealership desk; purchases disabled")
	end
	Remotes.getFunction("RequestPurchaseVehicle").OnServerInvoke = purchase
end

function DealershipService.start()
	Players.PlayerRemoving:Connect(function(player)
		inFlight[player] = nil
		limiter:reset(player.UserId)
	end)
end

return DealershipService
```

## VehicleService (unchanged in this range: full current source)
`src/ServerScriptService/Server/Services/VehicleService.luau`

```lua
--!strict
-- Server authority for vehicles: spawning, seating, exiting, network ownership and cleanup.
-- Physics is simulated by one client per vehicle (the driver, else the owner); the server
-- decides who that is and publishes it in the "SimulatedBy" attribute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local Types = require(Shared.Types)
local VehicleConfig = require(Shared.Config.VehicleConfig)
local Server = script.Parent.Parent
local VehicleFactory = require(Server.Vehicle.VehicleFactory)
local RateLimiter = require(Server.Util.RateLimiter)
local WorldService = require(script.Parent.WorldService)
local JailService = require(script.Parent.JailService)
local EconomyService = require(script.Parent.EconomyService)

local VehicleService = {}

local SPAWN_COOLDOWN = 3
local EXIT_COOLDOWN = 0.5
local MAX_VEHICLE_ID_LENGTH = 32
local PROMPT_SLACK = 6 -- extra studs allowed beyond the prompt range for latency
local SPAWN_CLEARANCE = Vector3.new(10, 8, 16)
local SPAWN_DROP = 0.5

local vehiclesFolder: Folder
local vehicleByOwner: { [number]: Model } = {}
local spawnLimiter = RateLimiter.new(SPAWN_COOLDOWN)
local exitLimiter = RateLimiter.new(EXIT_COOLDOWN)

local function getLiveHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function getSeat(vehicle: Model): Seat?
	return vehicle:FindFirstChild("DriverSeat") :: Seat?
end

-- Driver simulates; otherwise the owner (so a parked car still rests on its springs); else the server.
local function updateSimulation(vehicle: Model)
	local chassis = vehicle.PrimaryPart
	local seat = getSeat(vehicle)
	if not chassis or not seat or not vehicle:IsDescendantOf(Workspace) then
		return
	end
	local occupant = seat.Occupant
	local driver = if occupant then Players:GetPlayerFromCharacter(occupant.Parent) else nil
	if driver and occupant and not JailService.allows(driver, "Drive") then
		-- A jailed player can never hold a driver seat (e.g. touch-sitting); eject them.
		local weld = seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		occupant.Sit = false
		driver = nil
		occupant = nil
	end
	local owner = Players:GetPlayerByUserId(vehicle:GetAttribute("OwnerUserId") :: number)
	local simulator = driver or owner
	chassis:SetNetworkOwner(simulator)
	vehicle:SetAttribute("SimulatedBy", if simulator then simulator.UserId else 0)
	vehicle:SetAttribute("DriverUserId", if driver then driver.UserId else 0)
	local prompt = seat:FindFirstChild("DrivePrompt") :: ProximityPrompt?
	if prompt then
		prompt.Enabled = occupant == nil
	end
end

local function despawnOwnedVehicle(userId: number)
	local vehicle = vehicleByOwner[userId]
	vehicleByOwner[userId] = nil
	if vehicle then
		vehicle:Destroy()
	end
end

local function findFreeSpawn(nearPosition: Vector3): CFrame?
	local candidates = WorldService.getVehicleSpawnCFrames()
	table.sort(candidates, function(a, b)
		return (a.Position - nearPosition).Magnitude < (b.Position - nearPosition).Magnitude
	end)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { vehiclesFolder }
	for _, cframe in candidates do
		local box = cframe + Vector3.new(0, SPAWN_CLEARANCE.Y / 2, 0)
		if #Workspace:GetPartBoundsInBox(box, SPAWN_CLEARANCE, params) == 0 then
			return cframe
		end
	end
	return nil
end

local function sitIfFree(player: Player, vehicle: Model)
	local seat = getSeat(vehicle)
	local humanoid = getLiveHumanoid(player)
	if not seat or not humanoid or seat.Occupant or humanoid.SeatPart or not JailService.allows(player, "Drive") then
		return
	end
	local root = humanoid.RootPart
	local prompt = seat:FindFirstChild("DrivePrompt") :: ProximityPrompt?
	local range = (if prompt then prompt.MaxActivationDistance else 12) + PROMPT_SLACK
	if not root or (root.Position - seat.Position).Magnitude > range then
		return
	end
	seat:Sit(humanoid)
end

local function spawnVehicle(player: Player, vehicleId: string): (boolean, Types.SpawnError?)
	local stats = VehicleConfig.get(vehicleId)
	if not stats or stats.PlayerSpawnable == false then
		return false, "UnknownVehicle"
	end
	if not EconomyService.ownsVehicle(player, vehicleId) then
		return false, "NotOwned" -- the server's profile decides, never the client
	end
	if not JailService.allows(player, "SpawnVehicle") then
		return false, "Jailed"
	end
	local humanoid = getLiveHumanoid(player)
	local root = humanoid and humanoid.RootPart
	if not humanoid or not root then
		return false, "NotAlive"
	end
	if not spawnLimiter:tryConsume(player.UserId) then
		return false, "Cooldown"
	end

	despawnOwnedVehicle(player.UserId)
	local spawnCFrame = findFreeSpawn(root.Position)
	if not spawnCFrame then
		spawnLimiter:reset(player.UserId)
		return false, "NoFreeSpawn"
	end

	local vehicle = VehicleFactory.build(vehicleId, stats)
	vehicle.Name = `{vehicleId}_{player.UserId}`
	vehicle:SetAttribute("OwnerUserId", player.UserId)
	vehicle:PivotTo(spawnCFrame * CFrame.new(0, VehicleFactory.getRideHeight(stats) + SPAWN_DROP, 0))
	vehicle.Parent = vehiclesFolder
	vehicleByOwner[player.UserId] = vehicle

	local seat = getSeat(vehicle)
	assert(seat, "vehicle has no DriverSeat")
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		updateSimulation(vehicle)
	end)
	local prompt = seat:FindFirstChild("DrivePrompt") :: ProximityPrompt?
	if prompt then
		prompt.Triggered:Connect(function(who: Player)
			sitIfFree(who, vehicle)
		end)
	end
	updateSimulation(vehicle)
	seat:Sit(humanoid)
	return true, nil
end

local function exitVehicle(player: Player)
	if not exitLimiter:tryConsume(player.UserId) then
		return
	end
	local humanoid = getLiveHumanoid(player)
	local seat = humanoid and humanoid.SeatPart
	if not humanoid or not seat or seat.Name ~= "DriverSeat" or not seat:IsDescendantOf(vehiclesFolder) then
		return
	end
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	humanoid.Sit = false
	local character = player.Character
	if character then
		local exitCFrame = seat.CFrame * CFrame.new(-4.5, 2, 0)
		character:PivotTo(CFrame.new(exitCFrame.Position) * seat.CFrame.Rotation)
	end
end

function VehicleService.init()
	local existing = Workspace:FindFirstChild("Vehicles")
	if existing then
		existing:Destroy()
	end
	vehiclesFolder = Instance.new("Folder")
	vehiclesFolder.Name = "Vehicles"
	vehiclesFolder.Parent = Workspace

	Remotes.getFunction("RequestSpawnVehicle").OnServerInvoke = function(player: Player, vehicleId: unknown)
		if typeof(vehicleId) ~= "string" or #vehicleId == 0 or #vehicleId > MAX_VEHICLE_ID_LENGTH then
			return false, "BadRequest"
		end
		return spawnVehicle(player, vehicleId)
	end
	Remotes.getEvent("RequestExitVehicle").OnServerEvent:Connect(exitVehicle)
end

function VehicleService.start()
	Players.PlayerRemoving:Connect(function(player)
		despawnOwnedVehicle(player.UserId)
		spawnLimiter:reset(player.UserId)
		exitLimiter:reset(player.UserId)
		-- Anyone they were driving falls back to its owner.
		for _, vehicle in vehiclesFolder:GetChildren() do
			if vehicle:IsA("Model") and vehicle:GetAttribute("SimulatedBy") == player.UserId then
				task.defer(updateSimulation, vehicle)
			end
		end
	end)
end

function VehicleService.getVehicleOf(player: Player): Model?
	return vehicleByOwner[player.UserId]
end

return VehicleService
```

## RobberyService (changed)
`src/ServerScriptService/Server/Services/RobberyService.luau`

```diff
diff --git a/src/ServerScriptService/Server/Services/RobberyService.luau b/src/ServerScriptService/Server/Services/RobberyService.luau
index b25cfe3..48e92ba 100644
--- a/src/ServerScriptService/Server/Services/RobberyService.luau
+++ b/src/ServerScriptService/Server/Services/RobberyService.luau
@@ -39,7 +39,7 @@ type Store = {
 	Area: BasePart,
 }
 type Live = { Session: RobberyRules.Session, Character: Model, LastInProgressReport: number }
-type Pending = { TxId: string, Amount: number, SessionId: string, StoreId: string, NextTry: number }
+type Pending = { TxId: string, Amount: number, SessionId: string, StoreId: string, NextTry: number, InFlight: boolean, Recorded: boolean }
 
 local stores: { [string]: Store } = {}
 local live: { [Player]: Live } = {}
@@ -184,6 +184,8 @@ local function onEscaped(player: Player)
 		SessionId = session.Id,
 		StoreId = session.StoreId,
 		NextTry = 0,
+		InFlight = false,
+		Recorded = false,
 	}
 	RobberyService.tryPayout(player)
 end
@@ -191,17 +193,21 @@ end
 -- One payout attempt for a pending reward. Returns the outcome (nil if nothing pending).
 function RobberyService.tryPayout(player: Player): Types.PayoutOutcome?
 	local pending = pendingPayouts[player]
-	if not pending then
+	if not pending or pending.InFlight then
 		return nil
 	end
-	local ok, err = EconomyService.grant(player, pending.Amount, pending.TxId, "store robbery " .. pending.StoreId)
+	-- Recorded in the durable reward ledger first, then granted write-through (EconomyService).
+	pending.InFlight = true
+	local ok, err, recorded = EconomyService.grantReward(player, pending.Amount, pending.TxId, "store robbery " .. pending.StoreId)
+	pending.InFlight = false
+	pending.Recorded = pending.Recorded or recorded
 	local outcome = RobberyRules.payoutOutcome(ok, err)
 	if outcome == "Retry" then
 		if pending.NextTry == 0 then
 			player:SetAttribute(PlayerAttributes.RobberyPhase, "PayoutPending")
 			player:SetAttribute(PlayerAttributes.RobberyReward, pending.Amount)
-			notify(player, "PayoutPending", { Id = pending.SessionId, Amount = pending.Amount })
-			warn(`[Robbery] {player.Name} {pending.SessionId} payout pending ({tostring(err)}); retrying`)
+			notify(player, "PayoutPending", { Id = pending.SessionId, Amount = pending.Amount, Recorded = pending.Recorded })
+			warn(`[Robbery] {player.Name} {pending.SessionId} payout pending ({tostring(err)}; recorded in ledger: {pending.Recorded}); retrying`)
 		end
 		pending.NextTry = now() + PAYOUT_RETRY_SECONDS
 		return outcome
@@ -262,9 +268,13 @@ function RobberyService.start()
 		local pending = pendingPayouts[player]
 		if pending then
 			pendingPayouts[player] = nil
-			-- Only reachable if cash data was lost mid-session and never came back; the player
-			-- was told the reward is pending and to stay in the game.
-			warn(`[Robbery] {player.Name} left with an unpaid reward {pending.Amount} ({pending.TxId}); not recorded`)
+			if pending.Recorded then
+				-- Durable: the reward ledger pays it on the player's next successful load.
+				print(`[Robbery] {player.Name} left before {pending.TxId} could be stored; it is in the reward ledger and will be paid on their next join`)
+			else
+				-- Only if BOTH the profile and the ledger writes failed for the whole time.
+				warn(`[Robbery] {player.Name} left with an unpaid reward {pending.Amount} ({pending.TxId}) that could not be recorded anywhere`)
+			end
 		end
 		local entry = live[player]
 		if entry then
@@ -281,8 +291,8 @@ function RobberyService.start()
 			tick()
 			local t = now()
 			for player, pending in pendingPayouts do
-				if player.Parent == Players and t >= pending.NextTry then
-					RobberyService.tryPayout(player)
+				if player.Parent == Players and t >= pending.NextTry and not pending.InFlight then
+					task.spawn(RobberyService.tryPayout, player) -- writes yield; keep the tick loop running
 				end
 			end
 		end
```

## RobberyRules (changed)
`src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau`

```diff
diff --git a/src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau b/src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau
index 13aff00..61c6b63 100644
--- a/src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau
+++ b/src/ReplicatedStorage/Shared/Robbery/RobberyRules.luau
@@ -152,8 +152,8 @@ function RobberyRules.payoutOutcome(ok: boolean, err: string?): Types.PayoutOutc
 		return "Paid"
 	elseif err == "DuplicateTransaction" then
 		return "AlreadyPaid"
-	elseif err == "DataNotLoaded" then
-		return "Retry"
+	elseif err == "DataNotLoaded" or err == "SaveFailed" then
+		return "Retry" -- temporary: the data isn't loaded, or the write didn't go through
 	end
 	return "Rejected"
 end
```

## PoliceConfig (changed)
`src/ServerScriptService/Server/Police/PoliceConfig.luau`

```diff
diff --git a/src/ServerScriptService/Server/Police/PoliceConfig.luau b/src/ServerScriptService/Server/Police/PoliceConfig.luau
index 5b4987c..7a4287c 100644
--- a/src/ServerScriptService/Server/Police/PoliceConfig.luau
+++ b/src/ServerScriptService/Server/Police/PoliceConfig.luau
@@ -10,12 +10,15 @@ local PoliceConfig = {
 	LostTargetSeconds = 10,
 
 	-- Perception
-	SightRange = 160, -- studs; plus a clear line of sight
+	-- Audit remediation, EXPERIMENTAL pursuit tuning (owner/auditor review pending):
+	-- SightRange 160 -> 130, ChaseSpeed 110 -> 100, ChaseGain 1.0 -> 0.25. Baseline values in
+	-- the comments; WantedConfig.DecayDelay stays 8 s.
+	SightRange = 130, -- studs; plus a clear line of sight (baseline 160)
 	DirectChaseRange = 90, -- within this and in sight, drive straight at the target
 
 	-- Driving (studs/s, studs, radians)
 	CruiseSpeed = 95,
-	ChaseSpeed = 110,
+	ChaseSpeed = 100, -- baseline 110
 	CornerSpeedMin = 30,
 	CornerDecel = 1.1, -- allowed speed grows by this per stud of distance before a corner
 	WaypointRadius = 16,
@@ -27,7 +30,7 @@ local PoliceConfig = {
 	ReplanInterval = 1,
 	ChaseLookAhead = 0.5, -- seconds of target velocity to lead by in direct chase
 	ChaseFollowDistance = 10, -- gap the chase-speed rule closes down to
-	ChaseGain = 1.0, -- extra studs/s per stud of gap beyond the follow distance
+	ChaseGain = 0.25, -- extra studs/s per stud of gap beyond the follow distance (baseline 1.0)
 
 	-- Stuck handling
 	StuckSpeed = 3,
```

## PoliceDriveRules (unchanged in this range: full current source)
`src/ServerScriptService/Server/Police/PoliceDriveRules.luau`

```lua
--!strict
-- Pure NPC driving decisions: steering toward a point, corner speed, throttle, and the
-- stuck-detection state machine. No Instances. Unit-tested in PoliceNavigation.spec.
local PoliceDriveRules = {}

export type StuckState = { StuckTime: number, ReverseTimeLeft: number, Recoveries: { number } }
export type StuckAction = "Drive" | "Reverse" | "HardRecover"

-- localTarget is in the chassis frame (forward = -Z). Returns (steer -1..1, headingError rad).
function PoliceDriveRules.steerToward(localTarget: Vector3, maxSteerAngle: number): (number, number)
	local angle = math.atan2(localTarget.X, -localTarget.Z)
	return math.clamp(angle / maxSteerAngle, -1, 1), angle
end

-- Turn angle at b when driving a -> b -> c, in radians (0 = straight, pi = U-turn), XZ only.
function PoliceDriveRules.cornerAngle(a: Vector3, b: Vector3, c: Vector3): number
	local u = Vector3.new(b.X - a.X, 0, b.Z - a.Z)
	local v = Vector3.new(c.X - b.X, 0, c.Z - b.Z)
	if u.Magnitude < 1e-3 or v.Magnitude < 1e-3 then
		return 0
	end
	return math.acos(math.clamp(u.Unit:Dot(v.Unit), -1, 1))
end

-- Desired speed given the distance to the next corner, how sharp it is, and how far the car
-- is currently pointing away from its target.
function PoliceDriveRules.targetSpeed(
	distanceToCorner: number,
	cornerAngle: number,
	headingError: number,
	cruiseSpeed: number,
	config: { CornerSpeedMin: number, CornerDecel: number }
): number
	local sharpness = math.clamp(cornerAngle / (math.pi / 2), 0, 1)
	local cornerSpeed = config.CornerSpeedMin + (cruiseSpeed - config.CornerSpeedMin) * (1 - sharpness)
	local speed = math.min(cruiseSpeed, cornerSpeed + math.max(distanceToCorner, 0) * config.CornerDecel)
	if math.abs(headingError) > math.rad(60) then
		speed = math.min(speed, config.CornerSpeedMin)
	end
	return speed
end

-- Speed for following a moving target: match its speed, plus a closing term for the gap
-- beyond `followDistance`; never negative, never above `maxSpeed`.
function PoliceDriveRules.chaseSpeed(targetSpeed: number, gap: number, followDistance: number, gain: number, maxSpeed: number): number
	return math.clamp(targetSpeed + (gap - followDistance) * gain, 0, maxSpeed)
end

function PoliceDriveRules.throttleFor(targetSpeed: number, forwardSpeed: number, gain: number): number
	return math.clamp((targetSpeed - forwardSpeed) * gain, -1, 1)
end

function PoliceDriveRules.newStuckState(): StuckState
	return { StuckTime = 0, ReverseTimeLeft = 0, Recoveries = {} }
end

-- Advances stuck detection. "Reverse" = back off and turn away; "HardRecover" = too many
-- recoveries in the window, the caller should reposition the unit on the road network.
function PoliceDriveRules.updateStuck(
	state: StuckState,
	dt: number,
	now: number,
	speed: number,
	wantsToMove: boolean,
	config: { StuckSpeed: number, StuckSeconds: number, ReverseSeconds: number, HardRecoverAfter: number, RecoveryWindow: number }
): StuckAction
	if state.ReverseTimeLeft > 0 then
		state.ReverseTimeLeft -= dt
		return "Reverse"
	end
	if wantsToMove and speed < config.StuckSpeed then
		state.StuckTime += dt
	else
		state.StuckTime = 0
	end
	if state.StuckTime < config.StuckSeconds then
		return "Drive"
	end
	state.StuckTime = 0
	local recent = {}
	for _, t in state.Recoveries do
		if now - t <= config.RecoveryWindow then
			table.insert(recent, t)
		end
	end
	table.insert(recent, now)
	if #recent >= config.HardRecoverAfter then
		state.Recoveries = {}
		return "HardRecover"
	end
	state.Recoveries = recent
	state.ReverseTimeLeft = config.ReverseSeconds
	return "Reverse"
end

return PoliceDriveRules
```

## DataStoreAdapter (changed)
`src/ServerScriptService/Server/Data/DataStoreAdapter.luau`

```diff
diff --git a/src/ServerScriptService/Server/Data/DataStoreAdapter.luau b/src/ServerScriptService/Server/Data/DataStoreAdapter.luau
index cec75ea..7bd98b2 100644
--- a/src/ServerScriptService/Server/Data/DataStoreAdapter.luau
+++ b/src/ServerScriptService/Server/Data/DataStoreAdapter.luau
@@ -28,9 +28,11 @@ end
 
 function DataStoreAdapter.get(baseName: string): any
 	local store = DataStoreService:GetDataStore(DataStoreAdapter.storeName(baseName))
+	-- Studio-only: Workspace attribute SimulateStoreFailure_<baseName> fails just this store.
+	local perStore = "SimulateStoreFailure_" .. baseName
 	return {
 		UpdateAsync = function(_, key: string, transform: (any) -> any): any
-			if DataStoreAdapter.isSimulatingFailure() then
+			if DataStoreAdapter.isSimulatingFailure() or (RunService:IsStudio() and Workspace:GetAttribute(perStore) == true) then
 				error("Simulated DataStore failure (Studio test)")
 			end
 			return store:UpdateAsync(key, transform)
```

## EconomyConfig (changed)
`src/ReplicatedStorage/Shared/Config/EconomyConfig.luau`

```diff
diff --git a/src/ReplicatedStorage/Shared/Config/EconomyConfig.luau b/src/ReplicatedStorage/Shared/Config/EconomyConfig.luau
index b84949e..3d72d1d 100644
--- a/src/ReplicatedStorage/Shared/Config/EconomyConfig.luau
+++ b/src/ReplicatedStorage/Shared/Config/EconomyConfig.luau
@@ -20,6 +20,10 @@ local EconomyConfig = {
 	SessionLockTimeout = 180, -- seconds after which another server's lock counts as stale
 	AutosaveInterval = 60,
 	SaveAttempts = 3,
+	-- Earned-but-unpaid rewards are recorded here first (separate store), so they survive a
+	-- failed profile save, a disconnect or a server crash. Claimed on the next load.
+	RewardStoreName = "OutlawCity_PendingRewards_v1",
+	CommitAttempts = 2, -- write-through tries per cash change before it is refused as SaveFailed
 	-- If the save on leave fails, the unsaved profile is kept on this server and retried.
 	OrphanRetryInterval = 10,
 	OrphanRetryLimit = 900, -- seconds; stops early if another server takes the lock
```

## Types (changed)
`src/ReplicatedStorage/Shared/Types.luau`

```diff
diff --git a/src/ReplicatedStorage/Shared/Types.luau b/src/ReplicatedStorage/Shared/Types.luau
index aa7f263..cb3dfc8 100644
--- a/src/ReplicatedStorage/Shared/Types.luau
+++ b/src/ReplicatedStorage/Shared/Types.luau
@@ -120,6 +120,7 @@ export type EconomyError =
 	| "InvalidVehicle"
 	| "AlreadyOwned"
 	| "TooManyVehicles"
+	| "SaveFailed" -- the change could not be stored, so it was NOT applied
 	| "NotInGame"
 
 -- Store robbery (Phase 4B).
```

## ProfileStore.spec (changed)
`src/ServerStorage/Tests/ProfileStore.spec.luau`

```diff
diff --git a/src/ServerStorage/Tests/ProfileStore.spec.luau b/src/ServerStorage/Tests/ProfileStore.spec.luau
index 2be6648..7bca483 100644
--- a/src/ServerStorage/Tests/ProfileStore.spec.luau
+++ b/src/ServerStorage/Tests/ProfileStore.spec.luau
@@ -4,6 +4,7 @@ local ServerScriptService = game:GetService("ServerScriptService")
 local ReplicatedStorage = game:GetService("ReplicatedStorage")
 local ProfileStore = require(ServerScriptService.Server.Data.ProfileStore)
 local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
+local EconomyRules = require(ReplicatedStorage.Shared.Economy.EconomyRules)
 local Assert = require(script.Parent.Assert)
 
 local C = EconomyConfig
@@ -83,6 +84,86 @@ return {
 		Assert.equal(again.Cash, 0)
 		Assert.equal(table.find(again.OwnedVehicles, "Muscle") ~= nil, true, "owned after rejoin")
 	end,
+	["write-through: a committed purchase is stored before it takes effect"] = function()
+		local store = fakeStore()
+		local profile = ProfileStore.load(store, "k", "A", 1000, C)
+		profile.Cash = 20000
+		ProfileStore.save(store, "k", "A", profile, 1000, false)
+		local ok = ProfileStore.commit(store, "k", "A", profile, 1001, function(draft)
+			return EconomyRules.purchaseVehicle(draft, "Muscle", 15000, "buy:1", C)
+		end)
+		Assert.equal(ok, true)
+		Assert.equal(profile.Cash, 5000)
+		Assert.equal(store.Data.k.Profile.Cash, 5000, "stored at the moment it is acknowledged")
+		Assert.equal(table.find(store.Data.k.Profile.OwnedVehicles, "Muscle") ~= nil, true)
+	end,
+	["write-through: a failed write changes nothing, in memory or stored, and burns no tx id"] = function()
+		local store = fakeStore()
+		local profile = ProfileStore.load(store, "k", "A", 1000, C)
+		profile.Cash = 20000
+		ProfileStore.save(store, "k", "A", profile, 1000, false)
+		store.Fail = true
+		local ok, err = ProfileStore.commit(store, "k", "A", profile, 1001, function(draft)
+			return EconomyRules.purchaseVehicle(draft, "Muscle", 15000, "buy:1", C)
+		end)
+		Assert.equal(ok, false)
+		Assert.equal(err, "StoreError")
+		Assert.equal(profile.Cash, 20000)
+		Assert.equal(EconomyRules.ownsVehicle(profile, "Muscle"), false)
+		Assert.equal(EconomyRules.hasTransaction(profile, "buy:1"), false, "the same request can be retried")
+		store.Fail = false
+		Assert.equal(store.Data.k.Profile.Cash, 20000)
+		Assert.equal((ProfileStore.commit(store, "k", "A", profile, 1002, function(draft)
+			return EconomyRules.purchaseVehicle(draft, "Muscle", 15000, "buy:1", C)
+		end)), true, "retry after the outage succeeds once")
+		Assert.equal(profile.Cash, 5000)
+	end,
+	["a rule refusal writes nothing"] = function()
+		local store = fakeStore()
+		local profile = ProfileStore.load(store, "k", "A", 1000, C)
+		local writes = store.Writes
+		local ok, err = ProfileStore.commit(store, "k", "A", profile, 1001, function(draft)
+			return EconomyRules.purchaseVehicle(draft, "Muscle", 15000, "buy:1", C)
+		end)
+		Assert.equal(ok, false)
+		Assert.equal(err, "InsufficientFunds")
+		Assert.equal(store.Writes, writes)
+	end,
+	["lock expiry: an acknowledged purchase survives another server taking over"] = function()
+		local store = fakeStore()
+		local a = ProfileStore.load(store, "k", "A", 1000, C)
+		a.Cash = 15000
+		ProfileStore.save(store, "k", "A", a, 1000, false)
+		assert(ProfileStore.commit(store, "k", "A", a, 1001, function(draft)
+			return EconomyRules.purchaseVehicle(draft, "Muscle", 15000, "buy:1", C)
+		end))
+		-- Server A's leave-save then keeps failing and its lock goes stale; server B takes over.
+		local b, result = ProfileStore.load(store, "k", "B", 1001 + C.SessionLockTimeout + 1, C)
+		Assert.equal(result, "Existing")
+		Assert.equal(b.Cash, 0)
+		Assert.equal(EconomyRules.ownsVehicle(b, "Muscle"), true, "the purchase A acknowledged is there")
+		-- A comes back late: it can no longer write over B.
+		local ok, err = ProfileStore.save(store, "k", "A", a, 1300, true)
+		Assert.equal(ok, false)
+		Assert.equal(err, "LockLost")
+		local ok2, err2 = ProfileStore.commit(store, "k", "A", a, 1301, function(draft)
+			return EconomyRules.grant(draft, 999, "late", C)
+		end)
+		Assert.equal(ok2, false)
+		Assert.equal(err2, "LockLost")
+		Assert.equal(store.Data.k.Profile.Cash, 0)
+	end,
+	["sequential commits never lose an update"] = function()
+		local store = fakeStore()
+		local profile = ProfileStore.load(store, "k", "A", 1000, C)
+		for i = 1, 5 do
+			assert(ProfileStore.commit(store, "k", "A", profile, 1000 + i, function(draft)
+				return EconomyRules.grant(draft, 100, "g" .. i, C)
+			end))
+		end
+		Assert.equal(store.Data.k.Profile.Cash, C.StartingCash + 500)
+		Assert.equal(#store.Data.k.Profile.RecentTransactions, 5)
+	end,
 	["a store outage during load never creates or overwrites data"] = function()
 		local store = fakeStore()
 		store.Data.k = { Profile = { Version = 1, Cash = 9000, RecentTransactions = {} } }
```

## RewardLedger.spec (new) (changed)
`src/ServerStorage/Tests/RewardLedger.spec.luau`

```diff
diff --git a/src/ServerStorage/Tests/RewardLedger.spec.luau b/src/ServerStorage/Tests/RewardLedger.spec.luau
new file mode 100644
index 0000000..ed69b5a
--- /dev/null
+++ b/src/ServerStorage/Tests/RewardLedger.spec.luau
@@ -0,0 +1,125 @@
+-- Durable reward ledger (audit remediation): earned rewards survive failed profile saves,
+-- disconnects and server crashes, and are paid exactly once.
+local ReplicatedStorage = game:GetService("ReplicatedStorage")
+local ServerScriptService = game:GetService("ServerScriptService")
+local HttpService = game:GetService("HttpService")
+local RewardLedger = require(ServerScriptService.Server.Data.RewardLedger)
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
+local function fakeStore()
+	local data = {}
+	local store = { Fail = false, Data = data }
+	function store.UpdateAsync(self, key, transform)
+		if self.Fail then
+			error("simulated outage")
+		end
+		local result = transform(deepCopy(data[key]))
+		if result ~= nil then
+			data[key] = deepCopy(result)
+		end
+		return deepCopy(result)
+	end
+	return store
+end
+
+local function reward(tx: string, amount: number?)
+	return { TxId = tx, Amount = amount or 2000, Reason = "store robbery", At = 1 }
+end
+
+-- What EconomyService does on a load: pay everything recorded, then clear it.
+local function claim(profiles, rewards, profile, sessionId, now)
+	local list = assert(RewardLedger.list(rewards, "r"))
+	local settled = {}
+	local ok = ProfileStore.commit(profiles, "k", sessionId, profile, now, function(draft)
+		settled = RewardLedger.applyAll(draft, list, C)
+		return true, nil
+	end)
+	if ok then
+		RewardLedger.remove(rewards, "r", settled)
+	end
+	return ok
+end
+
+return {
+	["recording is idempotent per transaction id"] = function()
+		local rewards = fakeStore()
+		Assert.equal((RewardLedger.record(rewards, "r", reward("robbery:1"))), true)
+		Assert.equal((RewardLedger.record(rewards, "r", reward("robbery:1"))), true)
+		Assert.equal(#assert(RewardLedger.list(rewards, "r")), 1)
+	end,
+	["profile write fails after escape: the reward is paid once on the next load (any server)"] = function()
+		local profiles, rewards = fakeStore(), fakeStore()
+		local a = ProfileStore.load(profiles, "k", "A", 1000, C)
+		local startCash = a.Cash
+		-- escape: ledger write succeeds, profile write fails
+		assert(RewardLedger.record(rewards, "r", reward("robbery:1")))
+		profiles.Fail = true
+		local ok = ProfileStore.commit(profiles, "k", "A", a, 1001, function(draft)
+			return EconomyRules.grant(draft, 2000, "robbery:1", C)
+		end)
+		Assert.equal(ok, false)
+		Assert.equal(profiles.Data.k.Profile.Cash, startCash)
+		-- server A dies; later server B loads after the lock expires and claims the ledger
+		profiles.Fail = false
+		local b = ProfileStore.load(profiles, "k", "B", 1001 + C.SessionLockTimeout + 1, C)
+		Assert.equal(claim(profiles, rewards, b, "B", 1300), true)
+		Assert.equal(b.Cash, startCash + 2000)
+		Assert.equal(profiles.Data.k.Profile.Cash, startCash + 2000)
+		Assert.equal(#assert(RewardLedger.list(rewards, "r")), 0, "ledger cleared")
+		-- claiming again (another rejoin) pays nothing more
+		Assert.equal(claim(profiles, rewards, b, "B", 1301), true)
+		Assert.equal(b.Cash, startCash + 2000)
+	end,
+	["a reward already paid but not cleared from the ledger is never paid twice"] = function()
+		local profiles, rewards = fakeStore(), fakeStore()
+		local a = ProfileStore.load(profiles, "k", "A", 1000, C)
+		assert(RewardLedger.record(rewards, "r", reward("robbery:1")))
+		assert(ProfileStore.commit(profiles, "k", "A", a, 1001, function(draft)
+			return EconomyRules.grant(draft, 2000, "robbery:1", C)
+		end))
+		-- the ledger removal failed (outage), so the entry is still there on the next load
+		local cash = a.Cash
+		Assert.equal(claim(profiles, rewards, a, "A", 1002), true)
+		Assert.equal(a.Cash, cash, "duplicate transaction: not paid again")
+		Assert.equal(#assert(RewardLedger.list(rewards, "r")), 0, "and now cleared")
+	end,
+	["claim during a profile outage pays nothing and keeps the ledger entry"] = function()
+		local profiles, rewards = fakeStore(), fakeStore()
+		local a = ProfileStore.load(profiles, "k", "A", 1000, C)
+		local cash = a.Cash
+		assert(RewardLedger.record(rewards, "r", reward("robbery:1")))
+		profiles.Fail = true
+		Assert.equal(claim(profiles, rewards, a, "A", 1001), false)
+		Assert.equal(a.Cash, cash)
+		Assert.equal(#assert(RewardLedger.list(rewards, "r")), 1, "still recorded for the next try")
+	end,
+	["several recorded rewards are paid together and each once"] = function()
+		local profiles, rewards = fakeStore(), fakeStore()
+		local a = ProfileStore.load(profiles, "k", "A", 1000, C)
+		local cash = a.Cash
+		assert(RewardLedger.record(rewards, "r", reward("robbery:1", 2000)))
+		assert(RewardLedger.record(rewards, "r", reward("robbery:2", 2000)))
+		Assert.equal(claim(profiles, rewards, a, "A", 1001), true)
+		Assert.equal(a.Cash, cash + 4000)
+	end,
+	["a ledger outage is reported, not hidden"] = function()
+		local rewards = fakeStore()
+		rewards.Fail = true
+		local ok, err = RewardLedger.record(rewards, "r", reward("robbery:1"))
+		Assert.equal(ok, false)
+		Assert.truthy(err ~= nil)
+		Assert.equal((RewardLedger.list(rewards, "r")), nil)
+	end,
+}
```

## RobberyRules.spec (changed)
`src/ServerStorage/Tests/RobberyRules.spec.luau`

```diff
diff --git a/src/ServerStorage/Tests/RobberyRules.spec.luau b/src/ServerStorage/Tests/RobberyRules.spec.luau
index 89ccef6..0062704 100644
--- a/src/ServerStorage/Tests/RobberyRules.spec.luau
+++ b/src/ServerStorage/Tests/RobberyRules.spec.luau
@@ -121,6 +121,7 @@ return {
 		Assert.equal(RobberyRules.payoutOutcome(true, nil), "Paid")
 		Assert.equal(RobberyRules.payoutOutcome(false, "DuplicateTransaction"), "AlreadyPaid")
 		Assert.equal(RobberyRules.payoutOutcome(false, "DataNotLoaded"), "Retry")
+		Assert.equal(RobberyRules.payoutOutcome(false, "SaveFailed"), "Retry")
 		Assert.equal(RobberyRules.payoutOutcome(false, "NotInGame"), "Rejected")
 		Assert.equal(RobberyRules.payoutOutcome(false, "InvalidAmount"), "Rejected")
 	end,
```

## PoliceNavigation.spec (changed)
`src/ServerStorage/Tests/PoliceNavigation.spec.luau`

```diff
diff --git a/src/ServerStorage/Tests/PoliceNavigation.spec.luau b/src/ServerStorage/Tests/PoliceNavigation.spec.luau
index d55a3c4..b31fff5 100644
--- a/src/ServerStorage/Tests/PoliceNavigation.spec.luau
+++ b/src/ServerStorage/Tests/PoliceNavigation.spec.luau
@@ -113,7 +113,11 @@ return {
 	["chase speed matches the target and closes the gap"] = function()
 		local C = PoliceConfig
 		Assert.equal(PoliceDriveRules.chaseSpeed(35, C.ChaseFollowDistance, C.ChaseFollowDistance, C.ChaseGain, C.ChaseSpeed), 35)
-		Assert.truthy(PoliceDriveRules.chaseSpeed(35, 65, C.ChaseFollowDistance, C.ChaseGain, C.ChaseSpeed) > 35 + 40, "closes a 65-stud gap")
+		-- Closes a gap in proportion to ChaseGain (tuning lives in PoliceConfig; the audit
+		-- remediation lowered it from 1.0 to 0.25), never faster than ChaseSpeed.
+		local closing = PoliceDriveRules.chaseSpeed(35, 65, C.ChaseFollowDistance, C.ChaseGain, C.ChaseSpeed)
+		Assert.truthy(closing > 35, "closes a 65-stud gap")
+		Assert.equal(closing, math.min(35 + (65 - C.ChaseFollowDistance) * C.ChaseGain, C.ChaseSpeed))
 		Assert.equal(PoliceDriveRules.chaseSpeed(0, 0, C.ChaseFollowDistance, C.ChaseGain, C.ChaseSpeed), 0)
 		Assert.equal(PoliceDriveRules.chaseSpeed(200, 500, C.ChaseFollowDistance, C.ChaseGain, C.ChaseSpeed), C.ChaseSpeed)
 	end,
```

## EconomyRules.spec (unchanged in this range: full current source)
`src/ServerStorage/Tests/EconomyRules.spec.luau`

```lua
-- Economy rules (pure): validation, grants, deductions, duplicates, saved-data checks, locks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyRules = require(ReplicatedStorage.Shared.Economy.EconomyRules)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Assert = require(script.Parent.Assert)

local C = EconomyConfig

local function fresh()
	return EconomyRules.newProfile(C)
end

return {
	["new players start with the configured starting cash"] = function()
		local p = fresh()
		Assert.equal(p.Cash, C.StartingCash)
		Assert.equal(#p.RecentTransactions, 0)
		local fromNil, kind = EconomyRules.validateSaved(nil, C)
		Assert.equal(kind, "New")
		Assert.equal(fromNil.Cash, C.StartingCash)
	end,
	["invalid, negative, zero, fractional and nonfinite amounts are rejected"] = function()
		local p = fresh()
		for _, bad in { 0, -1, -500, 1.5, 0 / 0, math.huge, -math.huge, "100", true, {}, C.MaxTransaction + 1 } do
			local ok, err = EconomyRules.grant(p, bad, "tx-" .. tostring(bad), C)
			Assert.equal(ok, false, `grant {tostring(bad)}`)
			Assert.equal(err, "InvalidAmount")
			local ok2, err2 = EconomyRules.deduct(p, bad, "txd-" .. tostring(bad), C)
			Assert.equal(ok2, false, `deduct {tostring(bad)}`)
			Assert.equal(err2, "InvalidAmount")
		end
		Assert.equal((EconomyRules.grant(p, 100, nil, C)), false, "missing tx id")
		Assert.equal(select(2, EconomyRules.grant(p, 100, string.rep("x", 65), C)), "InvalidTransactionId")
		Assert.equal(p.Cash, C.StartingCash, "balance untouched")
	end,
	["grants and deductions change the balance"] = function()
		local p = fresh()
		Assert.equal((EconomyRules.grant(p, 250, "a", C)), true)
		Assert.equal(p.Cash, C.StartingCash + 250)
		Assert.equal((EconomyRules.deduct(p, 100, "b", C)), true)
		Assert.equal(p.Cash, C.StartingCash + 150)
	end,
	["insufficient funds prevents a purchase"] = function()
		local p = fresh()
		local ok, err = EconomyRules.deduct(p, C.StartingCash + 1, "buy-1", C)
		Assert.equal(ok, false)
		Assert.equal(err, "InsufficientFunds")
		Assert.equal(p.Cash, C.StartingCash)
		Assert.equal(EconomyRules.canAfford(p, C.StartingCash), true)
		Assert.equal(EconomyRules.canAfford(p, C.StartingCash + 1), false)
		Assert.equal((EconomyRules.deduct(p, C.StartingCash, "buy-2", C)), true, "exact balance is affordable")
		Assert.equal(p.Cash, 0)
	end,
	["a transaction id can only apply once"] = function()
		local p = fresh()
		Assert.equal((EconomyRules.grant(p, 100, "reward-42", C)), true)
		local ok, err = EconomyRules.grant(p, 100, "reward-42", C)
		Assert.equal(ok, false)
		Assert.equal(err, "DuplicateTransaction")
		Assert.equal(select(2, EconomyRules.deduct(p, 50, "reward-42", C)), "DuplicateTransaction", "ids are shared across grant and deduct")
		Assert.equal(p.Cash, C.StartingCash + 100)
	end,
	["remembered transaction ids are bounded"] = function()
		local p = fresh()
		for i = 1, C.RecentTransactionLimit + 25 do
			EconomyRules.grant(p, 1, `t{i}`, C)
		end
		Assert.equal(#p.RecentTransactions, C.RecentTransactionLimit)
		Assert.equal(EconomyRules.hasTransaction(p, `t{C.RecentTransactionLimit + 25}`), true)
	end,
	["the balance cap is enforced"] = function()
		local p = fresh()
		p.Cash = C.MaxBalance - 10
		Assert.equal(select(2, EconomyRules.grant(p, 11, "cap", C)), "BalanceCap")
		Assert.equal(p.Cash, C.MaxBalance - 10)
	end,
	["valid saved data is kept exactly; malformed data is refused, never reset"] = function()
		local saved = { Version = 2, Cash = 12345, RecentTransactions = { "x", "y", 5 }, OwnedVehicles = { "Coupe" } }
		local p, kind = EconomyRules.validateSaved(saved, C)
		Assert.equal(kind, "Existing")
		Assert.equal(p.Cash, 12345, "not reset to starting cash")
		Assert.equal(#p.RecentTransactions, 2, "junk ids dropped")
		for _, corrupt in { "text", { Cash = "lots" }, { Cash = -5 }, { Cash = 0 / 0 }, { Cash = 1.5 }, { Cash = C.MaxBalance + 1 } } do
			local profile, why = EconomyRules.validateSaved(corrupt, C)
			Assert.equal(profile, nil)
			Assert.equal(why, "Corrupt")
		end
	end,
	["new profiles own exactly the starter Coupe"] = function()
		local p = fresh()
		Assert.equal(p.Version, C.ProfileVersion)
		Assert.equal(#p.OwnedVehicles, 1)
		Assert.equal(p.OwnedVehicles[1], "Coupe")
	end,
	["cash-only (v1) profiles migrate without losing cash or transaction history"] = function()
		for _, legacy in { { Version = 1, Cash = 9800, RecentTransactions = { "robbery:a" } }, { Cash = 9800, RecentTransactions = { "robbery:a" } } } do
			local p, kind = EconomyRules.validateSaved(legacy, C)
			Assert.equal(kind, "Migrated")
			Assert.equal(p.Version, C.ProfileVersion)
			Assert.equal(p.Cash, 9800)
			Assert.equal(p.RecentTransactions[1], "robbery:a")
			Assert.equal(#p.OwnedVehicles, 1)
			Assert.equal(p.OwnedVehicles[1], "Coupe")
		end
		-- a v1 record that somehow carries a vehicle list does not gain cars from it
		local p = EconomyRules.validateSaved({ Version = 1, Cash = 5, OwnedVehicles = { "Muscle" } }, C)
		Assert.equal(EconomyRules.ownsVehicle(p, "Muscle"), false)
	end,
	["v2 ownership is kept; junk is dropped; damaged or newer records are refused untouched"] = function()
		local p, kind = EconomyRules.validateSaved({ Version = 2, Cash = 1, RecentTransactions = {}, OwnedVehicles = { "Muscle", 7, "Muscle", "" } }, C)
		Assert.equal(kind, "Existing")
		Assert.equal(EconomyRules.ownsVehicle(p, "Muscle"), true)
		Assert.equal(EconomyRules.ownsVehicle(p, "Coupe"), true, "starter is always owned")
		Assert.equal(#p.OwnedVehicles, 2, "duplicates and junk removed")
		for _, bad in {
			{ Version = 2, Cash = 1, RecentTransactions = {} }, -- v2 without its list
			{ Version = 3, Cash = 1, RecentTransactions = {}, OwnedVehicles = {} }, -- newer schema
			{ Version = 0, Cash = 1 },
			{ Version = 1.5, Cash = 1 },
		} do
			local profile, why = EconomyRules.validateSaved(bad, C)
			Assert.equal(profile, nil)
			Assert.equal(why, "Corrupt")
		end
	end,
	["buying a car takes the price once and records ownership in the same step"] = function()
		local p = fresh()
		p.Cash = 20000
		Assert.equal((EconomyRules.purchaseVehicle(p, "Muscle", 15000, "buy:1", C)), true)
		Assert.equal(p.Cash, 5000)
		Assert.equal(EconomyRules.ownsVehicle(p, "Muscle"), true)
		-- the same request again, or a new request for the same car, never charges twice
		local ok, err = EconomyRules.purchaseVehicle(p, "Muscle", 15000, "buy:1", C)
		Assert.equal(ok, false)
		Assert.equal(err, "DuplicateTransaction")
		ok, err = EconomyRules.purchaseVehicle(p, "Muscle", 15000, "buy:2", C)
		Assert.equal(err, "AlreadyOwned")
		Assert.equal(p.Cash, 5000)
		Assert.equal(#p.OwnedVehicles, 2)
	end,
	["a failed purchase changes nothing"] = function()
		local p = fresh()
		p.Cash = 14999
		local ok, err = EconomyRules.purchaseVehicle(p, "Muscle", 15000, "buy:x", C)
		Assert.equal(ok, false)
		Assert.equal(err, "InsufficientFunds")
		Assert.equal(p.Cash, 14999)
		Assert.equal(EconomyRules.ownsVehicle(p, "Muscle"), false)
		Assert.equal(#p.RecentTransactions, 0, "a refused purchase doesn't burn its transaction id")
		for _, case in { { "", 100, "InvalidVehicle" }, { 5, 100, "InvalidVehicle" }, { "Muscle", -1, "InvalidAmount" }, { "Muscle", 0 / 0, "InvalidAmount" }, { "Muscle", "15000", "InvalidAmount" } } do
			local ok2, err2 = EconomyRules.purchaseVehicle(p, case[1], case[2], "buy:y", C)
			Assert.equal(ok2, false)
			Assert.equal(err2, case[3])
		end
		Assert.equal(p.Cash, 14999)
	end,
	["session locks: own or stale locks can be claimed, live foreign locks cannot"] = function()
		local T = C.SessionLockTimeout
		Assert.equal(EconomyRules.canClaimLock(nil, "me", 1000, T), true)
		Assert.equal(EconomyRules.canClaimLock({ Id = "me", At = 999 }, "me", 1000, T), true)
		Assert.equal(EconomyRules.canClaimLock({ Id = "other", At = 990 }, "me", 1000, T), false)
		Assert.equal(EconomyRules.canClaimLock({ Id = "other", At = 1000 - T - 1 }, "me", 1000, T), true)
	end,
	["no client remote can change cash"] = function()
		for name in Remotes.Definitions do
			for _, word in { "Cash", "Money", "Grant", "Balance", "Economy" } do
				Assert.truthy(not name:find(word), `remote {name} must not expose {word}`)
			end
		end
	end,
}
```

## RobberyHudController (changed)
`src/StarterPlayer/StarterPlayerScripts/Client/Controllers/RobberyHudController.luau`

```diff
diff --git a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/RobberyHudController.luau b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/RobberyHudController.luau
index f0b497d..c9f79eb 100644
--- a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/RobberyHudController.luau
+++ b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/RobberyHudController.luau
@@ -137,7 +137,11 @@ function RobberyHudController.init()
 		elseif kind == "Paid" and type(payload.Amount) == "number" then
 			showToast(`Escaped! +{money(payload.Amount)} from the robbery.`, GREEN, 4)
 		elseif kind == "PayoutPending" then
-			showToast("Escaped! Your cash data is reconnecting; the reward will be added. Stay in the game.", AMBER, 5)
+			if payload.Recorded then
+				showToast("Escaped! Your reward is safely recorded and will be added as soon as it can be saved (even if you rejoin).", AMBER, 5)
+			else
+				showToast("Escaped! Your cash data is reconnecting; the reward will be added. Stay in the game.", AMBER, 5)
+			end
 		elseif kind == "PayoutFailed" then
 			showToast("Escaped, but the reward couldn't be paid.", RED, 4)
 		end
```

## DealershipController (changed)
`src/StarterPlayer/StarterPlayerScripts/Client/Controllers/DealershipController.luau`

```diff
diff --git a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/DealershipController.luau b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/DealershipController.luau
index e7d00fa..bc99ddf 100644
--- a/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/DealershipController.luau
+++ b/src/StarterPlayer/StarterPlayerScripts/Client/Controllers/DealershipController.luau
@@ -29,6 +29,7 @@ local RESULT_TEXT: { [string]: string } = {
 	NotForSale = "That car isn't for sale.",
 	DuplicateTransaction = "That purchase was already processed.",
 	TooManyVehicles = "Your garage is full.",
+	SaveFailed = "Couldn't save your purchase right now. Nothing was charged; try again.",
 	NetworkError = "Couldn't reach the server. Nothing was charged.",
 }
 
```
