-- ProfileStore against an in-memory fake with DataStore UpdateAsync semantics and failure
-- injection. Proves that failures never wipe progress and that locks protect sessions.
local ServerScriptService = game:GetService("ServerScriptService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ProfileStore = require(ServerScriptService.Server.Data.ProfileStore)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local EconomyRules = require(ReplicatedStorage.Shared.Economy.EconomyRules)
local Assert = require(script.Parent.Assert)

local C = EconomyConfig

local HttpService = game:GetService("HttpService")

-- Like a real DataStore, values are serialized: nothing the caller holds aliases stored data.
local function deepCopy(value)
	if value == nil then
		return nil
	end
	return HttpService:JSONDecode(HttpService:JSONEncode(value))
end

local function fakeStore()
	local data = {}
	local store = { Fail = false, Writes = 0, Data = data }
	function store.UpdateAsync(self, key, transform)
		if self.Fail then
			error("simulated outage")
		end
		local result = transform(deepCopy(data[key]))
		if result ~= nil then
			data[key] = deepCopy(result)
			self.Writes += 1
		end
		return deepCopy(result)
	end
	return store
end

return {
	["a new player is created with starting cash and locked to this session"] = function()
		local store = fakeStore()
		local profile, result = ProfileStore.load(store, "k", "server-A", 1000, C)
		Assert.equal(result, "New")
		Assert.equal(profile.Cash, C.StartingCash)
		Assert.equal(store.Data.k.Lock.Id, "server-A")
	end,
	["save then load round-trips (rejoin)"] = function()
		local store = fakeStore()
		local profile = ProfileStore.load(store, "k", "A", 1000, C)
		profile.Cash = 777
		Assert.equal((ProfileStore.save(store, "k", "A", profile, 1010, true)), true)
		Assert.equal(store.Data.k.Lock, nil, "lock released on leave")
		local again, result = ProfileStore.load(store, "k", "B", 1020, C)
		Assert.equal(result, "Existing")
		Assert.equal(again.Cash, 777)
	end,
	["a cash-only record migrates on load, is written back as v2, and keeps the balance"] = function()
		local store = fakeStore()
		store.Data.k = { Profile = { Version = 1, Cash = 9800, RecentTransactions = { "robbery:a" } } }
		local profile, result = ProfileStore.load(store, "k", "A", 1000, C)
		Assert.equal(result, "Migrated")
		Assert.equal(profile.Cash, 9800)
		Assert.equal(store.Data.k.Profile.Version, C.ProfileVersion, "migration persisted with the lock claim")
		Assert.equal(store.Data.k.Profile.Cash, 9800)
		Assert.equal(store.Data.k.Profile.OwnedVehicles[1], "Coupe")
		local again, result2 = ProfileStore.load(store, "k", "A", 1001, C)
		Assert.equal(result2, "Existing")
		Assert.equal(again.Cash, 9800)
	end,
	["a purchase saves cash and ownership together; a failed save changes neither"] = function()
		local store = fakeStore()
		local profile = ProfileStore.load(store, "k", "A", 1000, C)
		profile.Cash = 15000
		Assert.equal((ProfileStore.save(store, "k", "A", profile, 1001, false)), true)
		profile.Cash -= 15000
		table.insert(profile.OwnedVehicles, "Muscle")
		store.Fail = true
		Assert.equal((ProfileStore.save(store, "k", "A", profile, 1002, false)), false)
		Assert.equal(store.Data.k.Profile.Cash, 15000, "stored record untouched by the failed save")
		Assert.equal(#store.Data.k.Profile.OwnedVehicles, 1)
		store.Fail = false
		Assert.equal((ProfileStore.save(store, "k", "A", profile, 1003, true)), true)
		local again = ProfileStore.load(store, "k", "B", 1004, C)
		Assert.equal(again.Cash, 0)
		Assert.equal(table.find(again.OwnedVehicles, "Muscle") ~= nil, true, "owned after rejoin")
	end,
	["write-through: a committed purchase is stored before it takes effect"] = function()
		local store = fakeStore()
		local profile = ProfileStore.load(store, "k", "A", 1000, C)
		profile.Cash = 20000
		ProfileStore.save(store, "k", "A", profile, 1000, false)
		local ok = ProfileStore.commit(store, "k", "A", profile, 1001, function(draft)
			return EconomyRules.purchaseVehicle(draft, "Muscle", 15000, "buy:1", C)
		end)
		Assert.equal(ok, true)
		Assert.equal(profile.Cash, 5000)
		Assert.equal(store.Data.k.Profile.Cash, 5000, "stored at the moment it is acknowledged")
		Assert.equal(table.find(store.Data.k.Profile.OwnedVehicles, "Muscle") ~= nil, true)
	end,
	["write-through: a failed write changes nothing, in memory or stored, and burns no tx id"] = function()
		local store = fakeStore()
		local profile = ProfileStore.load(store, "k", "A", 1000, C)
		profile.Cash = 20000
		ProfileStore.save(store, "k", "A", profile, 1000, false)
		store.Fail = true
		local ok, err = ProfileStore.commit(store, "k", "A", profile, 1001, function(draft)
			return EconomyRules.purchaseVehicle(draft, "Muscle", 15000, "buy:1", C)
		end)
		Assert.equal(ok, false)
		Assert.equal(err, "StoreError")
		Assert.equal(profile.Cash, 20000)
		Assert.equal(EconomyRules.ownsVehicle(profile, "Muscle"), false)
		Assert.equal(EconomyRules.hasTransaction(profile, "buy:1"), false, "the same request can be retried")
		store.Fail = false
		Assert.equal(store.Data.k.Profile.Cash, 20000)
		Assert.equal((ProfileStore.commit(store, "k", "A", profile, 1002, function(draft)
			return EconomyRules.purchaseVehicle(draft, "Muscle", 15000, "buy:1", C)
		end)), true, "retry after the outage succeeds once")
		Assert.equal(profile.Cash, 5000)
	end,
	["a rule refusal writes nothing"] = function()
		local store = fakeStore()
		local profile = ProfileStore.load(store, "k", "A", 1000, C)
		local writes = store.Writes
		local ok, err = ProfileStore.commit(store, "k", "A", profile, 1001, function(draft)
			return EconomyRules.purchaseVehicle(draft, "Muscle", 15000, "buy:1", C)
		end)
		Assert.equal(ok, false)
		Assert.equal(err, "InsufficientFunds")
		Assert.equal(store.Writes, writes)
	end,
	["lock expiry: an acknowledged purchase survives another server taking over"] = function()
		local store = fakeStore()
		local a = ProfileStore.load(store, "k", "A", 1000, C)
		a.Cash = 15000
		ProfileStore.save(store, "k", "A", a, 1000, false)
		assert(ProfileStore.commit(store, "k", "A", a, 1001, function(draft)
			return EconomyRules.purchaseVehicle(draft, "Muscle", 15000, "buy:1", C)
		end))
		-- Server A's leave-save then keeps failing and its lock goes stale; server B takes over.
		local b, result = ProfileStore.load(store, "k", "B", 1001 + C.SessionLockTimeout + 1, C)
		Assert.equal(result, "Existing")
		Assert.equal(b.Cash, 0)
		Assert.equal(EconomyRules.ownsVehicle(b, "Muscle"), true, "the purchase A acknowledged is there")
		-- A comes back late: it can no longer write over B.
		local ok, err = ProfileStore.save(store, "k", "A", a, 1300, true)
		Assert.equal(ok, false)
		Assert.equal(err, "LockLost")
		local ok2, err2 = ProfileStore.commit(store, "k", "A", a, 1301, function(draft)
			return EconomyRules.grant(draft, 999, "late", C)
		end)
		Assert.equal(ok2, false)
		Assert.equal(err2, "LockLost")
		Assert.equal(store.Data.k.Profile.Cash, 0)
	end,
	["sequential commits never lose an update"] = function()
		local store = fakeStore()
		local profile = ProfileStore.load(store, "k", "A", 1000, C)
		for i = 1, 5 do
			assert(ProfileStore.commit(store, "k", "A", profile, 1000 + i, function(draft)
				return EconomyRules.grant(draft, 100, "g" .. i, C)
			end))
		end
		Assert.equal(store.Data.k.Profile.Cash, C.StartingCash + 500)
		Assert.equal(#store.Data.k.Profile.RecentTransactions, 5)
	end,
	["a store outage during load never creates or overwrites data"] = function()
		local store = fakeStore()
		store.Data.k = { Profile = { Version = 1, Cash = 9000, RecentTransactions = {} } }
		store.Fail = true
		local profile, result = ProfileStore.load(store, "k", "A", 1000, C)
		Assert.equal(profile, nil)
		Assert.equal(result, "StoreError")
		Assert.equal(store.Data.k.Profile.Cash, 9000, "progress intact")
		store.Fail = false
		local recovered = ProfileStore.load(store, "k", "A", 1030, C)
		Assert.equal(recovered.Cash, 9000, "recovers the real balance, not defaults")
	end,
	["corrupt saved data refuses the load and stays untouched"] = function()
		local store = fakeStore()
		store.Data.k = { Profile = { Cash = "broken" } }
		local profile, result = ProfileStore.load(store, "k", "A", 1000, C)
		Assert.equal(profile, nil)
		Assert.equal(result, "Corrupt")
		Assert.equal(store.Data.k.Profile.Cash, "broken")
		Assert.equal(store.Writes, 0)
	end,
	["another live server's lock blocks the load; a stale lock does not"] = function()
		local store = fakeStore()
		store.Data.k = { Profile = { Version = 1, Cash = 50, RecentTransactions = {} }, Lock = { Id = "B", At = 1000 } }
		local profile, result = ProfileStore.load(store, "k", "A", 1010, C)
		Assert.equal(profile, nil)
		Assert.equal(result, "SessionLocked")
		local later = ProfileStore.load(store, "k", "A", 1000 + C.SessionLockTimeout + 1, C)
		Assert.equal(later.Cash, 50)
	end,
	["a server that lost its lock cannot overwrite the new owner's data"] = function()
		local store = fakeStore()
		local profile = ProfileStore.load(store, "k", "A", 1000, C)
		store.Data.k.Lock = { Id = "B", At = 2000 }
		store.Data.k.Profile.Cash = 4242
		profile.Cash = 1
		local ok, err = ProfileStore.save(store, "k", "A", profile, 2001, false)
		Assert.equal(ok, false)
		Assert.equal(err, "LockLost")
		Assert.equal(store.Data.k.Profile.Cash, 4242)
	end,
	["a failed save reports an error instead of pretending"] = function()
		local store = fakeStore()
		local profile = ProfileStore.load(store, "k", "A", 1000, C)
		store.Fail = true
		local ok, err = ProfileStore.save(store, "k", "A", profile, 1001, false)
		Assert.equal(ok, false)
		Assert.equal(err, "StoreError")
	end,
}
