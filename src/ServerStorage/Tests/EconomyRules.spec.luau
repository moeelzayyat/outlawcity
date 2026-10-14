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
		local saved = { Version = 1, Cash = 12345, RecentTransactions = { "x", "y", 5 } }
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
