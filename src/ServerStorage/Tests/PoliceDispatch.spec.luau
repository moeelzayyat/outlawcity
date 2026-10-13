-- Dispatch and busting rules for NPC police, including the shared combat gate.
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Police = ServerScriptService.Server.Police
local PoliceDispatchRules = require(Police.PoliceDispatchRules)
local PoliceConfig = require(Police.PoliceConfig)
local RoadNetwork = require(Police.RoadNetwork)
local CombatRules = require(ReplicatedStorage.Shared.Combat.CombatRules)
local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)
local Assert = require(script.Parent.Assert)

local POLICE = { Kind = "NpcPolice", WantedStars = 0, InSafeZone = false, SpawnProtectedUntil = 0 }
local function suspect(stars: number)
	return { Kind = "Player", UserId = 1, Status = "Peaceful", WantedStars = stars, InSafeZone = false, SpawnProtectedUntil = 0 }
end

return {
	["prototype is limited to one unit"] = function()
		Assert.equal(PoliceConfig.MaxUnits, 1)
	end,
	["police cruiser exists and players cannot spawn it"] = function()
		local stats = VehicleConfig.get("Police")
		Assert.truthy(stats, "Police vehicle config")
		Assert.equal(stats.PlayerSpawnable, false)
		Assert.truthy(VehicleConfig.get(VehicleConfig.DefaultVehicleId).PlayerSpawnable ~= false, "Coupe still spawnable")
	end,
	["no dispatch for players who are not wanted"] = function()
		Assert.equal(PoliceDispatchRules.unitsFor(0, PoliceConfig.MaxUnits), 0)
		Assert.equal(PoliceDispatchRules.unitsFor(-1, PoliceConfig.MaxUnits), 0)
		Assert.equal(PoliceDispatchRules.unitsFor(nil :: any, PoliceConfig.MaxUnits), 0)
	end,
	["dispatch activates as soon as a star appears"] = function()
		for stars = 1, 3 do
			Assert.equal(PoliceDispatchRules.unitsFor(stars, PoliceConfig.MaxUnits), 1)
		end
	end,
	["spawn node is in the distance band when possible"] = function()
		local network = RoadNetwork.build()
		local target = Vector3.new(0, 0, 0)
		local rng = Random.new(5)
		for _ = 1, 50 do
			local node = assert(PoliceDispatchRules.chooseSpawnNode(network.Nodes, target, PoliceConfig.SpawnMinDistance, PoliceConfig.SpawnMaxDistance, rng))
			local d = RoadNetwork.flatDistance(network.Nodes[node], target)
			Assert.truthy(d >= PoliceConfig.SpawnMinDistance and d <= PoliceConfig.SpawnMaxDistance, `spawn at {d} studs`)
		end
		Assert.equal(PoliceDispatchRules.chooseSpawnNode({}, target, 1, 2, rng), nil)
	end,
	["bust needs range, a stopped target and permission, continuously"] = function()
		local C = PoliceConfig
		local state = PoliceDispatchRules.newBustState()
		local busted = false
		for _ = 1, math.ceil(C.BustSeconds / 0.25) do
			busted = PoliceDispatchRules.updateBust(state, 0.25, C.BustRange - 1, 0, true, C)
		end
		Assert.equal(busted, true)

		local function attempt(distance, speed, allowed)
			local s = PoliceDispatchRules.newBustState()
			local result = false
			for _ = 1, 40 do
				result = result or PoliceDispatchRules.updateBust(s, 0.25, distance, speed, allowed, C)
			end
			return result
		end
		Assert.equal(attempt(C.BustRange + 1, 0, true), false)
		Assert.equal(attempt(5, C.BustMaxTargetSpeed + 1, true), false)
		Assert.equal(attempt(5, 0, false), false)
	end,
	["moving away resets bust progress"] = function()
		local C = PoliceConfig
		local state = PoliceDispatchRules.newBustState()
		PoliceDispatchRules.updateBust(state, C.BustSeconds - 0.1, 5, 0, true, C)
		PoliceDispatchRules.updateBust(state, 0.25, 5, 30, true, C)
		Assert.equal(state.Progress, 0)
	end,
	["combat gate: police may bust wanted players and never unwanted ones"] = function()
		Assert.equal((CombatRules.canHarm(POLICE, suspect(1), { Now = 0, Action = "Bust" })), true)
		local ok, reason = CombatRules.canHarm(POLICE, suspect(0), { Now = 0, Action = "Bust" })
		Assert.equal(ok, false)
		Assert.equal(reason, "NotWanted")
	end,
}
