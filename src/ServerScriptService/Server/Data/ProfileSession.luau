--!strict
-- One player's profile on this server, and the ONLY way it is written (audit remediation).
--  * Operations (commits and saves) run one at a time, strictly in arrival order (`run` hands
--    out tickets: first come, first served).
--  * Once the player is leaving, only the final release-save may still run: queued commits and
--    heartbeat saves are refused, so nothing can interleave with or follow the release.
--  * Once a session is closed (the player left, this server lost the lock, or another server
--    took ownership), every operation still queued or started later is refused with
--    "SessionClosed" and writes nothing.
--  * Write-through commits: a change is applied to a copy and stored before it takes effect
--    (ProfileStore.commit).
--  * Ambiguous writes: a write that errors may still have been stored. After any failed write
--    the session is marked Stale, and NOTHING more is written from memory until it has been
--    reconciled: the stored profile is read back (ProfileStore.read, our lock only) and adopted
--    as the truth. A commit is then re-applied to that stored state; if the stored state
--    already contains it (its transaction id is there), it reports success without applying it
--    twice. Heartbeat and leave saves reconcile first too, so a stale copy can never overwrite
--    a stored change.
-- Pure apart from the injected store and wait function; unit-tested in ProfileSession.spec.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local ProfileStore = require(script.Parent.ProfileStore)

local ProfileSession = {}

export type Session = {
	Store: any,
	Key: string,
	SessionId: string,
	Config: any,
	Profile: Types.Profile,
	Stale: boolean, -- a write failed ambiguously; reconcile before writing again
	Leaving: boolean, -- the player is leaving: only the final save may still run
	Closed: boolean,
	CloseReason: string?,
	Busy: boolean,
	NextTicket: number, -- FIFO queue: the ticket the next operation gets...
	Serving: number, -- ...and the ticket whose turn it is
	Wait: (number) -> (),
	Now: () -> number,
	Log: (string) -> (),
}

function ProfileSession.new(store: any, key: string, sessionId: string, profile: Types.Profile, config: any, options: { [string]: any }?): Session
	local opts = options or {}
	return {
		Store = store,
		Key = key,
		SessionId = sessionId,
		Config = config,
		Profile = profile,
		Stale = false,
		Leaving = false,
		Closed = false,
		CloseReason = nil,
		Busy = false,
		NextTicket = 1,
		Serving = 1,
		Wait = opts.Wait or function(seconds: number)
			task.wait(seconds)
		end,
		Now = opts.Now or os.time,
		Log = opts.Log or function() end,
	}
end

-- The player is leaving: commits queued or started from now on are refused; the final save
-- (ProfileSession.save with release) may still run.
function ProfileSession.beginLeave(session: Session)
	session.Leaving = true
end

-- Closes the session: anything queued or started later writes nothing.
function ProfileSession.close(session: Session, reason: string)
	if not session.Closed then
		session.Closed = true
		session.CloseReason = reason
	end
end

-- Runs fn with the profile to itself, strictly in arrival order (FIFO tickets). Refuses if the
-- session is (or becomes) closed before fn's turn comes; a refused ticket still passes the
-- turn on, so the queue never stalls.
function ProfileSession.run<T...>(session: Session, fn: () -> T...): (boolean, ...any)
	if session.Closed then
		return false, "SessionClosed"
	end
	local ticket = session.NextTicket
	session.NextTicket += 1
	while session.Serving ~= ticket do
		task.wait()
	end
	if session.Closed then
		session.Serving += 1
		return false, "SessionClosed"
	end
	session.Busy = true
	local results = table.pack(pcall(fn))
	session.Busy = false
	session.Serving += 1
	if not results[1] then
		error(results[2], 0)
	end
	return true, table.unpack(results, 2, results.n)
end

local function adopt(session: Session, stored: Types.Profile)
	local profile = session.Profile
	profile.Version = stored.Version
	profile.Cash = stored.Cash
	profile.RecentTransactions = stored.RecentTransactions
	profile.OwnedVehicles = stored.OwnedVehicles
	profile.PaidRewards = stored.PaidRewards
end

-- Reads the stored profile and adopts it. Returns (ok, err): "LockLost" closes the session.
local function reconcile(session: Session): (boolean, string?)
	local stored, err, detail = ProfileStore.read(session.Store, session.Key, session.SessionId, session.Config)
	if stored then
		adopt(session, stored)
		session.Stale = false
		session.Log(`reconciled from the store (cash={stored.Cash})`)
		return true, nil
	end
	if err == "LockLost" then
		ProfileSession.close(session, "LockLost")
	end
	session.Log(`reconcile failed ({err}{if detail then ": " .. detail else ""})`)
	return false, err
end

-- Write-through change. mutate(draft) applies the change to a copy (and returns ok, err); the
-- copy is stored before it takes effect. Returns (ok, err, note):
--   ok=true            stored (note "AlreadyApplied" if an earlier ambiguous write had stored it)
--   err = rule error   refused by the rules; nothing written
--   err = "SaveFailed"       not stored (confirmed by reading the store)
--   err = "SaveUnconfirmed"  writes failed and the store couldn't be read to check
--   err = "SessionClosed"    the session closed (left / lock lost) before or while running
function ProfileSession.commit(session: Session, mutate: (Types.Profile) -> (boolean, string?)): (boolean, string?, string?)
	local ran, ok, err, note = ProfileSession.run(session, function(): (boolean, string?, string?)
		local ambiguous = false
		for attempt = 1, session.Config.CommitAttempts do
			if session.Closed or session.Leaving then
				return false, "SessionClosed", session.CloseReason or "Leaving"
			end
			if session.Stale then
				local reconciled, recErr = reconcile(session)
				if not reconciled then
					if recErr == "LockLost" then
						return false, "SessionClosed", "LockLost"
					end
					if attempt < session.Config.CommitAttempts then
						session.Wait(session.Config.RetryBaseDelay * 2 ^ (attempt - 1))
					end
					continue
				end
			end
			local committed, commitErr, detail = ProfileStore.commit(session.Store, session.Key, session.SessionId, session.Profile, session.Now(), mutate)
			if committed then
				return true, nil, nil
			end
			if commitErr == "DuplicateTransaction" and ambiguous then
				-- The stored state (just reconciled) already holds this change: an earlier
				-- write that reported an error had in fact been stored.
				return true, nil, "AlreadyApplied"
			end
			if commitErr == "LockLost" then
				ProfileSession.close(session, "LockLost")
				return false, "SessionClosed", "LockLost"
			end
			if commitErr ~= "StoreError" then
				return false, commitErr, nil -- refused by the rules
			end
			-- The write may or may not have been stored: never trust memory until reconciled.
			ambiguous = true
			session.Stale = true
			session.Log(`write attempt {attempt} failed ({detail or commitErr})`)
			if attempt < session.Config.CommitAttempts then
				session.Wait(session.Config.RetryBaseDelay * 2 ^ (attempt - 1))
			end
		end
		-- Out of attempts. Settle the answer from the store if it can be read.
		if session.Stale and not session.Closed then
			local reconciled = reconcile(session)
			if reconciled then
				local probe = table.clone(session.Profile) :: any
				probe.RecentTransactions = table.clone(session.Profile.RecentTransactions)
				probe.OwnedVehicles = table.clone(session.Profile.OwnedVehicles)
				probe.PaidRewards = table.clone(session.Profile.PaidRewards)
				local _, probeErr = mutate(probe)
				if probeErr == "DuplicateTransaction" then
					return true, nil, "AlreadyApplied"
				end
				return false, "SaveFailed", nil
			end
		end
		if session.Closed then
			return false, "SessionClosed", session.CloseReason
		end
		return false, if session.Stale then "SaveUnconfirmed" else "SaveFailed", nil
	end)
	if not ran then
		return false, ok :: any, nil -- "SessionClosed"
	end
	return ok, err, note
end

-- Heartbeat / leave save. Reconciles first if a write was ambiguous, so a stale copy is never
-- written. release=true drops the lock and closes the session. Returns (ok, err).
function ProfileSession.save(session: Session, release: boolean): (boolean, string?)
	local ran, ok, err = ProfileSession.run(session, function(): (boolean, string?)
		if session.Leaving and not release then
			return false, "SessionClosed" -- only the final release-save may run once leaving
		end
		if session.Stale then
			local reconciled, recErr = reconcile(session)
			if not reconciled then
				return false, recErr -- don't write a copy that may be older than the store
			end
		end
		local saved, saveErr = ProfileStore.save(session.Store, session.Key, session.SessionId, session.Profile, session.Now(), release)
		if saved then
			if release then
				ProfileSession.close(session, "Released")
			end
			return true, nil
		end
		if saveErr == "LockLost" then
			ProfileSession.close(session, "LockLost")
		else
			session.Stale = true
		end
		return false, saveErr
	end)
	if not ran then
		return false, ok :: any
	end
	return ok, err
end

return ProfileSession
