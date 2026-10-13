--!strict
-- Server-side observation of client-simulated PLAYER vehicles (Workspace.Vehicles only; NPC
-- police in Workspace.NpcVehicles are server-simulated and never judged here).
-- MONITOR-ONLY: samples every vehicle at 5 Hz, runs VehicleValidationRules, and logs
-- observations and alerts to the Output and to ServerStorage.Diagnostics. It never resets,
-- moves, kicks or punishes anyone. Future rewards for driving must come from server-validated
-- gameplay events, not from client claims.
local Players = game:GetService("Players")
local ServerStorage = game:GetService("ServerStorage")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local VehicleConfig = require(ReplicatedStorage.Shared.Config.VehicleConfig)
local Validation = script.Parent.Parent.Validation
local VehicleValidationConfig = require(Validation.VehicleValidationConfig)
local VehicleValidationRules = require(Validation.VehicleValidationRules)

local VehicleValidationService = {}

type Track = { State: VehicleValidationRules.TrackState, Limits: VehicleValidationRules.Limits }

local tracks: { [Model]: Track } = setmetatable({}, { __mode = "k" }) :: any
local diagnostics: Folder
local logLines: { string } = {}
local totals = { Samples = 0, Observations = 0, Alerts = 0, Loops = 0, LoopSeconds = 0, MaxLoopMs = 0 }

local function log(text: string)
	table.insert(logLines, string.format("%.1f %s", Workspace:GetServerTimeNow() % 1000, text))
	while #logLines > VehicleValidationConfig.LogLines do
		table.remove(logLines, 1)
	end
	diagnostics:SetAttribute("ValidationLog", table.concat(logLines, "\n"))
	print(`[VehicleValidation] {text}`)
end

local function publishTotals()
	for key, value in totals do
		diagnostics:SetAttribute(key, value)
	end
end

local function ownerName(vehicle: Model): string
	local ownerId = vehicle:GetAttribute("OwnerUserId")
	local owner = if type(ownerId) == "number" then Players:GetPlayerByUserId(ownerId) else nil
	return if owner then owner.Name else tostring(ownerId)
end

-- Does the chassis' network owner match the player the server assigned in SimulatedBy?
local function ownerMatches(vehicle: Model, chassis: BasePart): boolean
	local ok, owner = pcall(chassis.GetNetworkOwner, chassis)
	if not ok then
		return true -- anchored or not simulated; nothing to compare
	end
	local simulatedBy = vehicle:GetAttribute("SimulatedBy")
	local expected = if type(simulatedBy) == "number" and simulatedBy ~= 0 then Players:GetPlayerByUserId(simulatedBy) else nil
	return owner == expected
end

-- Authorized server moves (spawn, reposition, recovery) call this so they aren't judged.
function VehicleValidationService.authorizeReposition(vehicle: Model, seconds: number?)
	local track = tracks[vehicle]
	if track then
		VehicleValidationRules.grant(track.State, Workspace:GetServerTimeNow(), seconds or VehicleValidationConfig.SpawnGraceSeconds)
	end
end

local function sampleAll()
	local started = os.clock()
	local now = Workspace:GetServerTimeNow()
	local vehicles = Workspace:FindFirstChild("Vehicles")
	if not vehicles then
		return
	end
	for _, vehicle in vehicles:GetChildren() do
		if not vehicle:IsA("Model") or vehicle:GetAttribute("Npc") then
			continue
		end
		local chassis = vehicle.PrimaryPart
		local stats = VehicleConfig.get(vehicle:GetAttribute("VehicleId") :: string)
		if not chassis or not stats then
			continue
		end
		local track = tracks[vehicle]
		if not track then
			track = {
				State = VehicleValidationRules.new(now, VehicleValidationConfig.SpawnGraceSeconds),
				Limits = VehicleValidationRules.limitsFor(stats, VehicleValidationConfig),
			}
			tracks[vehicle] = track
		end
		local result = VehicleValidationRules.observe(track.State, {
			Time = now,
			Position = chassis.Position,
			Velocity = chassis.AssemblyLinearVelocity,
			OwnerOk = ownerMatches(vehicle, chassis),
		}, track.Limits, VehicleValidationConfig)
		totals.Samples += 1
		for _, observation in result.Observations do
			totals.Observations += 1
			log(`observation {observation.Kind} ({ownerName(vehicle)}, {vehicle.Name}): {observation.Detail}`)
		end
		if result.Alert then
			totals.Alerts += 1
			log(`ALERT [monitor-only, no action taken] {ownerName(vehicle)} {vehicle.Name}: {result.Alert}`)
		end
	end
	local elapsed = os.clock() - started
	totals.Loops += 1
	totals.LoopSeconds += elapsed
	totals.MaxLoopMs = math.max(totals.MaxLoopMs, elapsed * 1000)
end

function VehicleValidationService.getTotals(): { [string]: number }
	return table.clone(totals)
end

function VehicleValidationService.init()
	diagnostics = ServerStorage:FindFirstChild("Diagnostics") :: Folder
	if not diagnostics then
		local created = Instance.new("Folder")
		created.Name = "Diagnostics"
		created.Parent = ServerStorage
		diagnostics = created
	end
end

function VehicleValidationService.start()
	local lastSummary = os.clock()
	task.spawn(function()
		while true do
			task.wait(VehicleValidationConfig.SampleInterval)
			sampleAll()
			publishTotals()
			if os.clock() - lastSummary >= VehicleValidationConfig.SummaryInterval then
				lastSummary = os.clock()
				log(string.format(
					"summary: samples=%d observations=%d alerts=%d avgLoop=%.3fms maxLoop=%.3fms",
					totals.Samples,
					totals.Observations,
					totals.Alerts,
					if totals.Loops > 0 then totals.LoopSeconds / totals.Loops * 1000 else 0,
					totals.MaxLoopMs
				))
			end
		end
	end)
end

return VehicleValidationService
