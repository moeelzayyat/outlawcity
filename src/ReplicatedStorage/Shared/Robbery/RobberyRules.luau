--!strict
-- Pure robbery state machine. The server (RobberyService) owns clocks, positions and payouts;
-- these rules only decide. Unit-tested in ServerStorage.Tests.RobberyRules.spec.
--
--   start ──► Holding ──(HoldSeconds, stayed alive, inside, not jailed)──► Escaping
--                 │                                                            │
--                 └──► Failed (Died | Busted | LeftArea | Disconnected)        ├──(escaped police)──► Paid (once)
--                                                                              └──► Failed (Died | Busted | Disconnected | EscapeTimedOut)
local Types = require(script.Parent.Parent.Types)

local RobberyRules = {}

export type StoreState = { CooldownUntil: number, ActiveSession: string?, LastSession: string? }
export type Session = {
	Id: string,
	UserId: number,
	StoreId: string,
	Phase: Types.RobberyPhase,
	StartedAt: number,
	HoldEndsAt: number,
	EscapeDeadline: number,
	Reward: number,
	FailReason: Types.RobberyFailReason?,
}
export type StartFacts = {
	Alive: boolean,
	Jailed: boolean,
	InSafeZone: boolean,
	InVehicle: boolean,
	DistanceToRegister: number,
	HasActiveSession: boolean,
	CashReady: boolean, -- the player's cash profile is loaded, so a reward can be recorded
}
export type TickFacts = { Connected: boolean, Alive: boolean, Jailed: boolean, InArea: boolean }
type Config = {
	HoldSeconds: number,
	Reward: number,
	CooldownSeconds: number,
	FailedCooldownSeconds: number?, -- shorter cooldown after a failed robbery (nil = same as CooldownSeconds)
	PromptDistance: number,
	DistanceSlack: number,
	MaxEscapeSeconds: number,
}

function RobberyRules.newStore(): StoreState
	return { CooldownUntil = -math.huge, ActiveSession = nil, LastSession = nil }
end

function RobberyRules.canStart(store: StoreState, facts: StartFacts, now: number, config: Config): (boolean, Types.RobberyStartError?)
	if not facts.Alive then
		return false, "Dead"
	end
	if facts.Jailed then
		return false, "Jailed"
	end
	if facts.InSafeZone then
		return false, "InSafeZone"
	end
	if facts.InVehicle then
		return false, "InVehicle"
	end
	if facts.HasActiveSession then
		return false, "AlreadyRobbing"
	end
	if not facts.CashReady then
		return false, "CashUnavailable" -- don't start a mission whose reward couldn't be recorded
	end
	if not (facts.DistanceToRegister <= config.PromptDistance + config.DistanceSlack) then
		return false, "TooFar" -- also catches NaN distances
	end
	if store.ActiveSession ~= nil then
		return false, "StoreBusy"
	end
	if now < store.CooldownUntil then
		return false, "StoreCooldown"
	end
	return true, nil
end

-- Opens a session (call only after canStart). The store cools down from now.
function RobberyRules.start(store: StoreState, sessionId: string, userId: number, storeId: string, now: number, config: Config): Session
	store.ActiveSession = sessionId
	store.LastSession = sessionId
	store.CooldownUntil = now + config.CooldownSeconds
	return {
		Id = sessionId,
		UserId = userId,
		StoreId = storeId,
		Phase = "Holding",
		StartedAt = now,
		HoldEndsAt = now + config.HoldSeconds,
		EscapeDeadline = math.huge,
		Reward = config.Reward,
		FailReason = nil,
	}
end

-- A failed robbery may shorten the store's cooldown (FailedCooldownSeconds, counted from the
-- start), but only while this session is still the store's latest: a late failure of an old
-- getaway never cuts the cooldown of a newer robbery. Only reached from a live phase (tick
-- returns nothing once a session is Failed or Paid), so a session fails, and changes the
-- cooldown, at most once.
local function fail(session: Session, store: StoreState?, reason: Types.RobberyFailReason, config: Config): (string, Types.RobberyFailReason)
	session.Phase = "Failed"
	session.FailReason = reason
	if store and store.ActiveSession == session.Id then
		store.ActiveSession = nil
	end
	local failed = config.FailedCooldownSeconds
	if store and failed ~= nil and store.LastSession == session.Id then
		store.CooldownUntil = math.min(store.CooldownUntil, session.StartedAt + failed)
	end
	return "Failed", reason
end

-- Advances a live session. Returns ("HoldComplete" | "Failed" | nil, failReason?).
function RobberyRules.tick(session: Session, store: StoreState?, facts: TickFacts, now: number, config: Config): (string?, Types.RobberyFailReason?)
	if session.Phase == "Holding" then
		if not facts.Connected then
			return fail(session, store, "Disconnected", config)
		elseif not facts.Alive then
			return fail(session, store, "Died", config)
		elseif facts.Jailed then
			return fail(session, store, "Busted", config)
		elseif not facts.InArea then
			return fail(session, store, "LeftArea", config)
		elseif now >= session.HoldEndsAt then
			session.Phase = "Escaping"
			session.EscapeDeadline = now + config.MaxEscapeSeconds
			if store and store.ActiveSession == session.Id then
				store.ActiveSession = nil
			end
			return "HoldComplete", nil
		end
	elseif session.Phase == "Escaping" then
		if not facts.Connected then
			return fail(session, store, "Disconnected", config)
		elseif facts.Jailed then
			return fail(session, store, "Busted", config)
		elseif not facts.Alive then
			return fail(session, store, "Died", config)
		elseif now > session.EscapeDeadline then
			return fail(session, store, "EscapeTimedOut", config)
		end
	end
	return nil, nil
end

-- The player escaped the police. Pays exactly once, and only from the Escaping phase.
function RobberyRules.onEscaped(session: Session): boolean
	if session.Phase ~= "Escaping" then
		return false
	end
	session.Phase = "Paid"
	return true
end

-- Classifies the result of EconomyService.grant for a robbery reward. Only temporary failures
-- (cash data not loaded right now) keep the reward pending for another try; a duplicate
-- transaction means this exact reward was already paid.
function RobberyRules.payoutOutcome(ok: boolean, err: string?): Types.PayoutOutcome
	if ok then
		return "Paid"
	elseif err == "DuplicateTransaction" then
		return "AlreadyPaid"
	elseif err == "DataNotLoaded" or err == "SaveFailed" or err == "SaveUnconfirmed" or err == "SessionClosed" or err == "RewardHistoryFull" then
		return "Retry" -- temporary: the data isn't loaded, or the write didn't go through
	end
	return "Rejected"
end

function RobberyRules.isLive(session: Session): boolean
	return session.Phase == "Holding" or session.Phase == "Escaping"
end

return RobberyRules
