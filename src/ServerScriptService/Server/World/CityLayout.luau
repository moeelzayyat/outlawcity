--!strict
-- Data-only description of the driving test area. CityBuilder turns the blueprint into parts
-- and CityLayout.spec validates it. Units are studs; the Baseplate top is Y = 0.
local Types = require(game:GetService("ReplicatedStorage").Shared.Types)

export type PartSpec = {
	Name: string,
	Group: string,
	Center: Vector3,
	Size: Vector3,
	Color: Color3,
	Material: Enum.Material,
	CanCollide: boolean,
}
export type SpawnSpec = { Name: string, CFrame: CFrame }
-- Spawns: vehicle spawn pads. CivilianSpawns: where player characters appear.
export type Blueprint = { Parts: { PartSpec }, Spawns: { SpawnSpec }, CivilianSpawns: { SpawnSpec } }

local CityLayout = {}

CityLayout.ROAD_WIDTH = 36
CityLayout.GRID_LINES = { -300, -100, 100, 300 }
CityLayout.GRID_EXTENT = 318 -- outer edge of the outermost grid roads
CityLayout.HIGHWAY_Z = -520
CityLayout.HIGHWAY_WIDTH = 56
CityLayout.HIGHWAY_HALF_LENGTH = 700
CityLayout.CONNECTOR_XS = { -100, 100 } -- grid roads that continue north onto the highway
CityLayout.END_PLAZA_SIZE = 120
CityLayout.ROAD_TOP = 0.2
CityLayout.CURB_TOP = 0.6

local ROAD_THICKNESS = 0.4
local MARK_THICKNESS = 0.05
local MARK_TOP = CityLayout.ROAD_TOP + MARK_THICKNESS
local BARRIER_HEIGHT = 2.6
local BUILDING_SEED = 20261013

local COLORS = {
	Road = Color3.fromRGB(48, 48, 54),
	Sidewalk = Color3.fromRGB(150, 150, 145),
	Plaza = Color3.fromRGB(72, 72, 80),
	Yellow = Color3.fromRGB(240, 190, 40),
	White = Color3.fromRGB(235, 235, 235),
	Barrier = Color3.fromRGB(175, 175, 168),
}
local BUILDING_COLORS = {
	Color3.fromRGB(120, 110, 100),
	Color3.fromRGB(90, 100, 115),
	Color3.fromRGB(150, 130, 105),
	Color3.fromRGB(105, 85, 80),
	Color3.fromRGB(175, 170, 160),
}

local function slab(
	name: string,
	group: string,
	x: number,
	z: number,
	sizeX: number,
	sizeZ: number,
	top: number,
	thickness: number,
	color: Color3,
	material: Enum.Material,
	canCollide: boolean
): PartSpec
	return {
		Name = name,
		Group = group,
		Center = Vector3.new(x, top - thickness / 2, z),
		Size = Vector3.new(sizeX, thickness, sizeZ),
		Color = color,
		Material = material,
		CanCollide = canCollide,
	}
end

local function barrier(name: string, x1: number, z1: number, x2: number, z2: number, width: number): PartSpec
	local sizeX = if x1 == x2 then width else math.abs(x2 - x1)
	local sizeZ = if z1 == z2 then width else math.abs(z2 - z1)
	return slab(
		name,
		"Barriers",
		(x1 + x2) / 2,
		(z1 + z2) / 2,
		sizeX,
		sizeZ,
		CityLayout.ROAD_TOP + BARRIER_HEIGHT,
		BARRIER_HEIGHT,
		COLORS.Barrier,
		Enum.Material.Concrete,
		true
	)
end

-- Open stretches of road between intersections along one grid line, as {from, to} pairs.
function CityLayout.stretches(): { { number } }
	local half = CityLayout.ROAD_WIDTH / 2
	local lines = CityLayout.GRID_LINES
	local result = {}
	for i = 1, #lines - 1 do
		table.insert(result, { lines[i] + half, lines[i + 1] - half })
	end
	return result
end

-- Splits [from, to] into pieces that skip the given openings ({centre, halfWidth}).
local function withOpenings(from: number, to: number, openings: { { number } }): { { number } }
	local pieces = {}
	local cursor = from
	for _, opening in openings do
		local a, b = opening[1] - opening[2], opening[1] + opening[2]
		if a > cursor then
			table.insert(pieces, { cursor, a })
		end
		cursor = math.max(cursor, b)
	end
	if cursor < to then
		table.insert(pieces, { cursor, to })
	end
	return pieces
end

-- Safe zones (server-authoritative; see SafeZoneService). The first is the central plaza block
-- that holds the civilian spawns. Future garages add entries here.
function CityLayout.safeZones(): { Types.SafeZone }
	local plaza = CityLayout.stretches()[2]
	return {
		{
			Name = "Plaza",
			Min = Vector3.new(plaza[1], -20, plaza[1]),
			Max = Vector3.new(plaza[2], 80, plaza[2]),
		},
	}
end

-- Short-jail cell: one building south of the grid, off the road network (no new city area).
-- Solid walls on three sides, a barred front, a roof, and SLOT_COUNT separate standing spots.
CityLayout.JAIL_CENTER = Vector3.new(0, 0, 420)
CityLayout.JAIL_SIZE = 28
CityLayout.JAIL_HEIGHT = 12
CityLayout.JAIL_SLOT_COUNT = 4

function CityLayout.jail(): { Parts: { PartSpec }, Slots: { CFrame } }
	local c = CityLayout.JAIL_CENTER
	local half = CityLayout.JAIL_SIZE / 2
	local h = CityLayout.JAIL_HEIGHT
	local top = CityLayout.ROAD_TOP
	local wallColor = Color3.fromRGB(110, 110, 118)
	local parts: { PartSpec } = {}
	local function add(name: string, x: number, z: number, sizeX: number, sizeZ: number, partTop: number, thickness: number, color: Color3, material: Enum.Material)
		table.insert(parts, slab(name, "Jail", c.X + x, c.Z + z, sizeX, sizeZ, partTop, thickness, color, material, true))
	end
	add("JailFloor", 0, 0, 2 * half, 2 * half, top, 0.4, Color3.fromRGB(90, 90, 95), Enum.Material.Concrete)
	add("JailRoof", 0, 0, 2 * half + 2, 2 * half + 2, top + h + 1, 1, wallColor, Enum.Material.Concrete)
	add("JailWallNorth", 0, -half - 0.5, 2 * half + 2, 1, top + h, h, wallColor, Enum.Material.Concrete)
	add("JailWallWest", -half - 0.5, 0, 1, 2 * half, top + h, h, wallColor, Enum.Material.Concrete)
	add("JailWallEast", half + 0.5, 0, 1, 2 * half, top + h, h, wallColor, Enum.Material.Concrete)
	-- Barred front (south): 0.6-stud bars every 2 studs leave 1.4-stud gaps, too narrow to pass.
	local bar = 0
	for x = -half, half, 2 do
		bar += 1
		add(`JailBar{bar}`, x, half + 0.5, 0.6, 0.6, top + h, h, Color3.fromRGB(40, 40, 45), Enum.Material.Metal)
	end
	local slots = {}
	for _, offset in { Vector2.new(-6, -6), Vector2.new(6, -6), Vector2.new(-6, 6), Vector2.new(6, 6) } do
		table.insert(slots, CFrame.new(c.X + offset.X, top + 3, c.Z + offset.Y) * CFrame.Angles(0, math.pi, 0))
	end
	return { Parts = parts, Slots = slots }
end

function CityLayout.createBlueprint(): Blueprint
	local parts: { PartSpec } = {}
	local spawns: { SpawnSpec } = {}
	local function add(spec: PartSpec)
		table.insert(parts, spec)
	end

	local W = CityLayout.ROAD_WIDTH
	local E = CityLayout.GRID_EXTENT
	local TOP = CityLayout.ROAD_TOP
	local stretches = CityLayout.stretches()

	-- Grid roads. East-west roads run the full width and own the intersections;
	-- north-south roads are split between them so no two road parts overlap.
	for _, z in CityLayout.GRID_LINES do
		add(slab(`RoadEW_{z}`, "Roads", 0, z, 2 * E, W, TOP, ROAD_THICKNESS, COLORS.Road, Enum.Material.Asphalt, true))
	end
	for _, x in CityLayout.GRID_LINES do
		for i, s in stretches do
			local length = s[2] - s[1]
			local mid = (s[1] + s[2]) / 2
			add(slab(`RoadNS_{x}_{i}`, "Roads", x, mid, W, length, TOP, ROAD_THICKNESS, COLORS.Road, Enum.Material.Asphalt, true))
		end
	end

	-- Centre lines on every stretch between intersections.
	for _, line in CityLayout.GRID_LINES do
		for i, s in stretches do
			local length = s[2] - s[1]
			local mid = (s[1] + s[2]) / 2
			add(slab(`LineEW_{line}_{i}`, "Markings", mid, line, length, 0.8, MARK_TOP, MARK_THICKNESS, COLORS.Yellow, Enum.Material.SmoothPlastic, false))
			add(slab(`LineNS_{line}_{i}`, "Markings", line, mid, 0.8, length, MARK_TOP, MARK_THICKNESS, COLORS.Yellow, Enum.Material.SmoothPlastic, false))
		end
	end

	-- City blocks: the centre block is a flat plaza with vehicle spawns, the rest are raised sidewalks.
	local rng = Random.new(BUILDING_SEED)
	for bi, sx in stretches do
		for bj, sz in stretches do
			local cx, cz = (sx[1] + sx[2]) / 2, (sz[1] + sz[2]) / 2
			local size = sx[2] - sx[1]
			if cx == 0 and cz == 0 then
				add(slab("Plaza", "Plaza", cx, cz, size, size, TOP, ROAD_THICKNESS, COLORS.Plaza, Enum.Material.Concrete, true))
			else
				local curb = CityLayout.CURB_TOP
				add(slab(`Block_{bi}_{bj}`, "Sidewalks", cx, cz, size, size, curb, curb, COLORS.Sidewalk, Enum.Material.Concrete, true))
				local quarter = size / 4
				for q, offset in { Vector2.new(-1, -1), Vector2.new(1, -1), Vector2.new(-1, 1), Vector2.new(1, 1) } do
					if rng:NextNumber() < 0.8 then
						local w = rng:NextInteger(36, 62)
						local d = rng:NextInteger(36, 62)
						local h = rng:NextInteger(24, 110)
						local color = BUILDING_COLORS[rng:NextInteger(1, #BUILDING_COLORS)]
						add(slab(`Building_{bi}_{bj}_{q}`, "Buildings", cx + offset.X * quarter, cz + offset.Y * quarter, w, d, curb + h, h, color, Enum.Material.SmoothPlastic, true))
					end
				end
			end
		end
	end

	-- Highway north of the grid, joined by connector roads.
	local HZ = CityLayout.HIGHWAY_Z
	local HW = CityLayout.HIGHWAY_WIDTH
	local HL = CityLayout.HIGHWAY_HALF_LENGTH
	local P = CityLayout.END_PLAZA_SIZE
	local southEdge = HZ + HW / 2
	for _, x in CityLayout.CONNECTOR_XS do
		local length = -E - southEdge
		add(slab(`Connector_{x}`, "Roads", x, (southEdge - E) / 2, W, length, TOP, ROAD_THICKNESS, COLORS.Road, Enum.Material.Asphalt, true))
		add(slab(`LineConnector_{x}`, "Markings", x, (southEdge - E) / 2, 0.8, length, MARK_TOP, MARK_THICKNESS, COLORS.Yellow, Enum.Material.SmoothPlastic, false))
	end
	add(slab("Highway", "Highway", 0, HZ, 2 * HL, HW, TOP, ROAD_THICKNESS, COLORS.Road, Enum.Material.Asphalt, true))
	for _, side in { -1, 1 } do
		add(slab(`HighwayEnd_{side}`, "Highway", side * (HL + P / 2), HZ, P, P, TOP, ROAD_THICKNESS, COLORS.Plaza, Enum.Material.Concrete, true))
		add(slab(`HighwayEdge_{side}`, "Markings", 0, HZ + side * (HW / 2 - 1.5), 2 * HL, 0.6, MARK_TOP, MARK_THICKNESS, COLORS.White, Enum.Material.SmoothPlastic, false))
		local dash = 0
		local x = -HL + 15
		while x < HL - 15 do
			dash += 1
			add(slab(`LaneDash_{side}_{dash}`, "Markings", x, HZ + side * HW / 4, 12, 0.6, MARK_TOP, MARK_THICKNESS, COLORS.White, Enum.Material.SmoothPlastic, false))
			x += 30
		end
		-- End plaza walls (outer end, north, south).
		local inner, outer = side * HL, side * (HL + P)
		add(barrier(`PlazaWallEnd_{side}`, outer + side * 0.75, HZ - P / 2, outer + side * 0.75, HZ + P / 2, 1.5))
		add(barrier(`PlazaWallN_{side}`, inner, HZ - P / 2 - 0.75, outer, HZ - P / 2 - 0.75, 1.5))
		add(barrier(`PlazaWallS_{side}`, inner, HZ + P / 2 + 0.75, outer, HZ + P / 2 + 0.75, 1.5))
	end

	-- Highway barriers: full north wall, south wall and median with gaps at the connectors.
	local half = W / 2
	local southOpenings, medianOpenings = {}, {}
	for _, x in CityLayout.CONNECTOR_XS do
		table.insert(southOpenings, { x, half })
		table.insert(medianOpenings, { x, half + 2 })
	end
	add(barrier("HighwayWallN", -HL, HZ - HW / 2 - 0.75, HL, HZ - HW / 2 - 0.75, 1.5))
	for i, piece in withOpenings(-HL, HL, southOpenings) do
		add(barrier(`HighwayWallS_{i}`, piece[1], southEdge + 0.75, piece[2], southEdge + 0.75, 1.5))
	end
	for i, piece in withOpenings(-HL + 10, HL - 10, medianOpenings) do
		add(barrier(`HighwayMedian_{i}`, piece[1], HZ, piece[2], HZ, 1.2))
	end

	-- Vehicle spawns: four in the plaza facing north, one at each highway end facing inward.
	local function addSpawn(name: string, x: number, z: number, yaw: number)
		table.insert(spawns, { Name = name, CFrame = CFrame.new(x, TOP, z) * CFrame.Angles(0, yaw, 0) })
	end
	addSpawn("PlazaNW", -40, -45, 0)
	addSpawn("PlazaNE", 40, -45, 0)
	addSpawn("PlazaSW", -40, 45, 0)
	addSpawn("PlazaSE", 40, 45, 0)
	addSpawn("HighwayWest", -(HL + P / 2), HZ, -math.pi / 2)
	addSpawn("HighwayEast", HL + P / 2, HZ, math.pi / 2)

	-- Civilian character spawns around the plaza centre, clear of the vehicle pads.
	local civilianSpawns: { SpawnSpec } = {}
	for _, point in { { "North", 0, -20 }, { "South", 0, 20 }, { "West", -20, 0 }, { "East", 20, 0 }, { "FarWest", -65, 0 }, { "FarEast", 65, 0 } } do
		local name, x, z = point[1] :: string, point[2] :: number, point[3] :: number
		table.insert(civilianSpawns, { Name = `Civilian{name}`, CFrame = CFrame.new(x, TOP, z) })
	end

	return { Parts = parts, Spawns = spawns, CivilianSpawns = civilianSpawns }
end

return CityLayout
