--!strict
-- Pure economy rules: amount and transaction-id validation, grants, deductions, duplicate
-- protection, profile creation/validation and session-lock claims. No Instances, no clocks.
-- Unit-tested in ServerStorage.Tests.EconomyRules.spec.
local Types = require(script.Parent.Parent.Types)

local EconomyRules = {}

type Config = {
	StartingCash: number,
	MaxBalance: number,
	MaxTransaction: number,
	RecentTransactionLimit: number,
	TransactionIdMaxLength: number,
	ProfileVersion: number,
	StarterVehicles: { string },
	MaxOwnedVehicles: number,
	VehicleIdMaxLength: number,
	MaxPaidRewards: number,
}

local function isWholeFinite(n: any): boolean
	return type(n) == "number" and n == n and n ~= math.huge and n ~= -math.huge and n % 1 == 0
end

-- Amounts must be whole, finite, positive and no bigger than MaxTransaction.
function EconomyRules.validateAmount(amount: any, config: Config): (boolean, Types.EconomyError?)
	if not isWholeFinite(amount) or amount <= 0 or amount > config.MaxTransaction then
		return false, "InvalidAmount"
	end
	return true, nil
end

function EconomyRules.validateTransactionId(txId: any, config: Config): (boolean, Types.EconomyError?)
	if type(txId) ~= "string" or #txId == 0 or #txId > config.TransactionIdMaxLength then
		return false, "InvalidTransactionId"
	end
	return true, nil
end

function EconomyRules.newProfile(config: Config): Types.Profile
	return {
		Version = config.ProfileVersion,
		Cash = config.StartingCash,
		RecentTransactions = {},
		OwnedVehicles = table.clone(config.StarterVehicles),
		PaidRewards = {},
	}
end

-- Checks saved data. nil (never saved) -> a new profile with starting cash. Valid data is
-- returned as-is (never reset to defaults). Anything malformed is reported as corrupt so the
-- caller refuses to load and never overwrites it.
function EconomyRules.validateSaved(saved: any, config: Config): (Types.Profile?, string?)
	if saved == nil then
		return EconomyRules.newProfile(config), "New"
	end
	if type(saved) ~= "table" or not isWholeFinite(saved.Cash) or saved.Cash < 0 or saved.Cash > config.MaxBalance then
		return nil, "Corrupt"
	end
	-- Version 1 records (cash only) predate the field being required.
	local version = if saved.Version == nil then 1 else saved.Version
	if not isWholeFinite(version) or version < 1 or version > config.ProfileVersion then
		return nil, "Corrupt" -- unknown or newer schema: never guess, never downgrade
	end
	local recent = {}
	if type(saved.RecentTransactions) == "table" then
		for _, txId in saved.RecentTransactions do
			if type(txId) == "string" then
				table.insert(recent, txId)
			end
		end
	end
	-- Ownership: starters always; from v2 on, the saved list (it must be a list).
	local owned = table.clone(config.StarterVehicles)
	if version >= 2 then
		if type(saved.OwnedVehicles) ~= "table" then
			return nil, "Corrupt" -- a v2 record without its ownership list is damaged, not empty
		end
		for _, vehicleId in saved.OwnedVehicles do
			if
				type(vehicleId) == "string"
				and #vehicleId > 0
				and #vehicleId <= config.VehicleIdMaxLength
				and not table.find(owned, vehicleId)
				and #owned < config.MaxOwnedVehicles
			then
				table.insert(owned, vehicleId)
			end
		end
	end
	-- Paid-reward ids (v3+, audit remediation): rewards paid from the ledger that the ledger may
	-- still list. Kept until the ledger no longer has them, so a reward can never be paid twice
	-- even after its id has left RecentTransactions.
	local paid = {}
	if version >= 3 then
		if type(saved.PaidRewards) ~= "table" then
			return nil, "Corrupt" -- a v3 record without its paid-reward list is damaged, not empty
		end
		for _, txId in saved.PaidRewards do
			if type(txId) == "string" and not table.find(paid, txId) then
				table.insert(paid, txId)
			end
		end
	end
	return {
		Version = config.ProfileVersion,
		Cash = saved.Cash,
		RecentTransactions = recent,
		OwnedVehicles = owned,
		PaidRewards = paid,
	}, if version < config.ProfileVersion then "Migrated" else "Existing"
end

function EconomyRules.hasTransaction(profile: Types.Profile, txId: string): boolean
	return table.find(profile.RecentTransactions, txId) ~= nil
end

local function remember(profile: Types.Profile, txId: string, config: Config)
	table.insert(profile.RecentTransactions, txId)
	while #profile.RecentTransactions > config.RecentTransactionLimit do
		table.remove(profile.RecentTransactions, 1)
	end
end

local function precheck(profile: Types.Profile, amount: any, txId: any, config: Config): (boolean, Types.EconomyError?)
	local ok, err = EconomyRules.validateAmount(amount, config)
	if not ok then
		return false, err
	end
	ok, err = EconomyRules.validateTransactionId(txId, config)
	if not ok then
		return false, err
	end
	if EconomyRules.hasTransaction(profile, txId) then
		return false, "DuplicateTransaction"
	end
	return true, nil
end

function EconomyRules.canAfford(profile: Types.Profile, amount: number): boolean
	return isWholeFinite(amount) and amount >= 0 and profile.Cash >= amount
end

-- Adds cash once per transaction id. Never exceeds MaxBalance.
function EconomyRules.grant(profile: Types.Profile, amount: any, txId: any, config: Config): (boolean, Types.EconomyError?)
	local ok, err = precheck(profile, amount, txId, config)
	if not ok then
		return false, err
	end
	if profile.Cash + amount > config.MaxBalance then
		return false, "BalanceCap"
	end
	profile.Cash += amount
	remember(profile, txId, config)
	return true, nil
end

-- Removes cash once per transaction id; refuses if the balance is too small (purchases).
function EconomyRules.deduct(profile: Types.Profile, amount: any, txId: any, config: Config): (boolean, Types.EconomyError?)
	local ok, err = precheck(profile, amount, txId, config)
	if not ok then
		return false, err
	end
	if not EconomyRules.canAfford(profile, amount) then
		return false, "InsufficientFunds"
	end
	profile.Cash -= amount
	remember(profile, txId, config)
	return true, nil
end

function EconomyRules.ownsVehicle(profile: Types.Profile, vehicleId: string): boolean
	return table.find(profile.OwnedVehicles, vehicleId) ~= nil
end

-- Buys a vehicle: takes the price AND records ownership in one step on the same profile, so
-- they are always saved together (never cash without the car, never the car without cash).
-- The price comes from server config, never from the client.
function EconomyRules.purchaseVehicle(profile: Types.Profile, vehicleId: any, price: any, txId: any, config: Config): (boolean, Types.EconomyError?)
	if type(vehicleId) ~= "string" or #vehicleId == 0 or #vehicleId > config.VehicleIdMaxLength then
		return false, "InvalidVehicle"
	end
	local ok, err = precheck(profile, price, txId, config)
	if not ok then
		return false, err
	end
	if EconomyRules.ownsVehicle(profile, vehicleId) then
		return false, "AlreadyOwned"
	end
	if #profile.OwnedVehicles >= config.MaxOwnedVehicles then
		return false, "TooManyVehicles"
	end
	if not EconomyRules.canAfford(profile, price) then
		return false, "InsufficientFunds"
	end
	profile.Cash -= price
	table.insert(profile.OwnedVehicles, vehicleId)
	remember(profile, txId, config)
	return true, nil
end

-- Pays a ledger reward once (audit remediation). Refuses a reward already in PaidRewards or in
-- the recent transaction ids ("DuplicateTransaction"), so it can't pay twice even after the id
-- has aged out of RecentTransactions. Records the id in PaidRewards in the same step.
function EconomyRules.payReward(profile: Types.Profile, amount: any, txId: any, config: Config): (boolean, Types.EconomyError?)
	if type(txId) == "string" and table.find(profile.PaidRewards, txId) then
		return false, "DuplicateTransaction"
	end
	if #profile.PaidRewards >= config.MaxPaidRewards then
		return false, "RewardHistoryFull"
	end
	local ok, err = EconomyRules.grant(profile, amount, txId, config)
	if not ok then
		return false, err
	end
	table.insert(profile.PaidRewards, txId)
	return true, nil
end

-- Drops paid-reward ids the ledger no longer lists (they can never be claimed again).
-- Returns how many were dropped.
function EconomyRules.prunePaidRewards(profile: Types.Profile, stillInLedger: { string }): number
	local kept = {}
	for _, txId in profile.PaidRewards do
		if table.find(stillInLedger, txId) then
			table.insert(kept, txId)
		end
	end
	local dropped = #profile.PaidRewards - #kept
	profile.PaidRewards = kept
	return dropped
end

-- Session lock: a server may claim a record when it is unlocked, already its own, or the
-- other server's lock is older than `timeout` seconds (that server crashed or hung).
function EconomyRules.canClaimLock(lock: any, sessionId: string, now: number, timeout: number): boolean
	if type(lock) ~= "table" or type(lock.Id) ~= "string" then
		return true
	end
	if lock.Id == sessionId then
		return true
	end
	return type(lock.At) ~= "number" or now - lock.At > timeout
end

return EconomyRules
