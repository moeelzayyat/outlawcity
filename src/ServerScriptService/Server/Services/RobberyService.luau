--!strict
-- Server authority for store robberies (Phase 4B). Owns every robbery session; the client only
-- triggers the register's ProximityPrompt and displays what the server publishes.
--
-- Flow: prompt -> validate (alive, not jailed, not in a safe zone, on foot, near the register,
-- store free and off cooldown, no session already) -> server GUID session, StoreRobbery crime
-- (2 stars) -> 15 s holdout inside the store -> Escaping -> WantedService.Escaped while
-- Escaping -> EconomyService.grant(reward, "robbery:<id>") exactly once.
-- Death/reset, bust/jail, leaving the store and disconnecting end the session with no cash.
-- Recoverable payout: a robbery only starts while the player's cash data is loaded. If the
-- grant still fails temporarily at escape time, the reward stays pending (same transaction
-- id) and is retried every few seconds; the economy's duplicate-transaction guard makes any
-- retry pay at most once.
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Remotes = require(Shared.Net.Remotes)
local RobberyConfig = require(Shared.Config.RobberyConfig)
local RobberyRules = require(Shared.Robbery.RobberyRules)
local PlayerAttributes = require(Shared.Player.PlayerAttributes)

local Services = script.Parent
local WorldService = require(Services.WorldService)
local WantedService = require(Services.WantedService)
local JailService = require(Services.JailService)
local EconomyService = require(Services.EconomyService)
local PoliceService = require(Services.PoliceService)
local MilestoneLog = require(script.Parent.Parent.Dev.MilestoneLog)

local RobberyService = {}

type Store = {
	Id: string,
	State: RobberyRules.StoreState,
	Register: BasePart,
	Area: BasePart,
	Folder: Instance,
}
type Live = { Session: RobberyRules.Session, Character: Model, LastInProgressReport: number }
type Pending = { TxId: string, Amount: number, SessionId: string, StoreId: string, NextTry: number, InFlight: boolean, Recorded: boolean }

local stores: { [string]: Store } = {}
local live: { [Player]: Live } = {}
local paidIds: { [string]: boolean } = {} -- belt and braces next to EconomyService's own tx guard
local pendingPayouts: { [Player]: Pending } = {} -- escaped, reward not yet recorded
local PAYOUT_RETRY_SECONDS = 2
local noticeRemote: RemoteEvent

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function notify(player: Player, kind: string, payload: { [string]: any })
	if player.Parent == Players then
		noticeRemote:FireClient(player, kind, payload)
	end
end

-- Display only: the store's cooldown and busy state for the client's marker (P5). The server
-- still decides every start in RobberyRules.canStart.
local function publishStore(store: Store)
	local cooldownUntil = store.State.CooldownUntil
	store.Folder:SetAttribute("RobberyCooldownUntil", if cooldownUntil == -math.huge then 0 else cooldownUntil)
	store.Folder:SetAttribute("RobberyBusy", store.State.ActiveSession ~= nil)
end

local function publish(player: Player, session: RobberyRules.Session?)
	local isLive = session ~= nil and RobberyRules.isLive(session)
	player:SetAttribute(PlayerAttributes.RobberyPhase, if isLive then (session :: any).Phase else nil)
	player:SetAttribute(PlayerAttributes.RobberyHoldEndsAt, if isLive then (session :: any).HoldEndsAt else nil)
	player:SetAttribute(PlayerAttributes.RobberyReward, if isLive then (session :: any).Reward else nil)
end

local function rootOf(character: Model?): BasePart?
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function isAlive(character: Model?): boolean
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	return humanoid ~= nil and humanoid.Health > 0 and rootOf(character) ~= nil
end

local function insideArea(area: BasePart, position: Vector3): boolean
	local localPos = area.CFrame:PointToObjectSpace(position)
	local half = area.Size / 2
	return math.abs(localPos.X) <= half.X and math.abs(localPos.Y) <= half.Y and math.abs(localPos.Z) <= half.Z
end

local function endSession(player: Player, entry: Live)
	if live[player] == entry then
		live[player] = nil
	end
	PoliceService.setDispatchHold(player, false)
	publish(player, nil)
end

local function failSession(player: Player, entry: Live, reason: Types.RobberyFailReason)
	if live[player] ~= entry then
		return -- already ended: a duplicate failure never notifies or changes anything twice
	end
	endSession(player, entry)
	notify(player, "Failed", { Reason = reason, Id = entry.Session.Id })
	print(`[Robbery] {player.Name} {entry.Session.Id} failed: {reason}`)
end

-- Tries to start a robbery at `storeId` for `player`. Everything is checked here, on the server.
function RobberyService.tryStart(player: Player, storeId: string): (boolean, Types.RobberyStartError?)
	local store = stores[storeId]
	if not store or player.Parent ~= Players then
		return false, "TooFar"
	end
	local character = player.Character
	local root = rootOf(character)
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local t = now()
	local facts: RobberyRules.StartFacts = {
		Alive = isAlive(character),
		Jailed = JailService.isJailed(player),
		InSafeZone = player:GetAttribute(PlayerAttributes.InSafeZone) == true,
		InVehicle = humanoid ~= nil and humanoid.SeatPart ~= nil,
		DistanceToRegister = if root then (root.Position - store.Register.Position).Magnitude else math.huge,
		HasActiveSession = live[player] ~= nil or pendingPayouts[player] ~= nil,
		CashReady = EconomyService.getStatus(player) == "Loaded",
	}
	local ok, err = RobberyRules.canStart(store.State, facts, t, RobberyConfig)
	if not ok then
		notify(player, "Rejected", {
			Reason = err,
			CooldownLeft = if err == "StoreCooldown" then math.ceil(store.State.CooldownUntil - t) else nil,
		})
		return false, err
	end
	local session = RobberyRules.start(store.State, HttpService:GenerateGUID(false), player.UserId, storeId, t, RobberyConfig)
	local entry: Live = { Session = session, Character = character :: Model, LastInProgressReport = t }
	live[player] = entry
	if RobberyConfig.PoliceDispatchAtHoldEnd then
		PoliceService.setDispatchHold(player, true)
	end
	WantedService.reportCrime(player, RobberyConfig.WantedCrime)
	publish(player, session)
	publishStore(store)
	notify(player, "Started", { Id = session.Id, HoldEndsAt = session.HoldEndsAt, Reward = session.Reward })
	print(`[Robbery] {player.Name} started {session.Id} at {storeId}`)
	MilestoneLog.mark(player, "FirstRobbery")
	return true, nil
end

local function tick()
	local t = now()
	for player, entry in live do
		local session = entry.Session
		local store = stores[session.StoreId]
		local character = player.Character
		local sameCharacter = character == entry.Character
		local root = rootOf(character)
		local facts: RobberyRules.TickFacts = {
			Connected = player.Parent == Players,
			Alive = sameCharacter and isAlive(character), -- a reset or respawn counts as death
			Jailed = JailService.isJailed(player),
			InArea = store ~= nil and root ~= nil and insideArea(store.Area, root.Position),
		}
		local event, reason = RobberyRules.tick(session, store and store.State, facts, t, RobberyConfig)
		if event == "Failed" then
			failSession(player, entry, reason :: Types.RobberyFailReason)
		elseif event == "HoldComplete" then
			PoliceService.setDispatchHold(player, false) -- police respond now
			publish(player, session)
			notify(player, "Escape", { Id = session.Id, Reward = session.Reward, Deadline = session.EscapeDeadline })
			print(`[Robbery] {player.Name} {session.Id} holdout complete; escaping`)
		elseif session.Phase == "Holding" and t - entry.LastInProgressReport >= 1 then
			-- Keep the robber hot while inside so heat can't decay before the holdout ends.
			entry.LastInProgressReport = t
			WantedService.reportCrime(player, RobberyConfig.InProgressCrime)
		end
	end
	for _, store in stores do
		publishStore(store)
	end
end

local function onEscaped(player: Player)
	local entry = live[player]
	if not entry then
		return -- not robbing: an ordinary escape pays nothing
	end
	local session = entry.Session
	if not RobberyRules.onEscaped(session) then
		return -- still holding (or already settled): never pays
	end
	endSession(player, entry)
	MilestoneLog.mark(player, "FirstEscape")
	if paidIds[session.Id] then
		return
	end
	pendingPayouts[player] = {
		TxId = "robbery:" .. session.Id, -- stable: every retry uses the same id
		Amount = session.Reward,
		SessionId = session.Id,
		StoreId = session.StoreId,
		NextTry = 0,
		InFlight = false,
		Recorded = false,
	}
	RobberyService.tryPayout(player)
end

-- One payout attempt for a pending reward. Returns the outcome (nil if nothing pending).
function RobberyService.tryPayout(player: Player): Types.PayoutOutcome?
	local pending = pendingPayouts[player]
	if not pending or pending.InFlight then
		return nil
	end
	-- Recorded in the durable reward ledger first, then granted write-through (EconomyService).
	pending.InFlight = true
	local ok, err, recorded = EconomyService.grantReward(player, pending.Amount, pending.TxId, "store robbery " .. pending.StoreId)
	pending.InFlight = false
	pending.Recorded = pending.Recorded or recorded
	local outcome = RobberyRules.payoutOutcome(ok, err)
	if outcome == "Retry" then
		if pending.NextTry == 0 then
			player:SetAttribute(PlayerAttributes.RobberyPhase, "PayoutPending")
			player:SetAttribute(PlayerAttributes.RobberyReward, pending.Amount)
			notify(player, "PayoutPending", { Id = pending.SessionId, Amount = pending.Amount, Recorded = pending.Recorded })
			warn(`[Robbery] {player.Name} {pending.SessionId} payout pending ({tostring(err)}; recorded in ledger: {pending.Recorded}); retrying`)
		end
		pending.NextTry = now() + PAYOUT_RETRY_SECONDS
		return outcome
	end
	pendingPayouts[player] = nil
	paidIds[pending.SessionId] = true
	publish(player, nil)
	if outcome == "Paid" then
		notify(player, "Paid", { Id = pending.SessionId, Amount = pending.Amount })
		print(`[Robbery] {player.Name} {pending.SessionId} escaped; paid {pending.Amount}`)
	elseif outcome == "AlreadyPaid" then
		print(`[Robbery] {player.Name} {pending.SessionId} already paid (duplicate tx refused)`)
	else
		notify(player, "PayoutFailed", { Id = pending.SessionId, Reason = err })
		warn(`[Robbery] {player.Name} {pending.SessionId} payout rejected: {tostring(err)}`)
	end
	return outcome
end

-- Studio dev tools only: lets a solo tester rob again without waiting out the cooldown.
function RobberyService.clearCooldownsForTesting()
	for _, store in stores do
		store.State.CooldownUntil = -math.huge
		publishStore(store)
	end
end

function RobberyService.getSession(player: Player): RobberyRules.Session?
	local entry = live[player]
	return entry and entry.Session
end

function RobberyService.init()
	noticeRemote = Remotes.getEvent("OnRobberyNotice")
	local folder = WorldService.getStore()
	if not folder then
		warn("[Robbery] no City.Store; robberies disabled")
		return
	end
	local register = folder:FindFirstChild("StoreRegister")
	local area = folder:FindFirstChild("Area")
	local id = folder:GetAttribute("StoreId")
	if not (register and register:IsA("BasePart") and area and area:IsA("BasePart") and type(id) == "string") then
		warn("[Robbery] City.Store is incomplete; robberies disabled")
		return
	end
	stores[id] = { Id = id, State = RobberyRules.newStore(), Register = register, Area = area, Folder = folder }
	publishStore(stores[id])
	local prompt = register:FindFirstChild("RobPrompt", true)
	if prompt and prompt:IsA("ProximityPrompt") then
		prompt.Triggered:Connect(function(player)
			RobberyService.tryStart(player, id)
		end)
	end
end

function RobberyService.start()
	WantedService.Escaped:Connect(onEscaped)
	Players.PlayerRemoving:Connect(function(player)
		local pending = pendingPayouts[player]
		if pending then
			pendingPayouts[player] = nil
			if pending.Recorded then
				-- Durable: the reward ledger pays it on the player's next successful load.
				print(`[Robbery] {player.Name} left before {pending.TxId} could be stored; it is in the reward ledger and will be paid on their next join`)
			else
				-- Only if BOTH the profile and the ledger writes failed for the whole time.
				warn(`[Robbery] {player.Name} left with an unpaid reward {pending.Amount} ({pending.TxId}) that could not be recorded anywhere`)
			end
		end
		local entry = live[player]
		if entry then
			RobberyRules.tick(entry.Session, stores[entry.Session.StoreId] and stores[entry.Session.StoreId].State, {
				Connected = false, Alive = false, Jailed = false, InArea = false,
			}, now(), RobberyConfig)
			live[player] = nil
			print(`[Robbery] {player.Name} {entry.Session.Id} failed: Disconnected`)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(RobberyConfig.TickInterval)
			tick()
			local t = now()
			for player, pending in pendingPayouts do
				if player.Parent == Players and t >= pending.NextTry and not pending.InFlight then
					task.spawn(RobberyService.tryPayout, player) -- writes yield; keep the tick loop running
				end
			end
		end
	end)
end

return RobberyService
