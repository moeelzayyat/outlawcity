--!strict
-- NPC police orchestration (Phase 3D prototype: ONE unit). Dispatches a server-simulated
-- police car when a player is wanted, plans road routes to them, reports sightings to
-- WantedService, busts stationary wanted players through CombatService, and ends the
-- pursuit on escape, bust or the target leaving. Logs performance and recovery events.
-- Path planning (PolicePathPlanner/RoadNetwork), movement (PoliceDriver) and dispatch rules
-- (PoliceDispatchRules) are separate modules; this service only wires them together.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local VehicleConfig = require(Shared.Config.VehicleConfig)
local Server = script.Parent.Parent
local Police = Server.Police
local PoliceConfig = require(Police.PoliceConfig)
local RoadNetwork = require(Police.RoadNetwork)
local PolicePathPlanner = require(Police.PolicePathPlanner)
local PoliceDispatchRules = require(Police.PoliceDispatchRules)
local PoliceDriver = require(Police.PoliceDriver)
local PoliceCollisionDetector = require(Server.Crime.PoliceCollisionDetector)
local VehicleFactory = require(Server.Vehicle.VehicleFactory)
local WantedService = require(script.Parent.WantedService)
local CombatService = require(script.Parent.CombatService)
local JailService = require(script.Parent.JailService)

local PoliceService = {}

local POLICE_VEHICLE_ID = "Police"
local TICK = 0.25

type Unit = {
	Model: Model,
	Driver: PoliceDriver.PoliceDriver,
	Target: Player,
	Ending: boolean,
	SeesTarget: boolean,
	Bust: PoliceDispatchRules.BustState,
	NextReplan: number,
	FarSince: number?,
	RamConnection: RBXScriptConnection,
	Stats: {
		Frames: number,
		StepSeconds: number,
		MaxStepMs: number,
		Respawns: number,
	},
}

local network = RoadNetwork.build()
local npcFolder: Folder
local unit: Unit? = nil
local rng = Random.new()
local lastLog = 0

-- Event log kept for Studio tests and diagnostics (most recent 60 entries).
local eventLog: { string } = {}
local function logEvent(text: string)
	local line = string.format("%.1f %s", Workspace:GetServerTimeNow() % 1000, text)
	table.insert(eventLog, line)
	if #eventLog > 60 then
		table.remove(eventLog, 1)
	end
	npcFolder:SetAttribute("EventLog", table.concat(eventLog, "\n"))
	print(`[Police] {text}`)
end

local function ignoreList(): { Instance }
	local list: { Instance } = { npcFolder }
	local vehicles = Workspace:FindFirstChild("Vehicles")
	if vehicles then
		table.insert(list, vehicles)
	end
	for _, player in Players:GetPlayers() do
		if player.Character then
			table.insert(list, player.Character)
		end
	end
	return list
end

local function targetRoot(player: Player): BasePart?
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	return if root and root:IsA("BasePart") then root else nil
end

local function hasLineOfSight(from: Vector3, to: Vector3): boolean
	local params = RaycastParams.new()
	params.FilterType = Enum.RaycastFilterType.Exclude
	params.FilterDescendantsInstances = ignoreList()
	return Workspace:Raycast(from, to - from, params) == nil
end

local function placeOnNode(nodeIndex: number, lookAt: Vector3)
	local current = unit
	if not current then
		return
	end
	local stats = VehicleConfig.get(POLICE_VEHICLE_ID)
	assert(stats, "Police vehicle config missing")
	current.Driver:reposition(network.Nodes[nodeIndex], lookAt, VehicleFactory.getRideHeight(stats))
end

local function buildPoliceCar(): Model
	local stats = VehicleConfig.get(POLICE_VEHICLE_ID)
	assert(stats, "Police vehicle config missing")
	local model = VehicleFactory.build(POLICE_VEHICLE_ID, stats)
	model.Name = "PoliceUnit"
	model:SetAttribute("Npc", true)
	-- NPC cars are not drivable by players.
	local seat = model:FindFirstChild("DriverSeat")
	if seat and seat:IsA("Seat") then
		seat.Disabled = true
		local prompt = seat:FindFirstChild("DrivePrompt")
		if prompt then
			prompt:Destroy()
		end
	end
	-- Light bar so the unit reads as police at a glance.
	local chassis = model.PrimaryPart :: BasePart
	for side, color in { [-1] = Color3.fromRGB(255, 40, 40), [1] = Color3.fromRGB(40, 90, 255) } do
		local light = Instance.new("Part")
		light.Name = "LightBar"
		light.Size = Vector3.new(1.6, 0.35, 0.8)
		light.Material = Enum.Material.Neon
		light.Color = color
		light.Massless = true
		light.CanCollide = false
		light.CanQuery = false
		light.CanTouch = false
		light.CFrame = chassis.CFrame * CFrame.new(side * 1.0, stats.ChassisSize.Y / 2 + 2.15, 1.0)
		local weld = Instance.new("WeldConstraint")
		weld.Part0 = chassis
		weld.Part1 = light
		weld.Parent = light
		light.Parent = model
	end
	return model
end

local function despawn(reason: string)
	local current = unit
	if not current then
		return
	end
	unit = nil
	current.RamConnection:Disconnect()
	current.Driver:destroy()
	local s = current.Stats
	logEvent(string.format(
		"despawn (%s): frames=%d avgStep=%.3fms maxStep=%.3fms softRecoveries=%d hardRecoveries=%d respawns=%d",
		reason,
		s.Frames,
		if s.Frames > 0 then s.StepSeconds / s.Frames * 1000 else 0,
		s.MaxStepMs,
		current.Driver.softRecoveries,
		current.Driver.hardRecoveries,
		s.Respawns
	))
	current.Model:Destroy()
end

local function spawnFor(target: Player)
	local root = targetRoot(target)
	if not root then
		return
	end
	local nodeIndex = PoliceDispatchRules.chooseSpawnNode(network.Nodes, root.Position, PoliceConfig.SpawnMinDistance, PoliceConfig.SpawnMaxDistance, rng)
	if not nodeIndex then
		return
	end
	local stats = VehicleConfig.get(POLICE_VEHICLE_ID)
	assert(stats, "Police vehicle config missing")
	local model = buildPoliceCar()
	local spawnPosition = network.Nodes[nodeIndex]
	local height = VehicleFactory.getRideHeight(stats) + 0.5
	model:PivotTo(CFrame.lookAt(
		spawnPosition + Vector3.new(0, height, 0),
		Vector3.new(root.Position.X, spawnPosition.Y + height, root.Position.Z)
	))
	model.Parent = npcFolder
	local chassis = model.PrimaryPart :: BasePart
	chassis:SetNetworkOwner(nil)
	local driver = PoliceDriver.new(model, stats, ignoreList())
	if not driver then
		model:Destroy()
		return
	end
	unit = {
		Model = model,
		Driver = driver,
		Target = target,
		Ending = false,
		SeesTarget = false,
		Bust = PoliceDispatchRules.newBustState(),
		NextReplan = 0,
		FarSince = nil,
		RamConnection = PoliceCollisionDetector.attach(chassis, function(event)
			logEvent(string.format("crime detected: %s rammed police at %.0f studs/s", event.Player.Name, event.Speed))
		end),
		Stats = { Frames = 0, StepSeconds = 0, MaxStepMs = 0, Respawns = 0 },
	}
	logEvent(string.format("dispatched to %s from node %s (%.0f studs away)", target.Name, network.Names[nodeIndex], (spawnPosition - root.Position).Magnitude))
end

local function endPursuit(reason: string)
	local current = unit
	if not current or current.Ending then
		return
	end
	current.Ending = true
	current.Driver:setRoute({}, false)
	logEvent(`pursuit ended: {reason}`)
	task.delay(PoliceConfig.DespawnDelay, function()
		if unit == current then
			despawn(reason)
		end
	end)
end

local function bust(target: Player)
	-- JailService re-validates (must be wanted, no duplicate sentence), clears wanted with no
	-- reward and holds the player in the jail cell; release is server-timed.
	local jailed, err = JailService.jailForBust(target)
	logEvent(if jailed then `BUSTED {target.Name} -> jail` else `bust of {target.Name} refused: {tostring(err)}`)
	endPursuit("busted")
end

-- Players the unit must not be dispatched to yet (server systems only). A unit already
-- chasing the player keeps chasing.
local dispatchHolds: { [Player]: boolean } = {}

function PoliceService.setDispatchHold(player: Player, held: boolean)
	dispatchHolds[player] = if held then true else nil
end

local function tick(dt: number)
	local now = Workspace:GetServerTimeNow()
	local current = unit

	-- Dispatch: one unit for the most-wanted player.
	if not current then
		local best, bestStars = nil :: Player?, 0
		for _, player in Players:GetPlayers() do
			local stars = WantedService.getStars(player)
			if dispatchHolds[player] then
				continue -- e.g. a store robbery still in its holdout: police respond when it ends
			end
			if PoliceDispatchRules.unitsFor(stars, PoliceConfig.MaxUnits) > 0 and stars > bestStars then
				best, bestStars = player, stars
			end
		end
		if best then
			spawnFor(best)
		end
		return
	end
	if current.Ending then
		return
	end

	-- Termination.
	local target = current.Target
	if target.Parent ~= Players then
		endPursuit("target left")
		return
	end
	if WantedService.getStars(target) <= 0 then
		endPursuit("target no longer wanted (escaped or cleared)")
		return
	end
	local root = targetRoot(target)
	local chassis = current.Model.PrimaryPart
	if not root or not chassis then
		return
	end

	-- Perception.
	local distance = RoadNetwork.flatDistance(root.Position, chassis.Position)
	local sees = distance <= PoliceConfig.SightRange
		and hasLineOfSight(chassis.Position + Vector3.new(0, 3, 0), root.Position + Vector3.new(0, 1.5, 0))
	if sees ~= current.SeesTarget then
		logEvent(if sees then string.format("sighted %s at %.0f studs", target.Name, distance) else `lost sight of {target.Name}`)
	end
	current.SeesTarget = sees

	-- Busting through the shared combat rules.
	local allowed = CombatService.canPoliceBust(target)
	if PoliceDispatchRules.updateBust(current.Bust, dt, distance, root.AssemblyLinearVelocity.Magnitude, allowed, PoliceConfig) then
		bust(target)
		return
	end

	-- Fallen far behind: respawn closer (out of sight).
	if distance > PoliceConfig.LostTargetRespawnDistance then
		current.FarSince = current.FarSince or now
		if now - (current.FarSince :: number) > PoliceConfig.LostTargetSeconds then
			local node = PoliceDispatchRules.chooseSpawnNode(network.Nodes, root.Position, PoliceConfig.SpawnMinDistance, PoliceConfig.SpawnMaxDistance, rng)
			if node then
				placeOnNode(node, root.Position)
				current.Stats.Respawns += 1
				current.NextReplan = 0
				logEvent(`respawned closer at node {network.Names[node]}`)
			end
			current.FarSince = nil
		end
	else
		current.FarSince = nil
	end

	-- Route planning: direct chase (refreshed every tick) when close and in sight, otherwise a
	-- road route re-planned every ReplanInterval.
	local chase = sees and distance <= PoliceConfig.DirectChaseRange
	if chase then
		current.Driver:setChaseTarget(root.Position, root.AssemblyLinearVelocity)
		current.NextReplan = 0
	elseif now >= current.NextReplan then
		current.NextReplan = now + PoliceConfig.ReplanInterval
		current.Driver:setRoute(PolicePathPlanner.plan(network, chassis.Position, root.Position), false)
		current.Driver:setIgnoreList(ignoreList())
	end

	if now - lastLog >= PoliceConfig.LogInterval then
		lastLog = now
		local s = current.Stats
		logEvent(string.format(
			"status: dist=%.0f sees=%s speed=%.0f frames=%d avgStep=%.3fms maxStep=%.3fms soft=%d hard=%d whiskerFrames=%d",
			distance,
			tostring(sees),
			chassis.AssemblyLinearVelocity.Magnitude,
			s.Frames,
			if s.Frames > 0 then s.StepSeconds / s.Frames * 1000 else 0,
			s.MaxStepMs,
			current.Driver.softRecoveries,
			current.Driver.hardRecoveries,
			current.Driver.whiskerHits
		))
	end
end

local function physicsStep(dt: number)
	local current = unit
	if not current then
		return
	end
	local started = os.clock()
	local event = current.Driver:step(dt, Workspace:GetServerTimeNow())
	local elapsed = os.clock() - started
	local s = current.Stats
	s.Frames += 1
	s.StepSeconds += elapsed
	s.MaxStepMs = math.max(s.MaxStepMs, elapsed * 1000)
	if event == "HardRecover" then
		-- Repeated stalls mean the road ahead is blocked (the planner has no traffic data), so
		-- re-enter the network elsewhere, out of sight of the target, instead of retrying.
		local chassis = current.Model.PrimaryPart
		local root = targetRoot(current.Target)
		if chassis and root then
			local node = PoliceDispatchRules.chooseSpawnNode(network.Nodes, root.Position, PoliceConfig.SpawnMinDistance, PoliceConfig.SpawnMaxDistance, rng)
			if node then
				local stalledAt = chassis.Position
				placeOnNode(node, root.Position)
				current.NextReplan = 0
				logEvent(`hard recovery: stalled repeatedly at ({math.floor(stalledAt.X)}, {math.floor(stalledAt.Z)}); re-entered at node {network.Names[node]}`)
			end
		end
	end
end

-- Sighting hook for WantedService: true while the unit can see this player.
local function seesPlayer(player: Player): boolean
	local current = unit
	return current ~= nil and not current.Ending and current.Target == player and current.SeesTarget
end

function PoliceService.init()
	local existing = Workspace:FindFirstChild("NpcVehicles")
	if existing then
		existing:Destroy()
	end
	npcFolder = Instance.new("Folder")
	npcFolder.Name = "NpcVehicles"
	npcFolder.Parent = Workspace
	WantedService.setPoliceSightProvider(seesPlayer)
end

Players.PlayerRemoving:Connect(function(player)
	dispatchHolds[player] = nil
end)

function PoliceService.start()
	RunService.PreSimulation:Connect(physicsStep)
	task.spawn(function()
		while true do
			tick(task.wait(TICK))
		end
	end)
end

function PoliceService.getUnit(): Model?
	return if unit then unit.Model else nil
end

return PoliceService
