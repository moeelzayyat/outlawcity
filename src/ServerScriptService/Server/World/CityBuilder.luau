--!strict
-- Turns a CityLayout blueprint into anchored parts under Workspace.City.
-- Yields between chunks so it is safe to run in Studio edit mode or at server boot.
local CityLayout = require(script.Parent.CityLayout)

local CityBuilder = {}

local CHUNK_SIZE = 60
local SPAWN_PAD_SIZE = Vector3.new(9, 0.05, 15)

function CityBuilder.build(blueprint: CityLayout.Blueprint, parent: Instance): Folder
	local city = Instance.new("Folder")
	city.Name = "City"
	city:SetAttribute("GeneratedBy", "CityBuilder")
	city.Parent = parent

	local groups: { [string]: Folder } = {}
	local function groupFolder(name: string): Folder
		local existing = groups[name]
		if existing then
			return existing
		end
		local folder = Instance.new("Folder")
		folder.Name = name
		folder.Parent = city
		groups[name] = folder
		return folder
	end

	for i, spec in blueprint.Parts do
		local part = Instance.new("Part")
		part.Name = spec.Name
		part.Anchored = true
		part.Size = spec.Size
		part.CFrame = CFrame.new(spec.Center)
		part.Color = spec.Color
		part.Material = spec.Material
		part.CanCollide = spec.CanCollide
		part.TopSurface = Enum.SurfaceType.Smooth
		part.BottomSurface = Enum.SurfaceType.Smooth
		if not spec.CanCollide then
			part.CanQuery = false
			part.CanTouch = false
			part.CastShadow = false
		end
		part.Parent = groupFolder(spec.Group)
		if i % CHUNK_SIZE == 0 then
			task.wait()
		end
	end

	local spawnFolder = groupFolder("VehicleSpawns")
	for _, spawn in blueprint.Spawns do
		local pad = Instance.new("Part")
		pad.Name = spawn.Name
		pad.Anchored = true
		pad.CanCollide = false
		pad.CanQuery = false
		pad.CanTouch = false
		pad.CastShadow = false
		pad.Size = SPAWN_PAD_SIZE
		pad.CFrame = spawn.CFrame + Vector3.new(0, SPAWN_PAD_SIZE.Y / 2 + 0.03, 0)
		pad.Color = Color3.fromRGB(255, 200, 0)
		pad.Material = Enum.Material.SmoothPlastic
		pad.Transparency = 0.5
		pad.Parent = spawnFolder
	end

	return city
end

return CityBuilder
