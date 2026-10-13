--!strict
-- Pure spawn-point selection. Unit-tested in ServerStorage.Tests.SpawnRules.spec.
local SpawnRules = {}

-- Picks a random spawn with nothing within `clearance` studs; if every spawn is occupied,
-- picks the one farthest from its nearest occupant. Returns an index into `candidates`.
function SpawnRules.pickSpawn(candidates: { Vector3 }, occupied: { Vector3 }, clearance: number, rng: Random): number
	assert(#candidates > 0, "no spawn candidates")
	local free = {}
	local bestIndex, bestDistance = 1, -1
	for index, position in candidates do
		local nearest = math.huge
		for _, other in occupied do
			nearest = math.min(nearest, (other - position).Magnitude)
		end
		if nearest > clearance then
			table.insert(free, index)
		end
		if nearest > bestDistance then
			bestIndex, bestDistance = index, nearest
		end
	end
	if #free > 0 then
		return free[rng:NextInteger(1, #free)]
	end
	return bestIndex
end

return SpawnRules
