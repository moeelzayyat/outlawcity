--!strict
-- Pure dispatch and busting rules for NPC police. Unit-tested in PoliceDispatch.spec.
local PoliceDispatchRules = {}

-- How many units a target with `stars` should have (0 when not wanted).
function PoliceDispatchRules.unitsFor(stars: number, maxUnits: number): number
	if type(stars) ~= "number" or stars <= 0 then
		return 0
	end
	return math.max(0, maxUnits)
end

-- Picks a spawn node index: random among nodes within [min, max] of the target; otherwise the
-- node just beyond max; otherwise the farthest node. Returns nil only for an empty list.
function PoliceDispatchRules.chooseSpawnNode(
	nodes: { Vector3 },
	target: Vector3,
	minDistance: number,
	maxDistance: number,
	rng: Random
): number?
	if #nodes == 0 then
		return nil
	end
	local band, beyond, farthest = {}, nil :: number?, 1
	local beyondDistance, farthestDistance = math.huge, -1
	for i, node in nodes do
		local d = Vector3.new(node.X - target.X, 0, node.Z - target.Z).Magnitude
		if d >= minDistance and d <= maxDistance then
			table.insert(band, i)
		elseif d > maxDistance and d < beyondDistance then
			beyond, beyondDistance = i, d
		end
		if d > farthestDistance then
			farthest, farthestDistance = i, d
		end
	end
	if #band > 0 then
		return band[rng:NextInteger(1, #band)]
	end
	return beyond or farthest
end

export type BustState = { Progress: number }

function PoliceDispatchRules.newBustState(): BustState
	return { Progress = 0 }
end

-- Busting needs the combat rules' permission (`allowed`, i.e. the target is wanted), the unit
-- within range, and the target nearly stopped, continuously for BustSeconds.
function PoliceDispatchRules.updateBust(
	state: BustState,
	dt: number,
	distance: number,
	targetSpeed: number,
	allowed: boolean,
	config: { BustRange: number, BustSeconds: number, BustMaxTargetSpeed: number }
): boolean
	if allowed and distance <= config.BustRange and targetSpeed <= config.BustMaxTargetSpeed then
		state.Progress += dt
	else
		state.Progress = 0
	end
	return state.Progress >= config.BustSeconds
end

return PoliceDispatchRules
