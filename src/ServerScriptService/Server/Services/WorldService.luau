--!strict
-- Owns the driving test area. Uses Workspace.City if it already exists in the place
-- (built in edit mode), otherwise builds it from CityLayout at server start.
local Workspace = game:GetService("Workspace")

local World = script.Parent.Parent.World
local CityLayout = require(World.CityLayout)
local CityBuilder = require(World.CityBuilder)

local WorldService = {}

local city: Instance? = nil

function WorldService.init()
	city = Workspace:FindFirstChild("City")
	if not city then
		city = CityBuilder.build(CityLayout.createBlueprint(), Workspace)
	end
end

function WorldService.start() end

-- Spawn pad CFrames at road surface height, facing the direction the car should face.
function WorldService.getVehicleSpawnCFrames(): { CFrame }
	local result = {}
	local spawns = city and city:FindFirstChild("VehicleSpawns")
	if spawns then
		for _, pad in spawns:GetChildren() do
			if pad:IsA("BasePart") then
				table.insert(result, pad.CFrame - Vector3.new(0, pad.CFrame.Y - CityLayout.ROAD_TOP, 0))
			end
		end
	end
	return result
end

return WorldService
