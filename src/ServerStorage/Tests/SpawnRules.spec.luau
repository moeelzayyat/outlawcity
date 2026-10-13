local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SpawnRules = require(ReplicatedStorage.Shared.Player.SpawnRules)
local Assert = require(script.Parent.Assert)

local CANDIDATES = { Vector3.new(0, 0, 0), Vector3.new(20, 0, 0), Vector3.new(40, 0, 0) }

return {
	["empty server can use every spawn"] = function()
		local rng = Random.new(1)
		local seen = {}
		for _ = 1, 200 do
			seen[SpawnRules.pickSpawn(CANDIDATES, {}, 8, rng)] = true
		end
		Assert.truthy(seen[1] and seen[2] and seen[3], "all spawns used over many picks")
	end,
	["occupied spawns are skipped"] = function()
		local rng = Random.new(2)
		local occupied = { Vector3.new(1, 0, 0), Vector3.new(41, 0, 2) } -- near spawns 1 and 3
		for _ = 1, 50 do
			Assert.equal(SpawnRules.pickSpawn(CANDIDATES, occupied, 8, rng), 2)
		end
	end,
	["all occupied falls back to the least crowded"] = function()
		local occupied = { Vector3.new(0, 0, 0), Vector3.new(19, 0, 0), Vector3.new(36, 0, 0) }
		-- Spawn 3 (x=40) has its nearest occupant 4 studs away, the most of the three.
		Assert.equal(SpawnRules.pickSpawn(CANDIDATES, occupied, 8, Random.new(3)), 3)
	end,
	["simulated 12-player join fills spawns evenly"] = function()
		local rng = Random.new(4)
		local occupied = {}
		local counts = { 0, 0, 0 }
		for _ = 1, 3 do
			local index = SpawnRules.pickSpawn(CANDIDATES, occupied, 8, rng)
			counts[index] += 1
			table.insert(occupied, CANDIDATES[index])
		end
		Assert.truthy(counts[1] == 1 and counts[2] == 1 and counts[3] == 1, "first three players get different spawns")
	end,
}
