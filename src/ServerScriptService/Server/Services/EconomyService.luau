--!strict
-- The ONE place player cash and vehicle ownership change. Server-authoritative, persisted in a
-- DataStore.
--  * Load on join with retries + exponential backoff and a session lock (ProfileStore).
--  * If loading fails, the player is marked "Unavailable": no changes, and NOTHING is saved for
--    them (so a DataStore outage can never overwrite real progress with defaults). Loading is
--    retried in the background until it succeeds.
--  * Every write goes through the player's ProfileSession (audit remediation): one operation at
--    a time; write-through commits (a change is stored before it takes effect; a failed write
--    returns SaveFailed with nothing applied); after an ambiguous write nothing is written from
--    memory until the stored profile has been read back and adopted; operations queued when the
--    player leaves or the lock is lost never run.
--  * Earned rewards (grantReward) are first recorded in a separate reward ledger, then paid
--    write-through with the id kept in the profile's PaidRewards. Anything still in the ledger
--    is claimed after load and then periodically with bounded backoff, exactly once.
--  * Every loaded profile is re-saved every AutosaveInterval to refresh its session lock; saved
--    and released on leave and on shutdown. A failed leave-save is retried in the background.
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
local ProfileSession = require(Data.ProfileSession)
local RewardLedger = require(Data.RewardLedger)
local DataStoreAdapter = require(Data.DataStoreAdapter)

local EconomyService = {}

type Session = {
	Status: "Loading" | "Loaded" | "Unavailable",
	Profile: Types.Profile?,
	Store: ProfileSession.Session?, -- set once loaded
	Key: string,
	Leaving: boolean,
	NextClaim: number, -- os.clock() time of the next ledger check
	ClaimFailures: number,
	Claiming: boolean,
}

local sessions: { [Player]: Session } = {}
type Orphan = { Name: string, Store: ProfileSession.Session, Since: number }
local orphans: { [string]: Orphan } = {} -- key -> session whose save on leave failed
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

local function newProfileSession(player: Player, key: string, profile: Types.Profile): ProfileSession.Session
	return ProfileSession.new(store, key, sessionId, profile, EconomyConfig, {
		Log = function(text: string)
			log(`{player.Name}: {text}`)
		end,
	})
end

-- The ProfileSession closed under us (lock lost / taken over): stop treating data as loaded.
local function checkClosed(player: Player, session: Session)
	local ps = session.Store
	if ps and ps.Closed and ps.CloseReason == "LockLost" and session.Status == "Loaded" then
		session.Status = "Unavailable"
		publish(player, session)
		warn(`[Economy] {player.Name}: another server owns this profile now; this server stops changing it`)
	end
end

local function scheduleClaim(session: Session, ok: boolean, outstanding: number)
	if ok then
		session.ClaimFailures = 0
		session.NextClaim = os.clock() + (if outstanding > 0 then EconomyConfig.ClaimRetryBase else EconomyConfig.ClaimIdleInterval)
	else
		session.ClaimFailures += 1
		local delay = math.min(EconomyConfig.ClaimRetryBase * 2 ^ (session.ClaimFailures - 1), EconomyConfig.ClaimRetryMax)
		session.NextClaim = os.clock() + delay
	end
end

-- Pays what the reward ledger still holds (earned earlier, here or elsewhere, but not stored
-- then), prunes PaidRewards the ledger no longer lists, and marks lasting refusals Blocked.
local function claimRewards(player: Player, session: Session)
	local ps = session.Store
	if not ps or session.Claiming or session.Status ~= "Loaded" then
		return
	end
	session.Claiming = true
	local rewards, listErr, malformed = RewardLedger.list(rewardStore, rewardKeyFor(session.Key))
	if not rewards then
		log(`{player.Name}: reward ledger unreadable ({listErr}); retrying later`)
		if listErr == "LedgerCorrupt" then
			warn(`[Economy] {player.Name}: reward ledger record is corrupt; left untouched for review`)
		end
		scheduleClaim(session, false, 0)
		session.Claiming = false
		return
	end
	if malformed > 0 then
		warn(`[Economy] {player.Name}: reward ledger has {malformed} malformed entr(y/ies); kept untouched for review`)
	end
	local inLedger = {}
	for _, r in rewards do
		table.insert(inLedger, r.TxId)
	end
	local needsWrite = #rewards > 0
	for _, txId in (session.Profile :: Types.Profile).PaidRewards do
		if not table.find(inLedger, txId) then
			needsWrite = true -- something to prune
			break
		end
	end
	if not needsWrite then
		scheduleClaim(session, true, 0)
		session.Claiming = false
		return
	end
	local result: RewardLedger.ClaimResult = { Settled = {}, Blocked = {}, Retry = {} }
	local ok, err = ProfileSession.commit(ps, function(draft)
		EconomyRules.prunePaidRewards(draft, inLedger)
		result = RewardLedger.applyAll(draft, rewards, EconomyConfig)
		return true, nil
	end)
	checkClosed(player, session)
	if ok then
		publish(player, session)
		if #result.Settled > 0 then
			log(`{player.Name}: settled {#result.Settled} recorded reward(s) -> cash {(session.Profile :: Types.Profile).Cash}`)
		end
		for txId, reason in result.Blocked do
			warn(`[Economy] {player.Name}: recorded reward {txId} blocked ({reason}); kept in the ledger and retried later`)
		end
		local updated = RewardLedger.update(rewardStore, rewardKeyFor(session.Key), result)
		local outstanding = #rewards - #result.Settled
		scheduleClaim(session, updated, outstanding)
	else
		log(`{player.Name}: claiming recorded rewards failed ({err}); retrying later`)
		scheduleClaim(session, false, #rewards)
	end
	session.Claiming = false
end

local function adoptLoaded(player: Player, session: Session, profile: Types.Profile)
	session.Profile = profile
	session.Store = newProfileSession(player, session.Key, profile)
	session.Status = "Loaded"
	session.NextClaim = 0 -- claim right away
	publish(player, session)
end

local function tryLoad(player: Player, session: Session): boolean
	for attempt = 1, EconomyConfig.LoadAttempts do
		local profile, result, detail = ProfileStore.load(store, session.Key, sessionId, os.time(), EconomyConfig)
		if profile then
			if player.Parent ~= Players or session.Leaving then
				return false
			end
			adoptLoaded(player, session, profile)
			log(`{player.Name}: loaded ({result}) cash={profile.Cash}`)
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
	if player.Parent ~= Players or session.Leaving then
		return
	end
	session.Status = "Unavailable"
	publish(player, session)
	log(`{player.Name}: data unavailable; cash changes disabled and nothing will be saved until it loads`)
	while player.Parent == Players and not session.Leaving and session.Status ~= "Loaded" do
		task.wait(EconomyConfig.FailedRetryInterval)
		if player.Parent == Players and not session.Leaving and tryLoad(player, session) then
			log(`{player.Name}: recovered after a failed load`)
		end
	end
end

-- Background retries for sessions whose save on leave failed. Every change was already stored
-- when it happened; this releases the lock (reconciling first if a write was ambiguous).
local function retryOrphan(key: string, orphan: Orphan)
	while orphans[key] == orphan do
		task.wait(EconomyConfig.OrphanRetryInterval)
		if orphans[key] ~= orphan then
			return
		end
		local ok = ProfileSession.save(orphan.Store, true)
		if ok then
			orphans[key] = nil
			log(`{orphan.Name}: released after leaving (cash={orphan.Store.Profile.Cash})`)
		elseif orphan.Store.Closed then
			orphans[key] = nil
			log(`{orphan.Name}: another server owns this profile now; nothing to release`)
		elseif os.clock() - orphan.Since > EconomyConfig.OrphanRetryLimit then
			orphans[key] = nil
			ProfileSession.close(orphan.Store, "GaveUp")
			warn(`[Economy] {orphan.Name}: gave up releasing the lock after {EconomyConfig.OrphanRetryLimit}s (it expires by itself)`)
		end
	end
end

local function loadedSession(player: Player): (Session?, Types.EconomyError?)
	local session = sessions[player]
	if not session or player.Parent ~= Players or session.Leaving then
		return nil, "NotInGame"
	end
	if session.Status ~= "Loaded" or not session.Store then
		return nil, "DataNotLoaded"
	end
	return session, nil
end

-- One write-through change for a loaded player. Returns (ok, err).
local function commitChange(player: Player, label: string, mutate: (Types.Profile) -> (boolean, string?)): (boolean, Types.EconomyError?)
	local session, err = loadedSession(player)
	if not session then
		return false, err
	end
	local ok, changeErr, note = ProfileSession.commit(session.Store :: ProfileSession.Session, mutate)
	checkClosed(player, session)
	if ok then
		publish(player, session)
		log(`{player.Name}: {label} -> {(session.Profile :: Types.Profile).Cash} (stored{if note then ", " .. note else ""})`)
	else
		log(`{player.Name}: {label} refused: {changeErr}`)
	end
	return ok, changeErr :: any
end

-- Server-only API. txId must be unique per real-world event; repeats are refused. Returns true
-- only once the change is stored.
function EconomyService.grant(player: Player, amount: number, txId: string, reason: string): (boolean, Types.EconomyError?)
	return commitChange(player, `grant {tostring(amount)} ({reason}, tx {tostring(txId)})`, function(draft)
		return EconomyRules.grant(draft, amount, txId, EconomyConfig)
	end)
end

function EconomyService.deduct(player: Player, amount: number, txId: string, reason: string): (boolean, Types.EconomyError?)
	return commitChange(player, `deduct {tostring(amount)} ({reason}, tx {tostring(txId)})`, function(draft)
		return EconomyRules.deduct(draft, amount, txId, EconomyConfig)
	end)
end

-- A reward the player has EARNED (robbery payout). Recorded in the reward ledger first, then
-- paid write-through (its id kept in PaidRewards). Returns (paid, err, recorded): if not paid but
-- recorded, the periodic/next-load claim pays it, never twice.
function EconomyService.grantReward(player: Player, amount: number, txId: string, reason: string): (boolean, Types.EconomyError?, boolean)
	local recorded, recordErr = RewardLedger.record(rewardStore, rewardKeyFor(keyFor(player)), { TxId = txId, Amount = amount, Reason = reason, At = os.time() }, EconomyConfig.LedgerMaxEntries)
	if not recorded then
		warn(`[Economy] {player.Name}: reward {txId} could not be recorded in the ledger ({recordErr}); paying directly`)
	end
	local paid, err = commitChange(player, `reward {amount} ({reason}, tx {txId})`, function(draft)
		return EconomyRules.payReward(draft, amount, txId, EconomyConfig)
	end)
	if paid or err == "DuplicateTransaction" then
		RewardLedger.remove(rewardStore, rewardKeyFor(keyFor(player)), { txId }) -- best effort
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

-- Server-only purchase: price and ownership are stored together in one write BEFORE the
-- purchase takes effect. SaveFailed: nothing charged. SaveUnconfirmed: the write's outcome
-- couldn't be checked; the next operation reconciles, so it is applied at most once.
function EconomyService.purchaseVehicle(player: Player, vehicleId: string, price: number, txId: string): (boolean, Types.EconomyError?)
	if RunService:IsStudio() and Workspace:GetAttribute("SimulatePurchaseError") == true then
		error("Simulated purchase error (Studio test)") -- tests that callers clean up after errors
	end
	return commitChange(player, `purchase {tostring(vehicleId)} for {tostring(price)} (tx {tostring(txId)})`, function(draft)
		return EconomyRules.purchaseVehicle(draft, vehicleId, price, txId, EconomyConfig)
	end)
end

-- Unique transaction id helper for server systems.
function EconomyService.newTransactionId(prefix: string): string
	return `{prefix}:{HttpService:GenerateGUID(false)}`
end

-- Studio test hook: save now (as if autosaving).
function EconomyService.saveNowForTesting(player: Player): boolean
	assert(RunService:IsStudio(), "Studio-only")
	local session = sessions[player]
	return session ~= nil and session.Store ~= nil and (ProfileSession.save(session.Store :: ProfileSession.Session, false))
end

-- Studio test hook: writes a reward straight into this player's ledger (as if another server
-- had recorded it but couldn't pay it), for testing the periodic claim.
function EconomyService.addLedgerRewardForTesting(player: Player, amount: number): (boolean, string?)
	assert(RunService:IsStudio(), "Studio-only")
	return RewardLedger.record(rewardStore, rewardKeyFor(keyFor(player)), { TxId = EconomyService.newTransactionId("test"), Amount = amount, Reason = "Studio ledger test", At = os.time() }, EconomyConfig.LedgerMaxEntries)
end

-- Studio test hook: run the ledger claim now.
function EconomyService.claimNowForTesting(player: Player): boolean
	assert(RunService:IsStudio(), "Studio-only")
	local session = sessions[player]
	if not session then
		return false
	end
	claimRewards(player, session)
	return true
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
	if not session or session.Status ~= "Loaded" or not session.Profile or not session.Store then
		return false
	end
	local profile = session.Profile :: Types.Profile
	local ok = pcall(function()
		store:UpdateAsync(session.Key, function()
			return { Profile = { Version = 1, Cash = profile.Cash, RecentTransactions = table.clone(profile.RecentTransactions) } }
		end)
	end)
	if ok then
		ProfileSession.close(session.Store :: ProfileSession.Session, "TestLegacy")
		session.Status = "Unavailable" -- nothing more is saved this session
		publish(player, session)
		log(`{player.Name}: Studio test: stored record rewritten as version 1 (cash={profile.Cash}); rejoin to migrate`)
	end
	return ok
end

local function onPlayerAdded(player: Player)
	local session: Session = {
		Status = "Loading",
		Profile = nil,
		Store = nil,
		Key = keyFor(player),
		Leaving = false,
		NextClaim = math.huge,
		ClaimFailures = 0,
		Claiming = false,
	}
	sessions[player] = session
	local orphan = orphans[session.Key]
	if orphan and not orphan.Store.Closed then
		-- Rejoined this server before its leave-save went through: it still holds the lock and
		-- the session's profile matches what was stored by the write-through commits.
		orphans[session.Key] = nil
		orphan.Store.Leaving = false
		session.Profile = orphan.Store.Profile
		session.Store = orphan.Store
		session.Status = "Loaded"
		session.NextClaim = 0
		publish(player, session)
		log(`{player.Name}: rejoined; using the profile kept on this server (cash={orphan.Store.Profile.Cash})`)
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
	local ps = session.Store
	if session.Status == "Loaded" and ps then
		-- From here no queued or new commit may run; only the final save.
		ProfileSession.beginLeave(ps)
		local ok = ProfileSession.save(ps, true)
		if ok then
			log(`{player.Name}: saved on leave (cash={ps.Profile.Cash})`)
		elseif not ps.Closed then
			local orphan: Orphan = { Name = player.Name, Store = ps, Since = os.clock() }
			orphans[session.Key] = orphan
			warn(`[Economy] {player.Name}: save on leave failed; retrying in the background (every change was already stored when it happened)`)
			task.spawn(retryOrphan, session.Key, orphan)
		end
	else
		if ps then
			ProfileSession.close(ps, "Left")
		end
		log(`{player.Name}: left with data {session.Status}; nothing saved (protects stored progress)`)
	end
	if sessions[player] == session then
		sessions[player] = nil
	end
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
				if ProfileSession.save(orphan.Store, true) then
					orphans[key] = nil
					log(`{orphan.Name}: released at shutdown (cash={orphan.Store.Profile.Cash})`)
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
	-- player is here (reconciling first if a write was ambiguous).
	task.spawn(function()
		while true do
			task.wait(EconomyConfig.AutosaveInterval)
			for player, session in sessions do
				local ps = session.Store
				if session.Status == "Loaded" and not session.Leaving and ps then
					task.spawn(function()
						ProfileSession.save(ps, false)
						checkClosed(player, session)
					end)
				end
			end
		end
	end)
	-- Reward ledger claims: right after load, then periodically with bounded backoff.
	task.spawn(function()
		while true do
			task.wait(2)
			local now = os.clock()
			for player, session in sessions do
				if session.Status == "Loaded" and not session.Leaving and not session.Claiming and now >= session.NextClaim then
					task.spawn(claimRewards, player, session)
				end
			end
		end
	end)
end

return EconomyService
