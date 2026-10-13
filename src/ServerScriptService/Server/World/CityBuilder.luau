--!strict
-- Turns a CityLayout blueprint into anchored parts under Workspace.City.
-- Yields between chunks so it is safe to run in Studio edit mode or at server boot.
local CityLayout = require(script.Parent.CityLayout)

local CityBuilder = {}

local ReplicatedStorage = game:GetService("ReplicatedStorage")
local GameplayConfig = require(ReplicatedStorage.Shared.Config.GameplayConfig)

local CHUNK_SIZE = 60
local SPAWN_PAD_SIZE = Vector3.new(9, 0.05, 15)
local CIVILIAN_SPAWN_SIZE = Vector3.new(8, 0.1, 8)

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

	CityBuilder.buildCivilianSpawns(blueprint, city)
	return city
end

-- Adds City.CivilianSpawns if missing (safe to call on an existing city). Returns the folder.
-- Thin, non-colliding SpawnLocations; Duration gives the built-in spawn ForceField.
function CityBuilder.buildCivilianSpawns(blueprint: CityLayout.Blueprint, city: Instance): Folder
	local existing = city:FindFirstChild("CivilianSpawns")
	if existing and existing:IsA("Folder") then
		return existing
	end
	local folder = Instance.new("Folder")
	folder.Name = "CivilianSpawns"
	for _, spawn in blueprint.CivilianSpawns do
		local location = Instance.new("SpawnLocation")
		location.Name = spawn.Name
		location.Anchored = true
		location.CanCollide = false
		location.CanQuery = false
		location.CastShadow = false
		location.Size = CIVILIAN_SPAWN_SIZE
		location.CFrame = spawn.CFrame + Vector3.new(0, CIVILIAN_SPAWN_SIZE.Y / 2, 0)
		location.Color = Color3.fromRGB(90, 200, 255)
		location.Material = Enum.Material.SmoothPlastic
		location.Transparency = 0.4
		location.Neutral = true
		location.AllowTeamChangeOnTouch = false
		location.Duration = GameplayConfig.SpawnProtectionSeconds
		location.Parent = folder
	end
	folder.Parent = city
	return folder
end

return CityBuilder
