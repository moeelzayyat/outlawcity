--!strict
-- Driving waypoint graph for NPC vehicles, derived from CityLayout. Grid nodes sit on road
-- centre lines at intersections; highway nodes sit in the south carriageway, clear of the
-- median barrier. Pure data + queries (A* over ~25 nodes). Unit-tested in PoliceNavigation.spec.
local CityLayout = require(script.Parent.Parent.World.CityLayout)

export type Network = {
	Nodes: { Vector3 },
	Names: { string },
	Edges: { { number } },
}

local RoadNetwork = {}

local function flatDistance(a: Vector3, b: Vector3): number
	return Vector3.new(a.X - b.X, 0, a.Z - b.Z).Magnitude
end
RoadNetwork.flatDistance = flatDistance

function RoadNetwork.build(): Network
	local nodes: { Vector3 } = {}
	local names: { string } = {}
	local edges: { { number } } = {}
	local index: { [string]: number } = {}
	local y = CityLayout.ROAD_TOP

	local function add(name: string, x: number, z: number): number
		table.insert(nodes, Vector3.new(x, y, z))
		table.insert(names, name)
		table.insert(edges, {})
		index[name] = #nodes
		return #nodes
	end
	local function link(a: number, b: number)
		table.insert(edges[a], b)
		table.insert(edges[b], a)
	end

	local lines = CityLayout.GRID_LINES
	for _, x in lines do
		for _, z in lines do
			add(`G_{x}_{z}`, x, z)
		end
	end
	for i, x in lines do
		for j, z in lines do
			if i < #lines then
				link(index[`G_{x}_{z}`], index[`G_{lines[i + 1]}_{z}`])
			end
			if j < #lines then
				link(index[`G_{x}_{z}`], index[`G_{x}_{lines[j + 1]}`])
			end
		end
	end

	-- Plaza centre: an open paved block joined to the four intersections around it.
	local plaza = add("Plaza", 0, 0)
	for _, x in { lines[2], lines[3] } do
		for _, z in { lines[2], lines[3] } do
			link(plaza, index[`G_{x}_{z}`])
		end
	end

	-- Highway: south carriageway lane, junctions at each connector, turnaround plazas at the ends.
	local laneZ = CityLayout.HIGHWAY_Z + CityLayout.HIGHWAY_WIDTH / 4
	local halfLength = CityLayout.HIGHWAY_HALF_LENGTH
	local xs = { -halfLength }
	for _, x in CityLayout.CONNECTOR_XS do
		table.insert(xs, x)
	end
	table.insert(xs, halfLength)
	table.sort(xs)
	local previous: number? = nil
	for _, x in xs do
		local node = add(`H_{x}`, x, laneZ)
		if previous then
			link(previous, node)
		end
		previous = node
	end
	local endOffset = halfLength + CityLayout.END_PLAZA_SIZE / 2
	link(add("HwyEndW", -endOffset, CityLayout.HIGHWAY_Z), index[`H_{-halfLength}`])
	link(add("HwyEndE", endOffset, CityLayout.HIGHWAY_Z), index[`H_{halfLength}`])

	-- Connectors from the northern grid road up to the highway.
	for _, x in CityLayout.CONNECTOR_XS do
		link(index[`G_{x}_{lines[1]}`], index[`H_{x}`])
	end

	return { Nodes = nodes, Names = names, Edges = edges }
end

function RoadNetwork.nearestNode(network: Network, position: Vector3): number
	local best, bestDistance = 1, math.huge
	for i, node in network.Nodes do
		local d = flatDistance(node, position)
		if d < bestDistance then
			best, bestDistance = i, d
		end
	end
	return best
end

-- A* shortest path from node `from` to node `to`; returns node indices including both ends.
function RoadNetwork.findPath(network: Network, from: number, to: number): { number }?
	local nodes = network.Nodes
	if not nodes[from] or not nodes[to] then
		return nil
	end
	local open: { [number]: boolean } = { [from] = true }
	local cameFrom: { [number]: number } = {}
	local g: { [number]: number } = { [from] = 0 }
	local f: { [number]: number } = { [from] = flatDistance(nodes[from], nodes[to]) }
	while next(open) do
		local current, best = -1, math.huge
		for node in open do
			if f[node] < best then
				current, best = node, f[node]
			end
		end
		if current == to then
			local path = { current }
			while cameFrom[current] do
				current = cameFrom[current]
				table.insert(path, 1, current)
			end
			return path
		end
		open[current] = nil
		for _, neighbour in network.Edges[current] do
			local tentative = g[current] + flatDistance(nodes[current], nodes[neighbour])
			if tentative < (g[neighbour] or math.huge) then
				cameFrom[neighbour] = current
				g[neighbour] = tentative
				f[neighbour] = tentative + flatDistance(nodes[neighbour], nodes[to])
				open[neighbour] = true
			end
		end
	end
	return nil
end

return RoadNetwork
