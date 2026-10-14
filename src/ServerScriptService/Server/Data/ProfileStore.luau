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

return ProfileStore
