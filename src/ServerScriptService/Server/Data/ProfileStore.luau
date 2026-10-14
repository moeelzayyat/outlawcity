--!strict
-- Loads and saves player profiles through any store with DataStore's UpdateAsync semantics
-- (the real DataStore, or an in-memory fake in tests). Each record is
-- { Profile = Types.Profile, Lock = { Id = sessionId, At = unixTime }? }.
-- Safety rules:
--  * Load claims the session lock atomically; another live server's lock refuses the load.
--  * Existing valid data is never replaced by defaults; malformed data refuses the load and
--    is left untouched.
--  * Save only writes while this session still owns the lock.
--  * Any store error is returned to the caller, never swallowed into "new player".
-- Unit-tested with a failure-injecting fake store in ServerStorage.Tests.ProfileStore.spec.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local EconomyRules = require(ReplicatedStorage.Shared.Economy.EconomyRules)

local ProfileStore = {}

export type Store = { UpdateAsync: (self: any, key: string, transform: (any) -> any) -> any }
export type LoadResult = "New" | "Existing" | "Migrated"
export type LoadError = "StoreError" | "SessionLocked" | "Corrupt"
export type SaveError = "StoreError" | "LockLost"
export type ReadError = "StoreError" | "LockLost" | "Corrupt"

function ProfileStore.load(store: Store, key: string, sessionId: string, now: number, config: any): (Types.Profile?, LoadResult | LoadError, string?)
	local profile: Types.Profile? = nil
	local outcome: string = "StoreError"
	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old: any)
			local record = if type(old) == "table" then old else nil
			if record and not EconomyRules.canClaimLock(record.Lock, sessionId, now, config.SessionLockTimeout) then
				outcome = "SessionLocked"
				return nil -- cancel: leave the record untouched
			end
			local loaded, kind = EconomyRules.validateSaved(record and record.Profile, config)
			if not loaded then
				outcome = "Corrupt"
				return nil -- cancel: never overwrite data we can't read
			end
			profile = loaded
			outcome = kind :: string
			return { Profile = loaded, Lock = { Id = sessionId, At = now } }
		end)
	end)
	if not ok then
		return nil, "StoreError", tostring(err)
	end
	if outcome ~= "New" and outcome ~= "Existing" and outcome ~= "Migrated" then
		return nil, outcome :: any, nil
	end
	return profile, outcome :: any, nil
end

local function copyProfile(profile: Types.Profile): Types.Profile
	return {
		Version = profile.Version,
		Cash = profile.Cash,
		RecentTransactions = table.clone(profile.RecentTransactions),
		OwnedVehicles = table.clone(profile.OwnedVehicles),
		PaidRewards = table.clone(profile.PaidRewards),
	}
end

-- Write-through change (audit remediation): applies `mutate` to a COPY of `profile`, writes
-- that copy in one UpdateAsync while this session owns the lock, and only then copies it into
-- `profile`. If the rule refuses or the write fails, `profile` is left exactly as it was, so a
-- change the caller acknowledges is always already stored. Callers must serialise commits for
-- one profile (EconomyService does, per player).
-- Returns (ok, err, detail): err is the rule's error, "StoreError" or "LockLost".
function ProfileStore.commit(
	store: Store,
	key: string,
	sessionId: string,
	profile: Types.Profile,
	now: number,
	mutate: (Types.Profile) -> (boolean, string?)
): (boolean, string?, string?)
	local draft = copyProfile(profile)
	local ok, err = mutate(draft)
	if not ok then
		return false, err, nil
	end
	local saved, saveErr, detail = ProfileStore.save(store, key, sessionId, draft, now, false)
	if not saved then
		return false, saveErr, detail
	end
	profile.Version = draft.Version
	profile.Cash = draft.Cash
	profile.RecentTransactions = draft.RecentTransactions
	profile.OwnedVehicles = draft.OwnedVehicles
	profile.PaidRewards = draft.PaidRewards
	return true, nil, nil
end

-- Writes the profile if this session still owns the lock. `release` drops the lock (leaving).
function ProfileStore.save(store: Store, key: string, sessionId: string, profile: Types.Profile, now: number, release: boolean): (boolean, SaveError?, string?)
	local owned = false
	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old: any)
			local lock = type(old) == "table" and old.Lock
			if type(lock) == "table" and lock.Id ~= sessionId then
				owned = false
				return nil -- another server took over; don't clobber its data
			end
			owned = true
			return {
				Profile = {
					Version = profile.Version,
					Cash = profile.Cash,
					RecentTransactions = table.clone(profile.RecentTransactions),
					OwnedVehicles = table.clone(profile.OwnedVehicles),
					PaidRewards = table.clone(profile.PaidRewards),
				},
				Lock = if release then nil else { Id = sessionId, At = now },
			}
		end)
	end)
	if not ok then
		return false, "StoreError", tostring(err)
	end
	if not owned then
		return false, "LockLost", nil
	end
	return true, nil, nil
end

-- Reads the stored profile WITHOUT writing (the transform cancels), for reconciling after an
-- ambiguous write. Returns (profile?, err?): "LockLost" if another session owns the record now.
function ProfileStore.read(store: Store, key: string, sessionId: string, config: any): (Types.Profile?, ReadError?, string?)
	local profile: Types.Profile? = nil
	local outcome: ReadError? = nil
	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old: any)
			local record = if type(old) == "table" then old else nil
			local lock = record and record.Lock
			if type(lock) ~= "table" or lock.Id ~= sessionId then
				outcome = "LockLost"
				return nil
			end
			local loaded = EconomyRules.validateSaved(record and record.Profile, config)
			if not loaded then
				outcome = "Corrupt"
				return nil
			end
			profile = loaded
			return nil -- read only
		end)
	end)
	if not ok then
		return nil, "StoreError", tostring(err)
	end
	if outcome then
		return nil, outcome, nil
	end
	return profile, nil, nil
end

return ProfileStore
