--!strict
-- Hands out the player-data store. In Studio it uses a separate "_Studio" DataStore so tests
-- never touch live player data, and it can simulate failures (Studio only) to test that a
-- broken DataStore never wipes progress.
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")

local DataStoreAdapter = {}

local failureMode = false

function DataStoreAdapter.storeName(baseName: string): string
	return if RunService:IsStudio() then baseName .. "_Studio" else baseName
end

-- Studio-only: when on, every store call errors as if Roblox's DataStore were down.
function DataStoreAdapter.setSimulatedFailure(enabled: boolean)
	assert(RunService:IsStudio(), "simulated DataStore failure is Studio-only")
	failureMode = enabled
end

function DataStoreAdapter.isSimulatingFailure(): boolean
	return failureMode
end

function DataStoreAdapter.get(baseName: string): any
	local store = DataStoreService:GetDataStore(DataStoreAdapter.storeName(baseName))
	return {
		UpdateAsync = function(_, key: string, transform: (any) -> any): any
			if failureMode then
				error("Simulated DataStore failure (Studio test)")
			end
			return store:UpdateAsync(key, transform)
		end,
	}
end

return DataStoreAdapter
