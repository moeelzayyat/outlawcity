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
	return { Version = config.ProfileVersion, Cash = config.StartingCash, RecentTransactions = {} }
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
	local recent = {}
	if type(saved.RecentTransactions) == "table" then
		for _, txId in saved.RecentTransactions do
			if type(txId) == "string" then
				table.insert(recent, txId)
			end
		end
	end
	return {
		Version = if type(saved.Version) == "number" then saved.Version else config.ProfileVersion,
		Cash = saved.Cash,
		RecentTransactions = recent,
	}, "Existing"
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
