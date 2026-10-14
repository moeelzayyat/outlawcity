-- Road network, path planning and driving rules for NPC police (pure; no Studio physics).
-- Passing these does NOT mean navigation works in the city: that is verified by playtests.
local ServerScriptService = game:GetService("ServerScriptService")
local Police = ServerScriptService.Server.Police
local RoadNetwork = require(Police.RoadNetwork)
local PolicePathPlanner = require(Police.PolicePathPlanner)
local PoliceDriveRules = require(Police.PoliceDriveRules)
local PoliceConfig = require(Police.PoliceConfig)
local CityLayout = require(ServerScriptService.Server.World.CityLayout)
local Assert = require(script.Parent.Assert)

local network = RoadNetwork.build()
local blueprint = CityLayout.createBlueprint()

local function onDrivable(x: number, z: number): boolean
	for _, spec in blueprint.Parts do
		if spec.Group == "Roads" or spec.Group == "Plaza" or spec.Group == "Highway" then
			local c, s = spec.Center, spec.Size
			if math.abs(x - c.X) <= s.X / 2 and math.abs(z - c.Z) <= s.Z / 2 then
				return true
			end
		end
	end
	return false
end

return {
	["every node sits on a drivable surface"] = function()
		for i, node in network.Nodes do
			Assert.truthy(onDrivable(node.X, node.Z), `node {network.Names[i]} is off-road`)
		end
	end,
	["every edge runs over drivable surface"] = function()
		for a, neighbours in network.Edges do
			for _, b in neighbours do
				local p, q = network.Nodes[a], network.Nodes[b]
				for t = 0, 1, 0.05 do
					local x, z = p.X + (q.X - p.X) * t, p.Z + (q.Z - p.Z) * t
					Assert.truthy(onDrivable(x, z), `edge {network.Names[a]}-{network.Names[b]} leaves the road at ({x}, {z})`)
				end
			end
		end
	end,
	["network is fully connected"] = function()
		for i = 2, #network.Nodes do
			Assert.truthy(RoadNetwork.findPath(network, 1, i), `no path to {network.Names[i]}`)
		end
	end,
	["paths only use real edges and are shortest on a simple case"] = function()
		local function index(name)
			return table.find(network.Names, name) :: number
		end
		local path = assert(RoadNetwork.findPath(network, index("G_-300_-300"), index("G_300_-300")))
		Assert.equal(#path, 4, "straight along one road")
		for i = 1, #path - 1 do
			Assert.truthy(table.find(network.Edges[path[i]], path[i + 1]), "consecutive nodes are linked")
		end
		local toHighway = assert(RoadNetwork.findPath(network, index("G_100_100"), index("HwyEndE")))
		Assert.truthy(table.find(toHighway, index("H_100")), "highway reached via the x=100 connector")
	end,
	["planner ends at the target and skips nodes already passed"] = function()
		local from = Vector3.new(-250, 0, -300) -- on the road, already past G_-300_-300
		local target = Vector3.new(300, 0, -250) -- on the x=300 road, just south of G_300_-300
		local waypoints = PolicePathPlanner.plan(network, from, target)
		Assert.equal(waypoints[#waypoints], target)
		Assert.truthy((waypoints[1] - Vector3.new(-300, CityLayout.ROAD_TOP, -300)).Magnitude > 1, "did not drive back to the passed node")
		for i = 1, #waypoints - 1 do
			Assert.truthy(onDrivable(waypoints[i].X, waypoints[i].Z), "waypoint on road")
		end
	end,
	["steering sign and corner angles"] = function()
		local right = PoliceDriveRules.steerToward(Vector3.new(10, 0, -10), PoliceConfig.MaxSteerAngle)
		local left = PoliceDriveRules.steerToward(Vector3.new(-10, 0, -10), PoliceConfig.MaxSteerAngle)
		local ahead = PoliceDriveRules.steerToward(Vector3.new(0, 0, -10), PoliceConfig.MaxSteerAngle)
		Assert.truthy(right > 0 and left < 0, "positive steer turns right")
		Assert.near(ahead, 0, 1e-9)
		Assert.near(PoliceDriveRules.cornerAngle(Vector3.new(0, 0, 0), Vector3.new(0, 0, -10), Vector3.new(10, 0, -10)), math.pi / 2, 1e-6)
		Assert.near(PoliceDriveRules.cornerAngle(Vector3.new(0, 0, 0), Vector3.new(0, 0, -10), Vector3.new(0, 0, -20)), 0, 1e-6)
	end,
	["slows for sharp corners and when pointing the wrong way"] = function()
		local C = PoliceConfig
		local straight = PoliceDriveRules.targetSpeed(5, 0, 0, C.CruiseSpeed, C)
		local rightAngle = PoliceDriveRules.targetSpeed(5, math.pi / 2, 0, C.CruiseSpeed, C)
		local farFromCorner = PoliceDriveRules.targetSpeed(200, math.pi / 2, 0, C.CruiseSpeed, C)
		local wrongWay = PoliceDriveRules.targetSpeed(200, 0, math.rad(90), C.CruiseSpeed, C)
		Assert.truthy(rightAngle < straight, "corner slower than straight")
		Assert.near(rightAngle, C.CornerSpeedMin + 5 * C.CornerDecel, 1e-6)
		Assert.equal(farFromCorner, C.CruiseSpeed)
		Assert.equal(wrongWay, C.CornerSpeedMin)
		Assert.equal(PoliceDriveRules.throttleFor(50, 50, C.ThrottleGain), 0)
		Assert.equal(PoliceDriveRules.throttleFor(100, 0, C.ThrottleGain), 1)
	end,
	["stuck detection reverses, then hard-recovers after repeated stalls"] = function()
		local C = PoliceConfig
		local state = PoliceDriveRules.newStuckState()
		local now, dt = 0, 0.1
		local actions = {}
		for _ = 1, 200 do
			now += dt
			local action = PoliceDriveRules.updateStuck(state, dt, now, 0, true, C)
			if action ~= actions[#actions] then
				table.insert(actions, action)
			end
			if action == "HardRecover" then
				break
			end
		end
		Assert.equal(actions[1], "Drive")
		Assert.equal(actions[2], "Reverse")
		Assert.equal(actions[#actions], "HardRecover")
		Assert.truthy(now < C.RecoveryWindow, "hard recovery within the window")
	end,
	["chase speed matches the target and closes the gap"] = function()
		local C = PoliceConfig
		Assert.equal(PoliceDriveRules.chaseSpeed(35, C.ChaseFollowDistance, C.ChaseFollowDistance, C.ChaseGain, C.ChaseSpeed), 35)
		-- Closes a gap in proportion to ChaseGain (tuning lives in PoliceConfig; the audit
		-- remediation lowered it from 1.0 to 0.25), never faster than ChaseSpeed.
		local closing = PoliceDriveRules.chaseSpeed(35, 65, C.ChaseFollowDistance, C.ChaseGain, C.ChaseSpeed)
		Assert.truthy(closing > 35, "closes a 65-stud gap")
		Assert.equal(closing, math.min(35 + (65 - C.ChaseFollowDistance) * C.ChaseGain, C.ChaseSpeed))
		Assert.equal(PoliceDriveRules.chaseSpeed(0, 0, C.ChaseFollowDistance, C.ChaseGain, C.ChaseSpeed), 0)
		Assert.equal(PoliceDriveRules.chaseSpeed(200, 500, C.ChaseFollowDistance, C.ChaseGain, C.ChaseSpeed), C.ChaseSpeed)
	end,
	["moving or idle cars are never considered stuck"] = function()
		local state = PoliceDriveRules.newStuckState()
		for i = 1, 100 do
			Assert.equal(PoliceDriveRules.updateStuck(state, 0.1, i * 0.1, 40, true, PoliceConfig), "Drive")
			Assert.equal(PoliceDriveRules.updateStuck(state, 0.1, i * 0.1, 0, false, PoliceConfig), "Drive")
		end
	end,
}
