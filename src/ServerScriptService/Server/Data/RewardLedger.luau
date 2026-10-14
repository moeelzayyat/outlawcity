--!strict
-- Durable record of earned-but-unpaid rewards. Kept in its OWN DataStore
-- (EconomyConfig.RewardStoreName), separate from the player profile, so a reward survives a
-- failed profile save, a disconnect or a server crash. Each entry carries the reward's stable
-- transaction id. Paying it (on any server, on load or in the periodic claim) records the id in
-- the profile's PaidRewards in the same write, so it can never pay twice, however many other
-- transactions happen in between.
-- Record: { Rewards = { { TxId, Amount, Reason, At, State = "Pending" | "Blocked", Note? } } }
-- Invalid states are handled explicitly (audit remediation):
--  * a record that isn't a table of this shape is "LedgerCorrupt": never overwritten, never
--    guessed at, reported;
--  * an entry that isn't a valid reward is kept untouched in the record (never dropped) and
--    counted as malformed;
--  * a full ledger refuses new rewards with "LedgerFull" (the caller still tries to pay directly);
--  * an entry the profile rules refuse for a lasting reason (e.g. BalanceCap) is marked
--    "Blocked" with the reason, kept, and retried at the normal claim pace.
-- Unit-tested with a fake store in ServerStorage.Tests.RewardLedger.spec.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Types = require(ReplicatedStorage.Shared.Types)
local EconomyRules = require(ReplicatedStorage.Shared.Economy.EconomyRules)
local EconomyConfig = require(ReplicatedStorage.Shared.Config.EconomyConfig)

local RewardLedger = {}

export type Reward = { TxId: string, Amount: number, Reason: string, At: number, State: string?, Note: string? }
export type Store = { UpdateAsync: (self: any, key: string, transform: (any) -> any) -> any }
export type ClaimResult = { Settled: { string }, Blocked: { [string]: string }, Retry: { string } }

local DEFAULT_MAX = 50

local function isReward(r: any): boolean
	return type(r) == "table" and type(r.TxId) == "string" and #r.TxId > 0 and type(r.Amount) == "number" and r.Amount == r.Amount
end

-- Splits a record into valid rewards and untouched malformed entries. Returns nil if the record
-- itself is unusable (corrupt).
local function parse(record: any): ({ Reward }?, { any }?)
	if record == nil then
		return {}, {}
	end
	if type(record) ~= "table" or (record.Rewards ~= nil and type(record.Rewards) ~= "table") then
		return nil, nil
	end
	local valid, malformed = {}, {}
	for _, r in record.Rewards or {} do
		if isReward(r) then
			table.insert(valid, {
				TxId = r.TxId,
				Amount = r.Amount,
				Reason = tostring(r.Reason or ""),
				At = tonumber(r.At) or 0,
				State = if r.State == "Blocked" then "Blocked" else "Pending",
				Note = if type(r.Note) == "string" then r.Note else nil,
			})
		else
			table.insert(malformed, r)
		end
	end
	return valid, malformed
end

local function build(valid: { Reward }, malformed: { any }): any
	local list = {}
	for _, r in valid do
		table.insert(list, r)
	end
	for _, r in malformed do
		table.insert(list, r) -- kept exactly as found
	end
	return { Rewards = list }
end

local MAX_REASON = 100

-- Checks a reward before it may enter the ledger (audit condition 4): a valid transaction id
-- and amount by the same rules the profile uses, a short reason and a numeric time. Returns
-- (ok, problem?).
function RewardLedger.validate(reward: any): (boolean, string?)
	if type(reward) ~= "table" then
		return false, "not a table"
	end
	local okTx, txErr = EconomyRules.validateTransactionId(reward.TxId, EconomyConfig)
	if not okTx then
		return false, txErr
	end
	local okAmount, amountErr = EconomyRules.validateAmount(reward.Amount, EconomyConfig)
	if not okAmount then
		return false, amountErr
	end
	if type(reward.Reason) ~= "string" or #reward.Reason > MAX_REASON then
		return false, "InvalidReason"
	end
	if type(reward.At) ~= "number" or reward.At ~= reward.At or reward.At == math.huge or reward.At == -math.huge then
		return false, "InvalidTime"
	end
	return true, nil
end

-- Adds a reward (no-op if its TxId is already recorded). Returns (ok, err?):
-- err is "InvalidReward: <why>" (nothing written), "LedgerFull", "LedgerCorrupt" or a store error.
function RewardLedger.record(store: Store, key: string, reward: Reward, maxEntries: number?): (boolean, string?)
	local valid, why = RewardLedger.validate(reward)
	if not valid then
		return false, `InvalidReward: {why}`
	end
	local limit = maxEntries or DEFAULT_MAX
	local refusal: string? = nil
	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old: any)
			local valid, malformed = parse(old)
			if not valid then
				refusal = "LedgerCorrupt"
				return nil
			end
			for _, r in valid do
				if r.TxId == reward.TxId then
					return nil -- already recorded
				end
			end
			if #valid + #(malformed :: { any }) >= limit then
				refusal = "LedgerFull"
				return nil
			end
			table.insert(valid, { TxId = reward.TxId, Amount = reward.Amount, Reason = reward.Reason, At = reward.At, State = "Pending" })
			return build(valid, malformed :: { any })
		end)
	end)
	if not ok then
		return false, tostring(err)
	end
	if refusal then
		return false, refusal
	end
	return true, nil
end

-- Reads the outstanding rewards without changing them. Returns (rewards?, err?, malformedCount).
function RewardLedger.list(store: Store, key: string): ({ Reward }?, string?, number)
	local result: { Reward }? = nil
	local malformedCount = 0
	local corrupt = false
	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old: any)
			local valid, malformed = parse(old)
			if not valid then
				corrupt = true
				return nil
			end
			result = valid
			malformedCount = #(malformed :: { any })
			return nil -- read only
		end)
	end)
	if not ok then
		return nil, tostring(err), 0
	end
	if corrupt then
		return nil, "LedgerCorrupt", 0
	end
	return result or {}, nil, malformedCount
end

-- Applies a claim's outcome: removes settled rewards, marks blocked ones (with their reason)
-- and puts the rest back to Pending. Malformed entries are kept. Returns (ok, err?).
function RewardLedger.update(store: Store, key: string, result: ClaimResult): (boolean, string?)
	local corrupt = false
	local ok, err = pcall(function()
		store:UpdateAsync(key, function(old: any)
			local valid, malformed = parse(old)
			if not valid then
				corrupt = true
				return nil
			end
			local kept = {}
			local changed = false
			for _, r in valid do
				if table.find(result.Settled, r.TxId) then
					changed = true
				else
					local blockedNote = result.Blocked[r.TxId]
					if blockedNote and (r.State ~= "Blocked" or r.Note ~= blockedNote) then
						r.State = "Blocked"
						r.Note = blockedNote
						changed = true
					elseif not blockedNote and r.State == "Blocked" and table.find(result.Retry, r.TxId) then
						r.State = "Pending"
						r.Note = nil
						changed = true
					end
					table.insert(kept, r)
				end
			end
			if not changed then
				return nil
			end
			return build(kept, malformed :: { any })
		end)
	end)
	if not ok then
		return false, tostring(err)
	end
	if corrupt then
		return false, "LedgerCorrupt"
	end
	return true, nil
end

-- Removes rewards by TxId (settled immediately after payment). Returns (ok, err?).
function RewardLedger.remove(store: Store, key: string, txIds: { string }): (boolean, string?)
	return RewardLedger.update(store, key, { Settled = txIds, Blocked = {}, Retry = {} })
end

-- Lasting refusals: the reward stays in the ledger as Blocked instead of being retried as if
-- the store were down. Everything else that isn't paid is retried later.
local LASTING = { BalanceCap = true, InvalidAmount = true, InvalidTransactionId = true, RewardHistoryFull = true }

-- Pays every outstanding reward into `draft` (a profile copy inside a commit). Returns which
-- were settled (paid now or already paid), which are blocked (with the reason) and which must
-- simply be retried.
function RewardLedger.applyAll(draft: Types.Profile, rewards: { Reward }, config: any): ClaimResult
	local result: ClaimResult = { Settled = {}, Blocked = {}, Retry = {} }
	for _, r in rewards do
		local ok, err = EconomyRules.payReward(draft, r.Amount, r.TxId, config)
		if ok or err == "DuplicateTransaction" then
			table.insert(result.Settled, r.TxId)
		elseif err and LASTING[err] then
			result.Blocked[r.TxId] = err
		else
			table.insert(result.Retry, r.TxId)
		end
	end
	return result
end

return RewardLedger
