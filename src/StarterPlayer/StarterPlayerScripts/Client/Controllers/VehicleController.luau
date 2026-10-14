--!strict
-- Client side of vehicles: runs VehiclePhysics for every vehicle this client simulates,
-- tracks whether the local player is driving, and forwards spawn/exit requests to the server.
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage.Shared
local Types = require(Shared.Types)
local Remotes = require(Shared.Net.Remotes)
local Signal = require(Shared.Util.Signal)
local VehicleConfig = require(Shared.Config.VehicleConfig)
local VehiclePhysics = require(Shared.Vehicle.VehiclePhysics)
local VehicleInputController = require(script.Parent.VehicleInputController)

local VehicleController = {}

VehicleController.DrivingChanged = Signal.new() -- (vehicle: Model?)
VehicleController.SpawnResult = Signal.new() -- (ok: boolean, err: string?)

local IDLE_INPUT: Types.VehicleInput = table.freeze({ Throttle = 0, Steer = 0, Handbrake = true })
local IGNORE_REFRESH_SECONDS = 1

local player = Players.LocalPlayer
local vehiclesFolder: Folder? = nil
local simulated: { [Model]: VehiclePhysics.VehiclePhysics } = {}
local currentVehicle: Model? = nil
local spawnPending = false
local ignoreTimer = 0

local function buildIgnoreList(): { Instance }
	local list: { Instance } = {}
	if vehiclesFolder then
		table.insert(list, vehiclesFolder)
	end
	for _, other in Players:GetPlayers() do
		if other.Character then
			table.insert(list, other.Character)
		end
	end
	return list
end

local function refreshVehicle(vehicle: Instance)
	if not vehicle:IsA("Model") then
		return
	end
	local mine = vehicle:GetAttribute("SimulatedBy") == player.UserId and vehicle.Parent ~= nil
	local existing = simulated[vehicle]
	if mine and not existing then
		local stats = VehicleConfig.get(vehicle:GetAttribute("VehicleId") :: string)
		local physics = stats and VehiclePhysics.new(vehicle, stats, buildIgnoreList())
		if physics then
			simulated[vehicle] = physics
		end
	elseif not mine and existing then
		existing:destroy()
		simulated[vehicle] = nil
	end
end

local function watchVehicle(vehicle: Instance)
	if not vehicle:IsA("Model") then
		return
	end
	vehicle:GetAttributeChangedSignal("SimulatedBy"):Connect(function()
		refreshVehicle(vehicle)
	end)
	vehicle:GetAttributeChangedSignal("VehicleId"):Connect(function()
		refreshVehicle(vehicle)
	end)
	refreshVehicle(vehicle)
end

local function setJumpEnabled(humanoid: Humanoid, enabled: boolean)
	humanoid:SetStateEnabled(Enum.HumanoidStateType.Jumping, enabled)
	local touchGui = player:FindFirstChildOfClass("PlayerGui") and player.PlayerGui:FindFirstChild("TouchGui")
	local jumpButton = touchGui and touchGui:FindFirstChild("JumpButton", true)
	if jumpButton and jumpButton:IsA("GuiObject") then
		jumpButton.Visible = enabled
	end
end

local function setCurrentVehicle(vehicle: Model?, humanoid: Humanoid?)
	if vehicle == currentVehicle then
		return
	end
	currentVehicle = vehicle
	if humanoid then
		setJumpEnabled(humanoid, vehicle == nil)
	end
	VehicleController.DrivingChanged:Fire(vehicle)
end

local function onSeated(humanoid: Humanoid, active: boolean, seat: BasePart?)
	local vehicle: Model? = nil
	if active and seat and seat.Name == "DriverSeat" and vehiclesFolder and seat:IsDescendantOf(vehiclesFolder) then
		local parent = seat.Parent
		if parent and parent:IsA("Model") then
			vehicle = parent
		end
	end
	setCurrentVehicle(vehicle, humanoid)
end

local function onCharacter(character: Model)
	local humanoid = character:WaitForChild("Humanoid", 10) :: Humanoid?
	if not humanoid then
		return
	end
	setCurrentVehicle(nil, humanoid)
	humanoid.Seated:Connect(function(active, seat)
		onSeated(humanoid, active, seat)
	end)
	-- Moving straight from one seat to another (a car replaced while driving) may not fire
	-- Seated again, so also follow SeatPart itself.
	humanoid:GetPropertyChangedSignal("SeatPart"):Connect(function()
		local seat = humanoid.SeatPart
		onSeated(humanoid, seat ~= nil, seat)
	end)
	if humanoid.SeatPart then
		onSeated(humanoid, true, humanoid.SeatPart)
	end
end

local function step(dt: number)
	ignoreTimer += dt
	local refreshIgnore = ignoreTimer >= IGNORE_REFRESH_SECONDS
	if refreshIgnore then
		ignoreTimer = 0
	end
	local ignore = if refreshIgnore then buildIgnoreList() else nil
	for vehicle, physics in simulated do
		if not vehicle.Parent then
			physics:destroy()
			simulated[vehicle] = nil
			continue
		end
		if ignore then
			physics:setIgnoreList(ignore)
		end
		local input = if vehicle == currentVehicle then VehicleInputController.getInput() else IDLE_INPUT
		physics:step(dt, input)
	end
end

function VehicleController.init()
	task.spawn(function()
		local folder = Workspace:WaitForChild("Vehicles") :: Folder
		vehiclesFolder = folder
		folder.ChildAdded:Connect(watchVehicle)
		folder.ChildRemoved:Connect(function(vehicle)
			if vehicle == currentVehicle then
				-- The car we were driving is gone (replaced or removed): stop driving it.
				local character = player.Character
				local humanoid = character and character:FindFirstChildOfClass("Humanoid")
				setCurrentVehicle(nil, humanoid)
				if humanoid and humanoid.SeatPart then
					onSeated(humanoid, true, humanoid.SeatPart)
				end
			end
			if vehicle:IsA("Model") then
				local physics = simulated[vehicle]
				if physics then
					physics:destroy()
					simulated[vehicle] = nil
				end
			end
		end)
		for _, vehicle in folder:GetChildren() do
			watchVehicle(vehicle)
		end
		if player.Character then
			task.spawn(onCharacter, player.Character)
		end
		player.CharacterAdded:Connect(onCharacter)
	end)
	RunService.PreSimulation:Connect(step)
end

function VehicleController.getCurrentVehicle(): Model?
	return currentVehicle
end

-- Horizontal speed of the vehicle being driven, studs/s.
function VehicleController.getCurrentSpeed(): number
	local chassis = currentVehicle and currentVehicle.PrimaryPart
	if not chassis then
		return 0
	end
	local velocity = chassis.AssemblyLinearVelocity
	return Vector3.new(velocity.X, 0, velocity.Z).Magnitude
end

function VehicleController.requestSpawn(vehicleId: string)
	if spawnPending then
		return
	end
	spawnPending = true
	task.spawn(function()
		local ok, result, err = pcall(function()
			return Remotes.getFunction("RequestSpawnVehicle"):InvokeServer(vehicleId)
		end)
		spawnPending = false
		if ok then
			VehicleController.SpawnResult:Fire(result == true, err)
		else
			VehicleController.SpawnResult:Fire(false, "NetworkError")
		end
	end)
end

function VehicleController.requestExit()
	if currentVehicle then
		Remotes.getEvent("RequestExitVehicle"):FireServer()
	end
end

return VehicleController
