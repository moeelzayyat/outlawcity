--!strict
-- Server authority for store robberies (Phase 4B). Owns every robbery session; the client only
-- triggers the register's ProximityPrompt and displays what the server publishes.
--
-- Flow: prompt -> validate (alive, not jailed, not in a safe zone, on foot, near the register,
-- store free and off cooldown, no session already) -> server GUID session, StoreRobbery crime
-- (2 stars) -> 15 s holdout inside the store -> Escaping -> WantedService.Escaped while
-- Escaping -> EconomyService.grant(reward, "robbery:<id>") exactly once.
-- Death/reset, bust/jail, leaving the store and disconnecting end the session with no cash.
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

local RobberyService = {}

type Store = {
	Id: string,
	State: RobberyRules.StoreState,
	Register: BasePart,
	Area: BasePart,
}
type Live = { Session: RobberyRules.Session, Character: Model, LastInProgressReport: number }

local stores: { [string]: Store } = {}
local live: { [Player]: Live } = {}
local paidIds: { [string]: boolean } = {} -- belt and braces next to EconomyService's own tx guard
local noticeRemote: RemoteEvent

local function now(): number
	return Workspace:GetServerTimeNow()
end

local function notify(player: Player, kind: string, payload: { [string]: any })
	if player.Parent == Players then
		noticeRemote:FireClient(player, kind, payload)
	end
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
	publish(player, nil)
end

local function failSession(player: Player, entry: Live, reason: Types.RobberyFailReason)
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
		HasActiveSession = live[player] ~= nil,
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
	WantedService.reportCrime(player, RobberyConfig.WantedCrime)
	publish(player, session)
	notify(player, "Started", { Id = session.Id, HoldEndsAt = session.HoldEndsAt, Reward = session.Reward })
	print(`[Robbery] {player.Name} started {session.Id} at {storeId}`)
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
			publish(player, session)
			notify(player, "Escape", { Id = session.Id, Reward = session.Reward, Deadline = session.EscapeDeadline })
			print(`[Robbery] {player.Name} {session.Id} holdout complete; escaping`)
		elseif session.Phase == "Holding" and t - entry.LastInProgressReport >= 1 then
			-- Keep the robber hot while inside so heat can't decay before the holdout ends.
			entry.LastInProgressReport = t
			WantedService.reportCrime(player, RobberyConfig.InProgressCrime)
		end
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
	if paidIds[session.Id] then
		return
	end
	paidIds[session.Id] = true
	local ok, err = EconomyService.grant(player, session.Reward, "robbery:" .. session.Id, "store robbery " .. session.StoreId)
	if ok then
		notify(player, "Paid", { Id = session.Id, Amount = session.Reward })
		print(`[Robbery] {player.Name} {session.Id} escaped; paid {session.Reward}`)
	else
		notify(player, "PayoutFailed", { Id = session.Id, Reason = err })
		warn(`[Robbery] {player.Name} {session.Id} payout failed: {tostring(err)}`)
	end
end

-- Studio dev tools only: lets a solo tester rob again without waiting out the cooldown.
function RobberyService.clearCooldownsForTesting()
	for _, store in stores do
		store.State.CooldownUntil = -math.huge
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
	stores[id] = { Id = id, State = RobberyRules.newStore(), Register = register, Area = area }
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
		end
	end)
end

return RobberyService
