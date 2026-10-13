--!strict
-- Turns "get from here to the target" into road waypoints using RoadNetwork. Pure.
-- Unit-tested in PoliceNavigation.spec.
local RoadNetwork = require(script.Parent.RoadNetwork)

local PolicePathPlanner = {}

-- Returns world waypoints ending at `target`. Skips the first node when the unit is already
-- past it, and the last node when the target lies before it on the final road segment.
function PolicePathPlanner.plan(network: RoadNetwork.Network, from: Vector3, target: Vector3): { Vector3 }
	local nodes = network.Nodes
	local startNode = RoadNetwork.nearestNode(network, from)
	local endNode = RoadNetwork.nearestNode(network, target)
	local path = RoadNetwork.findPath(network, startNode, endNode) or { startNode }

	local dist = RoadNetwork.flatDistance
	if #path >= 2 and dist(nodes[path[2]], from) < dist(nodes[path[2]], nodes[path[1]]) then
		table.remove(path, 1)
	end
	if #path >= 2 then
		local last, beforeLast = nodes[path[#path]], nodes[path[#path - 1]]
		if dist(target, beforeLast) < dist(last, beforeLast) then
			table.remove(path, #path)
		end
	end

	local waypoints = {}
	for _, node in path do
		table.insert(waypoints, nodes[node])
	end
	table.insert(waypoints, target)
	return waypoints
end

return PolicePathPlanner
