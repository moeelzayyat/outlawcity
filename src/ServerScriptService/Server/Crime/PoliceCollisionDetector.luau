--!strict
-- Gameplay crime detector: a player DRIVING a car into an NPC police car reports
-- "RammingPolice". Only the player car's own speed toward the police car counts, so police
-- driving into a parked player is not the player's crime. Detection only; the wanted rules
-- (heat, cooldown) live in WantedRules and are reached through WantedService.reportCrime.
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local WantedService = require(script.Parent.Parent.Services.WantedService)

local PoliceCollisionDetector = {}

local MIN_RAM_SPEED = 25 -- studs/s of the player's car toward the police car

export type Event = { Player: Player, Speed: number }

-- Watches one police chassis. onRam (optional) receives every detected ram, for logging.
function PoliceCollisionDetector.attach(policeChassis: BasePart, onRam: ((Event) -> ())?): RBXScriptConnection
	return policeChassis.Touched:Connect(function(hit: BasePart)
		local vehicles = Workspace:FindFirstChild("Vehicles")
		if not vehicles or not hit:IsDescendantOf(vehicles) then
			return
		end
		local car = hit:FindFirstAncestorOfClass("Model")
		while car and car.Parent ~= vehicles do
			car = car:FindFirstAncestorOfClass("Model")
		end
		if not car or not car.PrimaryPart then
			return
		end
		local driverId = car:GetAttribute("DriverUserId")
		local driver = if type(driverId) == "number" and driverId ~= 0 then Players:GetPlayerByUserId(driverId) else nil
		if not driver then
			return
		end
		local toPolice = policeChassis.Position - car.PrimaryPart.Position
		if toPolice.Magnitude < 1e-3 then
			return
		end
		local speed = car.PrimaryPart.AssemblyLinearVelocity:Dot(toPolice.Unit)
		if speed < MIN_RAM_SPEED then
			return
		end
		local accepted = WantedService.reportCrime(driver, "RammingPolice")
		if accepted and onRam then
			onRam({ Player = driver, Speed = speed })
		end
	end)
end

return PoliceCollisionDetector
