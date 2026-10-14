--!strict
-- Pure validation for Studio-only dev commands. Unit-tested in DevCommandRules.spec.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local WantedConfig = require(ReplicatedStorage.Shared.Config.WantedConfig)

local DevCommandRules = {}

export type Command =
	{ Name: "SetHeat", Value: number }
	| { Name: "SetStars", Value: number }
	| { Name: "ReportCrime", Value: string }
	| { Name: "ResetWanted" }
	| { Name: "SetPoliceSight", Value: boolean }
	| { Name: "SimulateBust" }
	| { Name: "GrantCash", Value: any } -- raw value on purpose: EconomyRules must reject bad amounts
	| { Name: "DeductCash", Value: any }
	| { Name: "GrantCashTx", Value: string } -- fixed 100 with a caller-chosen transaction id
	| { Name: "SetDataStoreFailure", Value: boolean }
	| { Name: "SaveNow" }
	| { Name: "ClearRobberyCooldown" }
	| { Name: "SetCashUnavailable", Value: boolean } -- simulates losing cash data mid-session
	| { Name: "TryRobStore" }
	| { Name: "AddLedgerReward", Value: number } -- writes a reward straight into the ledger
	| { Name: "WriteLegacyProfile" } -- stores a v1 cash-only record; rejoin to test migration -- same server checks as the register prompt, minus the prompt's own range limit

local function finite(value: any): boolean
	return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

-- Returns a validated command, or nil and a reason.
function DevCommandRules.parse(name: any, value: any): (Command?, string?)
	if name == "SetHeat" then
		if not finite(value) or value < 0 or value > WantedConfig.MaxHeat then
			return nil, "SetHeat needs a number from 0 to MaxHeat"
		end
		return { Name = "SetHeat", Value = value }, nil
	elseif name == "SetStars" then
		if not finite(value) or value % 1 ~= 0 or value < 0 or value > #WantedConfig.StarThresholds then
			return nil, "SetStars needs a whole number from 0 to max stars"
		end
		return { Name = "SetStars", Value = value }, nil
	elseif name == "ReportCrime" then
		if type(value) ~= "string" or WantedConfig.Crimes[value] == nil then
			return nil, "ReportCrime needs a known crime type"
		end
		return { Name = "ReportCrime", Value = value }, nil
	elseif name == "ResetWanted" then
		return { Name = "ResetWanted" }, nil
	elseif name == "SetPoliceSight" then
		if type(value) ~= "boolean" then
			return nil, "SetPoliceSight needs true or false"
		end
		return { Name = "SetPoliceSight", Value = value }, nil
	elseif name == "SimulateBust" then
		return { Name = "SimulateBust" }, nil
	elseif name == "GrantCash" or name == "DeductCash" then
		return { Name = name, Value = value } :: any, nil
	elseif name == "GrantCashTx" then
		if type(value) ~= "string" then
			return nil, "GrantCashTx needs a transaction id string"
		end
		return { Name = "GrantCashTx", Value = value }, nil
	elseif name == "SetDataStoreFailure" then
		if type(value) ~= "boolean" then
			return nil, "SetDataStoreFailure needs true or false"
		end
		return { Name = "SetDataStoreFailure", Value = value }, nil
	elseif name == "SaveNow" then
		return { Name = "SaveNow" }, nil
	elseif name == "ClearRobberyCooldown" then
		return { Name = "ClearRobberyCooldown" }, nil
	elseif name == "SetCashUnavailable" then
		if type(value) ~= "boolean" then
			return nil, "SetCashUnavailable needs true or false"
		end
		return { Name = "SetCashUnavailable", Value = value }, nil
	elseif name == "AddLedgerReward" then
		if not finite(value) or value <= 0 or value % 1 ~= 0 then
			return nil, "AddLedgerReward needs a whole positive amount"
		end
		return { Name = "AddLedgerReward", Value = value }, nil
	elseif name == "WriteLegacyProfile" then
		return { Name = "WriteLegacyProfile" }, nil
	elseif name == "TryRobStore" then
		return { Name = "TryRobStore" }, nil
	end
	return nil, "Unknown command"
end

-- Heat in the middle of the `stars` band (0 for none), so a dev-set level does not lose a
-- star on the very first decay tick the way heat sitting exactly on a threshold would.
function DevCommandRules.heatForStars(stars: number): number
	if stars <= 0 then
		return 0
	end
	local thresholds = WantedConfig.StarThresholds
	local upper = thresholds[stars + 1] or WantedConfig.MaxHeat
	return (thresholds[stars] + upper) / 2
end

return DevCommandRules
