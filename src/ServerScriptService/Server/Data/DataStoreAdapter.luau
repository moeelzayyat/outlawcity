--!strict
-- Hands out the player-data store. In Studio it uses a separate "_Studio" DataStore so tests
-- never touch live player data, and it can simulate failures (Studio only) to test that a
-- broken DataStore never wipes progress.
local DataStoreService = game:GetService("DataStoreService")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

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

-- Also on while the Studio-only Workspace attribute SimulateDataStoreFailure is true, so a test
-- can toggle failures with no player in the game (e.g. after a kick).
function DataStoreAdapter.isSimulatingFailure(): boolean
	return failureMode or (RunService:IsStudio() and Workspace:GetAttribute("SimulateDataStoreFailure") == true)
end

function DataStoreAdapter.get(baseName: string): any
	local store = DataStoreService:GetDataStore(DataStoreAdapter.storeName(baseName))
	-- Studio-only: Workspace attribute SimulateStoreFailure_<baseName> fails just this store.
	local perStore = "SimulateStoreFailure_" .. baseName
	return {
		UpdateAsync = function(_, key: string, transform: (any) -> any): any
			if DataStoreAdapter.isSimulatingFailure() or (RunService:IsStudio() and Workspace:GetAttribute(perStore) == true) then
				error("Simulated DataStore failure (Studio test)")
			end
			return store:UpdateAsync(key, transform)
		end,
	}
end

return DataStoreAdapter
