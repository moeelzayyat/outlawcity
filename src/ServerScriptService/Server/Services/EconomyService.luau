--!strict
-- The ONE place player cash changes. Server-authoritative balances, persisted in a DataStore.
--  * Load on join with retries + exponential backoff and a session lock (ProfileStore).
--  * If loading fails, the player is marked "Unavailable": no cash changes, and NOTHING is
--    saved for them (so a DataStore outage can never overwrite real progress with defaults).
--    Loading is retried in the background until it succeeds.
--  * grant/deduct go through EconomyRules (whole positive amounts, caps, duplicate
--    transaction ids, insufficient funds). There is no client remote that changes cash.
--  * Autosave every AutosaveInterval for changed profiles; save + release on leave and on
--    server shutdown.
--  * If the save on leave fails, the profile is kept as an "orphan" and its save retried in
--    the background (and at shutdown), so cash already earned isn't silently dropped. A
--    player who rejoins this server before it saves gets that newer profile back.
-- Future systems (robbery rewards, vehicle purchases) call grant/deduct with their own
-- unique transaction ids, e.g. "robbery:<serverJob>:<n>", so retries can't pay twice.
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
local DataStoreAdapter = require(Data.DataStoreAdapter)

local EconomyService = {}

type Session = {
	Status: "Loading" | "Loaded" | "Unavailable",
	Profile: Types.Profile?,
	Dirty: boolean,
	Key: string,
	Leaving: boolean,
}

local sessions: { [Player]: Session } = {}
type Orphan = { Name: string, Profile: Types.Profile, Since: number }
local orphans: { [string]: Orphan } = {} -- key -> profile whose save on leave failed
local store: any
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

local function tryLoad(player: Player, session: Session): boolean
	for attempt = 1, EconomyConfig.LoadAttempts do
		local profile, result, detail = ProfileStore.load(store, session.Key, sessionId, os.time(), EconomyConfig)
		if profile then
			session.Profile = profile
			session.Status = "Loaded"
			publish(player, session)
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
	if session.Status ~= "Loaded" or not session.Profile then
		return false -- never write for a profile we didn't load
	end
	local ok = saveProfile(player.Name, session.Key, session.Profile :: Types.Profile, release, EconomyConfig.SaveAttempts)
	if ok then
		session.Dirty = false
	end
	return ok
end

-- Background retries for profiles whose save on leave failed.
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
			warn(`[Economy] {orphan.Name}: another server owns this profile now; unsaved changes dropped (cash={orphan.Profile.Cash})`)
		elseif os.clock() - orphan.Since > EconomyConfig.OrphanRetryLimit then
			orphans[key] = nil
			warn(`[Economy] {orphan.Name}: gave up saving after {EconomyConfig.OrphanRetryLimit}s; unsaved cash={orphan.Profile.Cash}`)
		end
	end
end

local function change(player: Player, kind: "grant" | "deduct", amount: any, txId: any, reason: string): (boolean, Types.EconomyError?)
	local session = sessions[player]
	if not session or player.Parent ~= Players then
		return false, "NotInGame"
	end
	if session.Status ~= "Loaded" or not session.Profile then
		return false, "DataNotLoaded"
	end
	local profile = session.Profile :: Types.Profile
	local ok, err
	if kind == "grant" then
		ok, err = EconomyRules.grant(profile, amount, txId, EconomyConfig)
	else
		ok, err = EconomyRules.deduct(profile, amount, txId, EconomyConfig)
	end
	if ok then
		session.Dirty = true
		publish(player, session)
		log(`{player.Name}: {kind} {amount} ({reason}, tx {txId}) -> {profile.Cash}`)
	else
		log(`{player.Name}: {kind} {tostring(amount)} refused: {err} ({reason}, tx {tostring(txId)})`)
	end
	return ok, err
end

-- Server-only API. txId must be unique per real-world event; repeats are refused.
function EconomyService.grant(player: Player, amount: number, txId: string, reason: string): (boolean, Types.EconomyError?)
	return change(player, "grant", amount, txId, reason)
end

function EconomyService.deduct(player: Player, amount: number, txId: string, reason: string): (boolean, Types.EconomyError?)
	return change(player, "deduct", amount, txId, reason)
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

-- Server-only purchase: price and ownership change together on the profile, then it is saved
-- right away (and again by autosave/leave if that save fails; both always travel together).
function EconomyService.purchaseVehicle(player: Player, vehicleId: string, price: number, txId: string): (boolean, Types.EconomyError?)
	local session = sessions[player]
	if not session or player.Parent ~= Players then
		return false, "NotInGame"
	end
	if session.Status ~= "Loaded" or not session.Profile then
		return false, "DataNotLoaded"
	end
	local profile = session.Profile :: Types.Profile
	local ok, err = EconomyRules.purchaseVehicle(profile, vehicleId, price, txId, EconomyConfig)
	if not ok then
		log(`{player.Name}: purchase {tostring(vehicleId)} for {tostring(price)} refused: {err} (tx {tostring(txId)})`)
		return false, err
	end
	session.Dirty = true
	publish(player, session)
	log(`{player.Name}: bought {vehicleId} for {price} (tx {txId}) -> cash {profile.Cash}`)
	task.spawn(function()
		if save(player, session, false) then
			log(`{player.Name}: purchase saved`)
		end
	end)
	return true, nil
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
	local session: Session = { Status = "Loading", Profile = nil, Dirty = false, Key = keyFor(player), Leaving = false }
	sessions[player] = session
	local orphan = orphans[session.Key]
	if orphan then
		-- Rejoined this server before its unsaved profile was written: that copy is the newest
		-- data and this server still holds the lock, so use it instead of the stored record.
		orphans[session.Key] = nil
		session.Profile = orphan.Profile
		session.Status = "Loaded"
		session.Dirty = true
		publish(player, session)
		log(`{player.Name}: rejoined; using the unsaved profile kept on this server (cash={orphan.Profile.Cash})`)
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
			warn(`[Economy] {player.Name}: save on leave failed; keeping the profile and retrying (cash={profile.Cash})`)
			task.spawn(retryOrphan, session.Key, orphan)
		end
	else
		log(`{player.Name}: left with data {session.Status}; nothing saved (protects stored progress)`)
	end
	sessions[player] = nil
end

function EconomyService.init()
	store = DataStoreAdapter.get(EconomyConfig.DataStoreName)
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
	task.spawn(function()
		while true do
			task.wait(EconomyConfig.AutosaveInterval)
			for player, session in sessions do
				if session.Dirty and not session.Leaving then
					task.spawn(save, player, session, false)
				end
			end
		end
	end)
end

return EconomyService
