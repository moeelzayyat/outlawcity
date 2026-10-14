-- Economy rules (pure): validation, grants, deductions, duplicates, saved-data checks, locks.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local EconomyRules = require(ReplicatedStorage.Shared.Economy.EconomyRules)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)
local Remotes = require(ReplicatedStorage.Shared.Net.Remotes)
local Assert = require(script.Parent.Assert)

local C = EconomyConfig

local function fresh()
	return EconomyRules.newProfile(C)
end

return {
	["new players start with the configured starting cash"] = function()
		local p = fresh()
		Assert.equal(p.Cash, C.StartingCash)
		Assert.equal(#p.RecentTransactions, 0)
		local fromNil, kind = EconomyRules.validateSaved(nil, C)
		Assert.equal(kind, "New")
		Assert.equal(fromNil.Cash, C.StartingCash)
	end,
	["invalid, negative, zero, fractional and nonfinite amounts are rejected"] = function()
		local p = fresh()
		for _, bad in { 0, -1, -500, 1.5, 0 / 0, math.huge, -math.huge, "100", true, {}, C.MaxTransaction + 1 } do
			local ok, err = EconomyRules.grant(p, bad, "tx-" .. tostring(bad), C)
			Assert.equal(ok, false, `grant {tostring(bad)}`)
			Assert.equal(err, "InvalidAmount")
			local ok2, err2 = EconomyRules.deduct(p, bad, "txd-" .. tostring(bad), C)
			Assert.equal(ok2, false, `deduct {tostring(bad)}`)
			Assert.equal(err2, "InvalidAmount")
		end
		Assert.equal((EconomyRules.grant(p, 100, nil, C)), false, "missing tx id")
		Assert.equal(select(2, EconomyRules.grant(p, 100, string.rep("x", 65), C)), "InvalidTransactionId")
		Assert.equal(p.Cash, C.StartingCash, "balance untouched")
	end,
	["grants and deductions change the balance"] = function()
		local p = fresh()
		Assert.equal((EconomyRules.grant(p, 250, "a", C)), true)
		Assert.equal(p.Cash, C.StartingCash + 250)
		Assert.equal((EconomyRules.deduct(p, 100, "b", C)), true)
		Assert.equal(p.Cash, C.StartingCash + 150)
	end,
	["insufficient funds prevents a purchase"] = function()
		local p = fresh()
		local ok, err = EconomyRules.deduct(p, C.StartingCash + 1, "buy-1", C)
		Assert.equal(ok, false)
		Assert.equal(err, "InsufficientFunds")
		Assert.equal(p.Cash, C.StartingCash)
		Assert.equal(EconomyRules.canAfford(p, C.StartingCash), true)
		Assert.equal(EconomyRules.canAfford(p, C.StartingCash + 1), false)
		Assert.equal((EconomyRules.deduct(p, C.StartingCash, "buy-2", C)), true, "exact balance is affordable")
		Assert.equal(p.Cash, 0)
	end,
	["a transaction id can only apply once"] = function()
		local p = fresh()
		Assert.equal((EconomyRules.grant(p, 100, "reward-42", C)), true)
		local ok, err = EconomyRules.grant(p, 100, "reward-42", C)
		Assert.equal(ok, false)
		Assert.equal(err, "DuplicateTransaction")
		Assert.equal(select(2, EconomyRules.deduct(p, 50, "reward-42", C)), "DuplicateTransaction", "ids are shared across grant and deduct")
		Assert.equal(p.Cash, C.StartingCash + 100)
	end,
	["remembered transaction ids are bounded"] = function()
		local p = fresh()
		for i = 1, C.RecentTransactionLimit + 25 do
			EconomyRules.grant(p, 1, `t{i}`, C)
		end
		Assert.equal(#p.RecentTransactions, C.RecentTransactionLimit)
		Assert.equal(EconomyRules.hasTransaction(p, `t{C.RecentTransactionLimit + 25}`), true)
	end,
	["the balance cap is enforced"] = function()
		local p = fresh()
		p.Cash = C.MaxBalance - 10
		Assert.equal(select(2, EconomyRules.grant(p, 11, "cap", C)), "BalanceCap")
		Assert.equal(p.Cash, C.MaxBalance - 10)
	end,
	["valid saved data is kept exactly; malformed data is refused, never reset"] = function()
		local saved = { Version = 3, Cash = 12345, RecentTransactions = { "x", "y", 5 }, OwnedVehicles = { "Coupe" }, PaidRewards = {} }
		local p, kind = EconomyRules.validateSaved(saved, C)
		Assert.equal(kind, "Existing")
		Assert.equal(p.Cash, 12345, "not reset to starting cash")
		Assert.equal(#p.RecentTransactions, 2, "junk ids dropped")
		for _, corrupt in { "text", { Cash = "lots" }, { Cash = -5 }, { Cash = 0 / 0 }, { Cash = 1.5 }, { Cash = C.MaxBalance + 1 } } do
			local profile, why = EconomyRules.validateSaved(corrupt, C)
			Assert.equal(profile, nil)
			Assert.equal(why, "Corrupt")
		end
	end,
	["new profiles own exactly the starter Coupe"] = function()
		local p = fresh()
		Assert.equal(p.Version, C.ProfileVersion)
		Assert.equal(#p.OwnedVehicles, 1)
		Assert.equal(p.OwnedVehicles[1], "Coupe")
	end,
	["cash-only (v1) profiles migrate without losing cash or transaction history"] = function()
		for _, legacy in { { Version = 1, Cash = 9800, RecentTransactions = { "robbery:a" } }, { Cash = 9800, RecentTransactions = { "robbery:a" } } } do
			local p, kind = EconomyRules.validateSaved(legacy, C)
			Assert.equal(kind, "Migrated")
			Assert.equal(p.Version, C.ProfileVersion)
			Assert.equal(p.Cash, 9800)
			Assert.equal(p.RecentTransactions[1], "robbery:a")
			Assert.equal(#p.OwnedVehicles, 1)
			Assert.equal(p.OwnedVehicles[1], "Coupe")
		end
		-- a v1 record that somehow carries a vehicle list does not gain cars from it
		local p = EconomyRules.validateSaved({ Version = 1, Cash = 5, OwnedVehicles = { "Muscle" } }, C)
		Assert.equal(EconomyRules.ownsVehicle(p, "Muscle"), false)
	end,
	["saved ownership is kept; junk is dropped; damaged or newer records are refused untouched"] = function()
		local p, kind = EconomyRules.validateSaved({ Version = 3, Cash = 1, RecentTransactions = {}, OwnedVehicles = { "Muscle", 7, "Muscle", "" }, PaidRewards = {} }, C)
		Assert.equal(kind, "Existing")
		Assert.equal(EconomyRules.ownsVehicle(p, "Muscle"), true)
		Assert.equal(EconomyRules.ownsVehicle(p, "Coupe"), true, "starter is always owned")
		Assert.equal(#p.OwnedVehicles, 2, "duplicates and junk removed")
		for _, bad in {
			{ Version = 2, Cash = 1, RecentTransactions = {} }, -- v2 without its list
			{ Version = 3, Cash = 1, RecentTransactions = {}, OwnedVehicles = {} }, -- v3 without its paid-reward list
			{ Version = 4, Cash = 1, RecentTransactions = {}, OwnedVehicles = {}, PaidRewards = {} }, -- newer schema
			{ Version = 0, Cash = 1 },
			{ Version = 1.5, Cash = 1 },
		} do
			local profile, why = EconomyRules.validateSaved(bad, C)
			Assert.equal(profile, nil)
			Assert.equal(why, "Corrupt")
		end
	end,
	["buying a car takes the price once and records ownership in the same step"] = function()
		local p = fresh()
		p.Cash = 20000
		Assert.equal((EconomyRules.purchaseVehicle(p, "Muscle", 15000, "buy:1", C)), true)
		Assert.equal(p.Cash, 5000)
		Assert.equal(EconomyRules.ownsVehicle(p, "Muscle"), true)
		-- the same request again, or a new request for the same car, never charges twice
		local ok, err = EconomyRules.purchaseVehicle(p, "Muscle", 15000, "buy:1", C)
		Assert.equal(ok, false)
		Assert.equal(err, "DuplicateTransaction")
		ok, err = EconomyRules.purchaseVehicle(p, "Muscle", 15000, "buy:2", C)
		Assert.equal(err, "AlreadyOwned")
		Assert.equal(p.Cash, 5000)
		Assert.equal(#p.OwnedVehicles, 2)
	end,
	["a failed purchase changes nothing"] = function()
		local p = fresh()
		p.Cash = 14999
		local ok, err = EconomyRules.purchaseVehicle(p, "Muscle", 15000, "buy:x", C)
		Assert.equal(ok, false)
		Assert.equal(err, "InsufficientFunds")
		Assert.equal(p.Cash, 14999)
		Assert.equal(EconomyRules.ownsVehicle(p, "Muscle"), false)
		Assert.equal(#p.RecentTransactions, 0, "a refused purchase doesn't burn its transaction id")
		for _, case in { { "", 100, "InvalidVehicle" }, { 5, 100, "InvalidVehicle" }, { "Muscle", -1, "InvalidAmount" }, { "Muscle", 0 / 0, "InvalidAmount" }, { "Muscle", "15000", "InvalidAmount" } } do
			local ok2, err2 = EconomyRules.purchaseVehicle(p, case[1], case[2], "buy:y", C)
			Assert.equal(ok2, false)
			Assert.equal(err2, case[3])
		end
		Assert.equal(p.Cash, 14999)
	end,
	["v2 profiles migrate to v3 keeping cash, cars and history, with no paid rewards yet"] = function()
		local p, kind = EconomyRules.validateSaved({ Version = 2, Cash = 800, RecentTransactions = { "buy:1" }, OwnedVehicles = { "Coupe", "Muscle" } }, C)
		Assert.equal(kind, "Migrated")
		Assert.equal(p.Version, 3)
		Assert.equal(p.Cash, 800)
		Assert.equal(EconomyRules.ownsVehicle(p, "Muscle"), true)
		Assert.equal(p.RecentTransactions[1], "buy:1")
		Assert.equal(#p.PaidRewards, 0)
	end,
	["a ledger reward pays once and stays blocked from paying again after 200+ later transactions"] = function()
		local p = fresh()
		Assert.equal((EconomyRules.payReward(p, 2000, "robbery:old", C)), true)
		for i = 1, C.RecentTransactionLimit + 50 do
			assert(EconomyRules.grant(p, 1, "g" .. i, C))
		end
		Assert.equal(EconomyRules.hasTransaction(p, "robbery:old"), false, "aged out of the recent ids")
		local cash = p.Cash
		local ok, err = EconomyRules.payReward(p, 2000, "robbery:old", C)
		Assert.equal(ok, false)
		Assert.equal(err, "DuplicateTransaction")
		Assert.equal(p.Cash, cash)
	end,
	["paid-reward ids are pruned only once the ledger no longer lists them"] = function()
		local p = fresh()
		assert(EconomyRules.payReward(p, 10, "r1", C))
		assert(EconomyRules.payReward(p, 10, "r2", C))
		Assert.equal(EconomyRules.prunePaidRewards(p, { "r1" }), 1)
		Assert.equal(table.find(p.PaidRewards, "r1") ~= nil, true, "still in the ledger: kept")
		Assert.equal(table.find(p.PaidRewards, "r2"), nil)
	end,
	["a full paid-reward history refuses explicitly instead of forgetting"] = function()
		local p = fresh()
		for i = 1, C.MaxPaidRewards do
			p.PaidRewards[i] = "x" .. i
		end
		local ok, err = EconomyRules.payReward(p, 10, "r-new", C)
		Assert.equal(ok, false)
		Assert.equal(err, "RewardHistoryFull")
	end,
	["session locks: own or stale locks can be claimed, live foreign locks cannot"] = function()
		local T = C.SessionLockTimeout
		Assert.equal(EconomyRules.canClaimLock(nil, "me", 1000, T), true)
		Assert.equal(EconomyRules.canClaimLock({ Id = "me", At = 999 }, "me", 1000, T), true)
		Assert.equal(EconomyRules.canClaimLock({ Id = "other", At = 990 }, "me", 1000, T), false)
		Assert.equal(EconomyRules.canClaimLock({ Id = "other", At = 1000 - T - 1 }, "me", 1000, T), true)
	end,
	["no client remote can change cash"] = function()
		for name in Remotes.Definitions do
			for _, word in { "Cash", "Money", "Grant", "Balance", "Economy" } do
				Assert.truthy(not name:find(word), `remote {name} must not expose {word}`)
			end
		end
	end,
}
