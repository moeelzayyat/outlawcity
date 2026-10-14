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
local store: any
-- A Studio playtest has no JobId; give each server a unique lock id either way.
local sessionId = if game.JobId ~= "" then game.JobId else "studio-" .. HttpService:GenerateGUID(false)

local function log(text: string)
	print(`[Economy] {text}`)
end

local function publish(player: Player, session: Session)
	player:SetAttribute(PlayerAttributes.CashStatus, session.Status)
	player:SetAttribute(PlayerAttributes.Cash, if session.Profile then session.Profile.Cash else nil)
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

local function save(player: Player, session: Session, release: boolean): boolean
	if session.Status ~= "Loaded" or not session.Profile then
		return false -- never write for a profile we didn't load
	end
	for attempt = 1, EconomyConfig.SaveAttempts do
		local ok, err, detail = ProfileStore.save(store, session.Key, sessionId, session.Profile, os.time(), release)
		if ok then
			session.Dirty = false
			return true
		end
		log(`{player.Name}: save attempt {attempt} failed ({err}{if detail then ": " .. detail else ""})`)
		if err == "LockLost" then
			return false
		end
		if attempt < EconomyConfig.SaveAttempts then
			task.wait(EconomyConfig.RetryBaseDelay * 2 ^ (attempt - 1))
		end
	end
	return false
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

local function onPlayerAdded(player: Player)
	local session: Session = { Status = "Loading", Profile = nil, Dirty = false, Key = keyFor(player), Leaving = false }
	sessions[player] = session
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
		if save(player, session, true) then
			log(`{player.Name}: saved on leave (cash={(session.Profile :: Types.Profile).Cash})`)
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
