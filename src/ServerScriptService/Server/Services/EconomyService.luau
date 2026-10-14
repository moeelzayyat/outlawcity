--!strict
-- The ONE place player cash and vehicle ownership change. Server-authoritative, persisted in a
-- DataStore.
--  * Load on join with retries + exponential backoff and a session lock (ProfileStore).
--  * If loading fails, the player is marked "Unavailable": no changes, and NOTHING is saved for
--    them (so a DataStore outage can never overwrite real progress with defaults). Loading is
--    retried in the background until it succeeds.
--  * WRITE-THROUGH (audit remediation): every grant, deduction and purchase is applied to a copy
--    of the profile and written with ProfileStore.commit BEFORE it takes effect. If the write
--    fails, nothing changes and the caller gets "SaveFailed". So anything this service reports
--    as done is already stored and survives a crash, a failed leave-save or another server
--    taking the lock later.
--  * Changes for one player are serialised (one commit or save at a time), so concurrent
--    requests can't overwrite each other.
--  * Earned rewards (grantReward) are first recorded in a separate reward ledger, then granted.
--    If the grant can't be stored now, the ledger entry is paid on the player's next successful
--    load on any server, exactly once (same transaction id).
--  * Every loaded profile is re-saved every AutosaveInterval to refresh its session lock (a
--    quiet session's lock must never go stale while the player is still here); saved and
--    released on leave and on shutdown. A failed leave-save is retried in the background.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local EconomyConfig = require(Shared.Config.EconomyConfig)
local EconomyRules = require(Shared.Economy.EconomyRules)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)
local Data = script.Parent.Parent.Data
local ProfileStore = require(Data.ProfileStore)
local RewardLedger = require(Data.RewardLedger)
local DataStoreAdapter = require(Data.DataStoreAdapter)

local EconomyService = {}

type Session = {
	Status: "Loading" | "Loaded" | "Unavailable",
	Profile: Types.Profile?,
	Key: string,
	Leaving: boolean,
	Busy: boolean, -- a commit or save is in progress for this player
}

local sessions: { [Player]: Session } = {}
type Orphan = { Name: string, Profile: Types.Profile, Since: number }
local orphans: { [string]: Orphan } = {} -- key -> profile whose save on leave failed
local store: any
local rewardStore: any
-- A Studio playtest has no JobId; give each server a unique lock id either way.
local sessionId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)

local function log(text: string)
	print(`[Economy] {text}`)
end

local function publish(player: Player, session: Session)
	player:SetAttribute(PlayerAttributes.CashStatus, session.Status)
	player:SetAttribute(PlayerAttributes.Cash, if session.Profile then session.Profile.Cash else nil)
	local owned = if session.Profile then table.clone(session.Profile.OwnedVehicles) else table.clone(EconomyConfig.StarterVehicles)
	table.sort(owned)
	player:SetAttribute(PlayerAttributes.OwnedVehicles, table.concat(owned, ","))
end

local function keyFor(player: Player): string
	return `player_{player.UserId}`
end

local function rewardKeyFor(key: string): string
	return `rewards_{key}`
end

-- Runs fn with this player's profile to itself: no other commit or save interleaves.
local function withLock<T...>(session: Session, fn: () -> T...): T...
	while session.Busy do
		task.wait()
	end
	session.Busy = true
	local results = table.pack(pcall(fn))
	session.Busy = false
	if not results[1] then
		error(results[2], 0)
	end
	return table.unpack(results, 2, results.n)
end

-- Write-through commit for a loaded session. Returns (ok, err): rule errors pass through,
-- store failures become "SaveFailed" (nothing applied). Losing the lock means another server
-- owns this profile now, so this session stops writing.
local function commit(player: Player, session: Session, label: string, mutate: (Types.Profile) -> (boolean, string?)): (boolean, Types.EconomyError?)
	local profile = session.Profile :: Types.Profile
	local lastErr: string? = nil
	for attempt = 1, EconomyConfig.CommitAttempts do
		local ok, err, detail = ProfileStore.commit(store, session.Key, sessionId, profile, os.time(), mutate)
		if ok then
			return true, nil
		end
		if err ~= "StoreError" and err ~= "LockLost" then
			return false, err :: any -- refused by the rules: nothing to retry
		end
		lastErr = err
		log(`{player.Name}: {label} write attempt {attempt} failed ({err}{if detail then ": " .. detail else ""})`)
		if err == "LockLost" then
			session.Status = "Unavailable"
			publish(player, session)
			warn(`[Economy] {player.Name}: another server owns this profile; this session stops changing it`)
			break
		end
		if attempt < EconomyConfig.CommitAttempts then
			task.wait(EconomyConfig.RetryBaseDelay * 2 ^ (attempt - 1))
		end
	end
	log(`{player.Name}: {label} NOT applied ({lastErr}); nothing changed`)
	return false, "SaveFailed"
end

-- Pays rewards recorded in the ledger (earned earlier, here or on another server, but not
-- stored then). Runs once after each successful load; safe to repeat.
local function claimRewards(player: Player, session: Session)
	local rewards, listErr = RewardLedger.list(rewardStore, rewardKeyFor(session.Key))
	if not rewards then
		log(`{player.Name}: reward ledger unreadable ({listErr}); will retry on the next load`)
		return
	end
	if #rewards == 0 then
		return
	end
	local settled: { string } = {}
	local ok = withLock(session, function()
		local committed = commit(player, session, "claim rewards", function(draft)
			settled = RewardLedger.applyAll(draft, rewards, EconomyConfig)
			return true, nil
		end)
		return committed
	end)
	if ok then
		publish(player, session)
		log(`{player.Name}: paid {#settled} recorded reward(s) -> {(session.Profile :: Types.Profile).Cash}`)
		RewardLedger.remove(rewardStore, rewardKeyFor(session.Key), settled)
	end
end

local function tryLoad(player: Player, session: Session): boolean
	for attempt = 1, EconomyConfig.LoadAttempts do
		local profile, result, detail = ProfileStore.load(store, session.Key, sessionId, os.time(), EconomyConfig)
		if profile then
			session.Profile = profile
			session.Status = "Loaded"
			publish(player, session)
			log(`{player.Name}: loaded ({result}) cash={profile.Cash}`)
			task.spawn(claimRewards, player, session)
			return true
		end
		log(`{player.Name}: load attempt {attempt} failed ({result}{if detail then ": " .. detail else ""})`)
		if result == "Corrupt" then
			break -- retrying won't help; keep the data untouched and stay unavailable
		end
		if attempt < EconomyConfig.LoadAttempts then
			task.wait(EconomyConfig.RetryBaseDelay * 2 ^ (attempt - 1))
		end
		if player.Parent ~= Players then
			return false
		end
	end
	return false
end

local function loadWithRecovery(player: Player, session: Session)
	if tryLoad(player, session) then
		return
	end
	session.Status = "Unavailable"
	publish(player, session)
	log(`{player.Name}: data unavailable; cash changes disabled and nothing will be saved until it loads`)
	while player.Parent == Players and session.Status ~= "Loaded" do
		task.wait(EconomyConfig.FailedRetryInterval)
		if player.Parent == Players and tryLoad(player, session) then
			log(`{player.Name}: recovered after a failed load`)
		end
	end
end

-- Returns (saved, lockLost).
local function saveProfile(name: string, key: string, profile: Types.Profile, release: boolean, attempts: number): (boolean, boolean)
	for attempt = 1, attempts do
		local ok, err, detail = ProfileStore.save(store, key, sessionId, profile, os.time(), release)
		if ok then
			return true, false
		end
		log(`{name}: save attempt {attempt} failed ({err}{if detail then ": " .. detail else ""})`)
		if err == "LockLost" then
			return false, true
		end
		if attempt < attempts then
			task.wait(EconomyConfig.RetryBaseDelay * 2 ^ (attempt - 1))
		end
	end
	return false, false
end

local function save(player: Player, session: Session, release: boolean): boolean
	return withLock(session, function()
		if session.Status ~= "Loaded" or not session.Profile then
			return false -- never write for a profile we didn't load
		end
		local ok = saveProfile(player.Name, session.Key, session.Profile :: Types.Profile, release, EconomyConfig.SaveAttempts)
		return ok
	end)
end

-- Background retries for profiles whose save on leave failed. Since every cash change is
-- already stored when it happens, this only refreshes/releases the lock; nothing acknowledged
-- depends on it.
local function retryOrphan(key: string, orphan: Orphan)
	while orphans[key] == orphan do
		task.wait(EconomyConfig.OrphanRetryInterval)
		if orphans[key] ~= orphan then
			return -- the player came back and took the profile over
		end
		local ok, lockLost = saveProfile(orphan.Name, key, orphan.Profile, true, 1)
		if ok then
			orphans[key] = nil
			log(`{orphan.Name}: saved after leaving (cash={orphan.Profile.Cash})`)
		elseif lockLost then
			orphans[key] = nil
			log(`{orphan.Name}: another server owns this profile now; nothing to release`)
		elseif os.clock() - orphan.Since > EconomyConfig.OrphanRetryLimit then
			orphans[key] = nil
			warn(`[Economy] {orphan.Name}: gave up releasing the lock after {EconomyConfig.OrphanRetryLimit}s (it expires by itself)`)
		end
	end
end

local function loadedSession(player: Player): (Session?, Types.EconomyError?)
	local session = sessions[player]
	if not session or player.Parent ~= Players then
		return nil, "NotInGame"
	end
	if session.Status ~= "Loaded" or not session.Profile then
		return nil, "DataNotLoaded"
	end
	return session, nil
end

local function change(player: Player, kind: "grant" | "deduct", amount: any, txId: any, reason: string): (boolean, Types.EconomyError?)
	local session, err = loadedSession(player)
	if not session then
		return false, err
	end
	local ok, changeErr = withLock(session, function()
		if session.Status ~= "Loaded" then
			return false, "DataNotLoaded" :: Types.EconomyError?
		end
		return commit(player, session, `{kind} {tostring(amount)}`, function(draft)
			if kind == "grant" then
				return EconomyRules.grant(draft, amount, txId, EconomyConfig)
			end
			return EconomyRules.deduct(draft, amount, txId, EconomyConfig)
		end)
	end)
	if ok then
		publish(player, session)
		log(`{player.Name}: {kind} {amount} ({reason}, tx {txId}) -> {(session.Profile :: Types.Profile).Cash} (stored)`)
	else
		log(`{player.Name}: {kind} {tostring(amount)} refused: {changeErr} ({reason}, tx {tostring(txId)})`)
	end
	return ok, changeErr
end

-- Server-only API. txId must be unique per real-world event; repeats are refused. Returns true
-- only once the change is stored.
function EconomyService.grant(player: Player, amount: number, txId: string, reason: string): (boolean, Types.EconomyError?)
	return change(player, "grant", amount, txId, reason)
end

function EconomyService.deduct(player: Player, amount: number, txId: string, reason: string): (boolean, Types.EconomyError?)
	return change(player, "deduct", amount, txId, reason)
end

-- A reward the player has EARNED (robbery payout). Recorded in the reward ledger first, then
-- granted write-through. Returns (paid, err, recorded): if not paid but recorded, the reward
-- will be paid on the player's next successful load (any server), never twice.
function EconomyService.grantReward(player: Player, amount: number, txId: string, reason: string): (boolean, Types.EconomyError?, boolean)
	local recorded, recordErr = RewardLedger.record(rewardStore, rewardKeyFor(keyFor(player)), { TxId = txId, Amount = amount, Reason = reason, At = os.time() })
	if not recorded then
		log(`{player.Name}: reward {txId} could not be recorded in the ledger ({recordErr})`)
	end
	local paid, err = change(player, "grant", amount, txId, reason)
	if paid or err == "DuplicateTransaction" then
		-- Settled now (or earlier): clear it from the ledger. If this fails, the next load's
		-- claim finds it already paid (duplicate tx) and clears it then.
		RewardLedger.remove(rewardStore, rewardKeyFor(keyFor(player)), { txId })
	end
	return paid, err, recorded
end

function EconomyService.getBalance(player: Player): number?
	local session = sessions[player]
	return if session and session.Status == "Loaded" and session.Profile then session.Profile.Cash else nil
end

function EconomyService.canAfford(player: Player, amount: number): boolean
	local session = sessions[player]
	return session ~= nil and session.Profile ~= nil and session.Status == "Loaded" and EconomyRules.canAfford(session.Profile, amount)
end

function EconomyService.getStatus(player: Player): string
	local session = sessions[player]
	return if session then session.Status else "Unavailable"
end

-- Starter vehicles are always allowed (even while data is loading or unavailable); anything
-- else needs a loaded profile that owns it.
function EconomyService.ownsVehicle(player: Player, vehicleId: string): boolean
	if table.find(EconomyConfig.StarterVehicles, vehicleId) then
		return true
	end
	local session = sessions[player]
	return session ~= nil and session.Status == "Loaded" and session.Profile ~= nil and EconomyRules.ownsVehicle(session.Profile, vehicleId)
end

-- Server-only purchase: the price and the ownership are applied together to a profile copy and
-- stored in one write; only then does the purchase take effect and return true. A failed write
-- returns "SaveFailed" with nothing charged and no car.
function EconomyService.purchaseVehicle(player: Player, vehicleId: string, price: number, txId: string): (boolean, Types.EconomyError?)
	local session, err = loadedSession(player)
	if not session then
		return false, err
	end
	local ok, buyErr = withLock(session, function()
		if session.Status ~= "Loaded" then
			return false, "DataNotLoaded" :: Types.EconomyError?
		end
		return commit(player, session, `purchase {tostring(vehicleId)}`, function(draft)
			return EconomyRules.purchaseVehicle(draft, vehicleId, price, txId, EconomyConfig)
		end)
	end)
	if ok then
		publish(player, session)
		log(`{player.Name}: bought {vehicleId} for {price} (tx {txId}) -> cash {(session.Profile :: Types.Profile).Cash} (stored)`)
	else
		log(`{player.Name}: purchase {tostring(vehicleId)} for {tostring(price)} refused: {buyErr} (tx {tostring(txId)})`)
	end
	return ok, buyErr
end

-- Unique transaction id helper for server systems.
function EconomyService.newTransactionId(prefix: string): string
	return `{prefix}:{HttpService:GenerateGUID(false)}`
end

-- Studio test hook: save now (as if autosaving).
function EconomyService.saveNowForTesting(player: Player): boolean
	assert(RunService:IsStudio(), "Studio-only")
	local session = sessions[player]
	return session ~= nil and save(player, session, false)
end

-- Studio test hook: pretend this player's cash data just became unavailable (true) or came
-- back (false). The in-memory profile is kept, but no grants, deductions or saves happen.
function EconomyService.setUnavailableForTesting(player: Player, unavailable: boolean): boolean
	assert(RunService:IsStudio(), "Studio-only")
	local session = sessions[player]
	if not session or not session.Profile then
		return false
	end
	session.Status = if unavailable then "Unavailable" else "Loaded"
	publish(player, session)
	log(`{player.Name}: Studio test: data {if unavailable then "unavailable" else "available again"}`)
	return true
end

-- Studio test hook: rewrites this player's stored record as a version-1 (cash-only) profile
-- and stops saving this session, so the next join exercises the migration for real.
function EconomyService.writeLegacyRecordForTesting(player: Player): boolean
	assert(RunService:IsStudio(), "Studio-only")
	local session = sessions[player]
	if not session or session.Status ~= "Loaded" or not session.Profile then
		return false
	end
	local profile = session.Profile :: Types.Profile
	local ok = pcall(function()
		store:UpdateAsync(session.Key, function()
			return { Profile = { Version = 1, Cash = profile.Cash, RecentTransactions = table.clone(profile.RecentTransactions) } }
		end)
	end)
	if ok then
		session.Status = "Unavailable" -- nothing more is saved this session
		publish(player, session)
		log(`{player.Name}: Studio test: stored record rewritten as version 1 (cash={profile.Cash}); rejoin to migrate`)
	end
	return ok
end

local function onPlayerAdded(player: Player)
	local session: Session = { Status = "Loading", Profile = nil, Key = keyFor(player), Leaving = false, Busy = false }
	sessions[player] = session
	local orphan = orphans[session.Key]
	if orphan then
		-- Rejoined this server before its leave-save went through: this server still holds the
		-- lock and the copy matches what was stored by the write-through commits.
		orphans[session.Key] = nil
		session.Profile = orphan.Profile
		session.Status = "Loaded"
		publish(player, session)
		log(`{player.Name}: rejoined; using the profile kept on this server (cash={orphan.Profile.Cash})`)
		task.spawn(claimRewards, player, session)
		return
	end
	publish(player, session)
	task.spawn(loadWithRecovery, player, session)
end

local function onPlayerRemoving(player: Player)
	local session = sessions[player]
	if not session then
		return
	end
	session.Leaving = true
	if session.Status == "Loaded" then
		local profile = session.Profile :: Types.Profile
		if save(player, session, true) then
			log(`{player.Name}: saved on leave (cash={profile.Cash})`)
		elseif sessions[player] == session then
			local orphan: Orphan = { Name = player.Name, Profile = profile, Since = os.clock() }
			orphans[session.Key] = orphan
			warn(`[Economy] {player.Name}: save on leave failed; retrying in the background (every change was already stored when it happened)`)
			task.spawn(retryOrphan, session.Key, orphan)
		end
	else
		log(`{player.Name}: left with data {session.Status}; nothing saved (protects stored progress)`)
	end
	sessions[player] = nil
end

function EconomyService.init()
	store = DataStoreAdapter.get(EconomyConfig.DataStoreName)
	rewardStore = DataStoreAdapter.get(EconomyConfig.RewardStoreName)
	if RunService:IsStudio() and Workspace:GetAttribute("SimulateDataStoreFailureOnStart") == true then
		DataStoreAdapter.setSimulatedFailure(true)
		log("Studio test: simulating DataStore failure from server start")
	end
end

function EconomyService.start()
	Players.PlayerAdded:Connect(onPlayerAdded)
	for _, player in Players:GetPlayers() do
		if not sessions[player] then
			onPlayerAdded(player)
		end
	end
	Players.PlayerRemoving:Connect(onPlayerRemoving)
	game:BindToClose(function()
		local pending = 0
		for player in sessions do
			pending += 1
			task.spawn(function()
				onPlayerRemoving(player)
				pending -= 1
			end)
		end
		for key, orphan in orphans do
			pending += 1
			task.spawn(function()
				if saveProfile(orphan.Name, key, orphan.Profile, true, 1) then
					orphans[key] = nil
					log(`{orphan.Name}: saved at shutdown (cash={orphan.Profile.Cash})`)
				end
				pending -= 1
			end)
		end
		local started = os.clock()
		while pending > 0 and os.clock() - started < 25 do
			task.wait(0.1)
		end
	end)
	-- Lock heartbeat: re-save every loaded profile so its session lock stays fresh while the
	-- player is here (a lock older than SessionLockTimeout could be claimed by another server).
	task.spawn(function()
		while true do
			task.wait(EconomyConfig.AutosaveInterval)
			for player, session in sessions do
				if session.Status == "Loaded" and not session.Leaving then
					task.spawn(save, player, session, false)
				end
			end
		end
	end)
end

return EconomyService
