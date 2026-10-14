--!strict
-- Server authority for vehicles: spawning, seating, exiting, network ownership and cleanup.
-- Physics is simulated by one client per vehicle (the driver, else the owner); the server
-- decides who that is and publishes it in the "SimulatedBy" attribute.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Remotes = require(Shared.Net.Remotes)
local Types = require(Shared.Types)
local VehicleConfig = require(Shared.Config.VehicleConfig)
local Server = script.Parent.Parent
local VehicleFactory = require(Server.Vehicle.VehicleFactory)
local RateLimiter = require(Server.Util.RateLimiter)
local WorldService = require(script.Parent.WorldService)
local JailService = require(script.Parent.JailService)
local EconomyService = require(script.Parent.EconomyService)
local MilestoneLog = require(Server.Dev.MilestoneLog)

local VehicleService = {}

local SPAWN_COOLDOWN = 3
local EXIT_COOLDOWN = 0.5
local MAX_VEHICLE_ID_LENGTH = 32
local PROMPT_SLACK = 6 -- extra studs allowed beyond the prompt range for latency
local SPAWN_CLEARANCE = Vector3.new(10, 8, 16)
local SPAWN_DROP = 0.5
local SEAT_RETRIES = 10 -- re-seat attempts after a spawn (covers a client still leaving its old seat)
local SEAT_RETRY_INTERVAL = 0.1

local vehiclesFolder: Folder
local vehicleByOwner: { [number]: Model } = {}
local spawnLimiter = RateLimiter.new(SPAWN_COOLDOWN)
local exitLimiter = RateLimiter.new(EXIT_COOLDOWN)

local function getLiveHumanoid(player: Player): Humanoid?
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	if humanoid and humanoid.Health > 0 then
		return humanoid
	end
	return nil
end

local function getSeat(vehicle: Model): Seat?
	return vehicle:FindFirstChild("DriverSeat") :: Seat?
end

-- Driver simulates; otherwise the owner (so a parked car still rests on its springs); else the server.
local function updateSimulation(vehicle: Model)
	local chassis = vehicle.PrimaryPart
	local seat = getSeat(vehicle)
	if not chassis or not seat or not vehicle:IsDescendantOf(Workspace) then
		return
	end
	local occupant = seat.Occupant
	local driver = if occupant then Players:GetPlayerFromCharacter(occupant.Parent) else nil
	if driver and occupant and not JailService.allows(driver, "Drive") then
		-- A jailed player can never hold a driver seat (e.g. touch-sitting); eject them.
		local weld = seat:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		occupant.Sit = false
		driver = nil
		occupant = nil
	end
	local owner = Players:GetPlayerByUserId(vehicle:GetAttribute("OwnerUserId") :: number)
	local simulator = driver or owner
	chassis:SetNetworkOwner(simulator)
	vehicle:SetAttribute("SimulatedBy", if simulator then simulator.UserId else 0)
	vehicle:SetAttribute("DriverUserId", if driver then driver.UserId else 0)
	local prompt = seat:FindFirstChild("DrivePrompt") :: ProximityPrompt?
	if prompt then
		prompt.Enabled = occupant == nil
	end
end

local function despawnOwnedVehicle(userId: number)
	local vehicle = vehicleByOwner[userId]
	vehicleByOwner[userId] = nil
	if vehicle then
		vehicle:Destroy()
	end
end

local function findFreeSpawn(nearPosition: Vector3): CFrame?
	local candidates = WorldService.getVehicleSpawnCFrames()
	table.sort(candidates, function(a, b)
		return (a.Position - nearPosition).Magnitude < (b.Position - nearPosition).Magnitude
	end)
	local params = OverlapParams.new()
	params.FilterType = Enum.RaycastFilterType.Include
	params.FilterDescendantsInstances = { vehiclesFolder }
	for _, cframe in candidates do
		local box = cframe + Vector3.new(0, SPAWN_CLEARANCE.Y / 2, 0)
		if #Workspace:GetPartBoundsInBox(box, SPAWN_CLEARANCE, params) == 0 then
			return cframe
		end
	end
	return nil
end

local function sitIfFree(player: Player, vehicle: Model)
	local seat = getSeat(vehicle)
	local humanoid = getLiveHumanoid(player)
	if not seat or not humanoid or seat.Occupant or humanoid.SeatPart or not JailService.allows(player, "Drive") then
		return
	end
	local root = humanoid.RootPart
	local prompt = seat:FindFirstChild("DrivePrompt") :: ProximityPrompt?
	local range = (if prompt then prompt.MaxActivationDistance else 12) + PROMPT_SLACK
	if not root or (root.Position - seat.Position).Magnitude > range then
		return
	end
	seat:Sit(humanoid)
end

local function spawnVehicle(player: Player, vehicleId: string): (boolean, Types.SpawnError?)
	local stats = VehicleConfig.get(vehicleId)
	if not stats or stats.PlayerSpawnable == false then
		return false, "UnknownVehicle"
	end
	if not EconomyService.ownsVehicle(player, vehicleId) then
		return false, "NotOwned" -- the server's profile decides, never the client
	end
	if not JailService.allows(player, "SpawnVehicle") then
		return false, "Jailed"
	end
	local humanoid = getLiveHumanoid(player)
	local root = humanoid and humanoid.RootPart
	if not humanoid or not root then
		return false, "NotAlive"
	end
	if not spawnLimiter:tryConsume(player.UserId) then
		return false, "Cooldown"
	end

	-- Replacing a car while sitting in one: leave the old seat cleanly first (as exitVehicle
	-- does), so the character isn't still "seated" in a destroyed seat when the new one sits it.
	if humanoid.SeatPart then
		local weld = humanoid.SeatPart:FindFirstChild("SeatWeld")
		if weld then
			weld:Destroy()
		end
		humanoid.Sit = false
	end
	despawnOwnedVehicle(player.UserId)
	local spawnCFrame = findFreeSpawn(root.Position)
	if not spawnCFrame then
		spawnLimiter:reset(player.UserId)
		return false, "NoFreeSpawn"
	end

	local vehicle = VehicleFactory.build(vehicleId, stats)
	vehicle.Name = `{vehicleId}_{player.UserId}`
	vehicle:SetAttribute("OwnerUserId", player.UserId)
	vehicle:PivotTo(spawnCFrame * CFrame.new(0, VehicleFactory.getRideHeight(stats) + SPAWN_DROP, 0))
	vehicle.Parent = vehiclesFolder
	vehicleByOwner[player.UserId] = vehicle

	local seat = getSeat(vehicle)
	assert(seat, "vehicle has no DriverSeat")
	seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		updateSimulation(vehicle)
	end)
	local prompt = seat:FindFirstChild("DrivePrompt") :: ProximityPrompt?
	if prompt then
		prompt.Triggered:Connect(function(who: Player)
			sitIfFree(who, vehicle)
		end)
	end
	updateSimulation(vehicle)
	-- The character is simulated by its client, which can take a moment to leave its old seat;
	-- until it has sat in the new car once, retry briefly. Stops for good once it was seated (so
	-- a player who gets straight out isn't pulled back in), or the seat is taken, the car is
	-- gone, or the player may no longer drive.
	local seatedOnce = false
	local seatedConnection = seat:GetPropertyChangedSignal("Occupant"):Connect(function()
		if seat.Occupant == humanoid then
			seatedOnce = true
		end
	end)
	seat:Sit(humanoid)
	task.spawn(function()
		for _ = 1, SEAT_RETRIES do
			task.wait(SEAT_RETRY_INTERVAL)
			if seatedOnce or seat.Occupant ~= nil or not seat:IsDescendantOf(Workspace) then
				break
			end
			if humanoid.Health <= 0 or humanoid.Parent ~= player.Character or not JailService.allows(player, "Drive") then
				break
			end
			if humanoid.SeatPart == nil then
				seat:Sit(humanoid)
			end
		end
		seatedConnection:Disconnect()
	end)
	MilestoneLog.mark(player, "FirstCar")
	return true, nil
end

local function exitVehicle(player: Player)
	if not exitLimiter:tryConsume(player.UserId) then
		return
	end
	local humanoid = getLiveHumanoid(player)
	local seat = humanoid and humanoid.SeatPart
	if not humanoid or not seat or seat.Name ~= "DriverSeat" or not seat:IsDescendantOf(vehiclesFolder) then
		return
	end
	local weld = seat:FindFirstChild("SeatWeld")
	if weld then
		weld:Destroy()
	end
	humanoid.Sit = false
	local character = player.Character
	if character then
		local exitCFrame = seat.CFrame * CFrame.new(-4.5, 2, 0)
		character:PivotTo(CFrame.new(exitCFrame.Position) * seat.CFrame.Rotation)
	end
end

function VehicleService.init()
	local existing = Workspace:FindFirstChild("Vehicles")
	if existing then
		existing:Destroy()
	end
	vehiclesFolder = Instance.new("Folder")
	vehiclesFolder.Name = "Vehicles"
	vehiclesFolder.Parent = Workspace

	Remotes.getFunction("RequestSpawnVehicle").OnServerInvoke = function(player: Player, vehicleId: unknown)
		if typeof(vehicleId) ~= "string" or #vehicleId == 0 or #vehicleId > MAX_VEHICLE_ID_LENGTH then
			return false, "BadRequest"
		end
		return spawnVehicle(player, vehicleId)
	end
	Remotes.getEvent("RequestExitVehicle").OnServerEvent:Connect(exitVehicle)
end

function VehicleService.start()
	Players.PlayerRemoving:Connect(function(player)
		despawnOwnedVehicle(player.UserId)
		spawnLimiter:reset(player.UserId)
		exitLimiter:reset(player.UserId)
		-- Anyone they were driving falls back to its owner.
		for _, vehicle in vehiclesFolder:GetChildren() do
			if vehicle:IsA("Model") and vehicle:GetAttribute("SimulatedBy") == player.UserId then
				task.defer(updateSimulation, vehicle)
			end
		end
	end)
end

function VehicleService.getVehicleOf(player: Player): Model?
	return vehicleByOwner[player.UserId]
end

return VehicleService
