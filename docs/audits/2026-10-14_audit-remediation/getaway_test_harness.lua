-- Studio test harness (client, run through execute_luau): robbery + scripted getaway driven by
-- the real VehiclePhysics with waypoint steering. Not part of the game.
local p = game.Players.LocalPlayer
local RS = game:GetService("RunService")
local Shared = game.ReplicatedStorage.Shared
local VehicleConfig = require(Shared.Config.VehicleConfig)
local VehiclePhysics = require(Shared.Vehicle.VehiclePhysics)
local dev = game.ReplicatedStorage.DevRemotes.RequestDevCommand
local Remotes = game.ReplicatedStorage.Remotes

_G.__results = _G.__results or {}
_G.__notices = {}
if not _G.__noticeConn then
	_G.__noticeConn = Remotes.OnRobberyNotice.OnClientEvent:Connect(function(kind)
		table.insert(_G.__notices, kind)
	end)
end

local NORTH = { Vector3.new(-100, 0, -300), Vector3.new(300, 0, -300), Vector3.new(300, 0, 300), Vector3.new(-300, 0, 300), Vector3.new(-300, 0, -300) }
local EAST = { Vector3.new(-100, 0, -100), Vector3.new(300, 0, -100), Vector3.new(300, 0, 300), Vector3.new(-300, 0, 300), Vector3.new(-300, 0, -300), Vector3.new(300, 0, -300) }

local function police()
	return workspace.NpcVehicles:FindFirstChild("PoliceUnit")
end

local function waitFree()
	-- end any robbery left from an earlier run, and wait out jail
	if p:GetAttribute("RobberyPhase") ~= nil then
		dev:InvokeServer("SetStars", 1)
		task.wait(0.3)
		dev:InvokeServer("SimulateBust")
		task.wait(1)
	end
	while p:GetAttribute("Jailed") do
		task.wait(0.5)
	end
	task.wait(1)
	dev:InvokeServer("ResetWanted")
	dev:InvokeServer("ClearRobberyCooldown")
end

function _G.runGetaway(label: string, vehicleId: string)
	local log = { label = label, events = {} }
	table.insert(_G.__results, log)
	local function ev(s)
		table.insert(log.events, string.format("%.1f %s", workspace:GetServerTimeNow() % 1000, s))
	end
	waitFree()
	local hum = p.Character:WaitForChild("Humanoid")
	if hum.SeatPart then
		Remotes.RequestExitVehicle:FireServer()
		task.wait(1)
	end
	local _, err = Remotes.RequestSpawnVehicle:InvokeServer(vehicleId)
	task.wait(1.5)
	local car = hum.SeatPart and hum.SeatPart:FindFirstAncestorOfClass("Model")
	if not car then
		log.result = "setup failed " .. tostring(err)
		return
	end
	local pos = Vector3.new(-104, 3, -72)
	car:PivotTo(CFrame.lookAt(pos, pos + Vector3.new(0, 0, -1)))
	for _, d in car:GetDescendants() do
		if d:IsA("BasePart") then
			d.AssemblyLinearVelocity = Vector3.zero
			d.AssemblyAngularVelocity = Vector3.zero
		end
	end
	task.wait(1)
	Remotes.RequestExitVehicle:FireServer()
	task.wait(1.2)
	p.Character.HumanoidRootPart.CFrame = CFrame.new(-135, 4, -58) * CFrame.Angles(0, math.rad(90), 0)
	task.wait(0.6)
	table.clear(_G.__notices)
	local cash0 = p:GetAttribute("Cash")
	local rok, rerr = dev:InvokeServer("TryRobStore")
	ev("rob " .. tostring(rok) .. "/" .. tostring(rerr))
	if not rok then
		log.result = "rob refused"
		return
	end
	while p:GetAttribute("RobberyPhase") == "Holding" do
		task.wait(0.05)
	end
	ev("holdout over: " .. tostring(p:GetAttribute("RobberyPhase")))
	hum:MoveTo(Vector3.new(-117, 3, -62))
	hum.MoveToFinished:Wait()
	hum:MoveTo(car.DriverSeat.Position)
	local t0 = os.clock()
	while not hum.SeatPart and os.clock() - t0 < 6 do
		task.wait(0.05)
	end
	if not hum.SeatPart then
		log.result = "could not reach car"
		return
	end
	local u = police()
	local route = if u and u:GetPivot().Position.Z < car:GetPivot().Position.Z - 40 then EAST else NORTH
	ev("seated; police " .. (if u then string.format("(%d,%d)", u:GetPivot().Position.X, u:GetPivot().Position.Z) else "none") .. " route " .. (if route == EAST then "east" else "north"))
	car:SetAttribute("SimulatedBy", -1) -- local only: the game's controller stops simulating it
	task.wait()
	local physics = VehiclePhysics.new(car, VehicleConfig.get(car:GetAttribute("VehicleId")), { car, p.Character })
	local wp, laps = 1, 0
	local done = false
	local conn = RS.Heartbeat:Connect(function(dt)
		if done or not car.Parent then
			return
		end
		local cf = car:GetPivot()
		local target = route[wp]
		local to = Vector3.new(target.X - cf.Position.X, 0, target.Z - cf.Position.Z)
		if to.Magnitude < 22 then
			wp += 1
			if wp > #route then
				wp = 2
				laps += 1
			end
			return
		end
		local look = Vector3.new(cf.LookVector.X, 0, cf.LookVector.Z).Unit
		local angle = math.atan2(look:Cross(to.Unit).Y, look:Dot(to.Unit))
		local speed = car.PrimaryPart.AssemblyLinearVelocity.Magnitude
		local throttle = if (math.abs(angle) > 0.35 and speed > 40) or (to.Magnitude < 70 and speed > 60) then 0 else 1
		physics:step(dt, { Throttle = throttle, Steer = math.clamp(-angle * 2.5, -1, 1), Handbrake = false })
	end)
	local tStart = os.clock()
	local result = "timeout (still wanted)"
	local maxGap, firstEvading = 0, nil
	while os.clock() - tStart < 120 do
		local n = _G.__notices
		if table.find(n, "Paid") then
			result = "PAID"
			break
		end
		if table.find(n, "Failed") then
			result = "FAILED (" .. (if p:GetAttribute("Jailed") then "busted" else "other") .. ")"
			break
		end
		local pu = police()
		if pu then
			maxGap = math.max(maxGap, (pu:GetPivot().Position - car:GetPivot().Position).Magnitude)
		end
		if not firstEvading and p:GetAttribute("WantedEvading") == true then
			firstEvading = math.floor(os.clock() - tStart)
		end
		task.wait(0.5)
	end
	done = true
	conn:Disconnect()
	physics:destroy()
	car:SetAttribute("SimulatedBy", p.UserId)
	log.result = result
	log.time = math.floor(os.clock() - tStart)
	log.maxGap = math.floor(maxGap)
	log.laps = laps
	log.evading = firstEvading
	log.cash = tostring(cash0) .. "->" .. tostring(p:GetAttribute("Cash"))
	ev("end " .. result)
end

function _G.summary()
	local out = {}
	for i, r in _G.__results do
		table.insert(out, string.format("%d %s: %s after %ss driving; max police gap %s; first evading at %ss; laps %s; cash %s | %s", i, r.label, tostring(r.result), tostring(r.time), tostring(r.maxGap), tostring(r.evading), tostring(r.laps), tostring(r.cash), table.concat(r.events, "; ")))
	end
	return table.concat(out, "\n")
end

function _G.runSet(prefix: string, vehicleId: string, n: number)
	for i = 1, n do
		_G.runGetaway(prefix .. "-" .. i .. " " .. vehicleId, vehicleId)
	end
	_G.__setDone = true
end
