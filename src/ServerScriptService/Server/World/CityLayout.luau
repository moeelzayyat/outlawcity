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
	-- Optional: collision physics as if made of this material (keeps the feel when only the look changes).
	PhysicsMaterial: Enum.Material?,
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
-- The original building colours. No longer drawn, but their count still sets the range of the
-- seeded colour roll, so the RNG call sequence (and therefore every building's size) is unchanged.
local BUILDING_COLORS = {
	Color3.fromRGB(120, 110, 100),
	Color3.fromRGB(90, 100, 115),
	Color3.fromRGB(150, 130, 105),
	Color3.fromRGB(105, 85, 80),
	Color3.fromRGB(175, 170, 160),
}
-- World polish Batch 1 (N1): one look per block column, built-in materials only. West (column 1,
-- the 24/7 MART side) "Old Town" brick, centre "Civic" stone, east (OUTLAW MOTORS side)
-- "Downtown" slate. Collision physics stays SmoothPlastic (PhysicsMaterial).
CityLayout.DISTRICTS = table.freeze({
	table.freeze({ Name = "Old Town", Material = Enum.Material.Brick, Colors = table.freeze({ Color3.fromRGB(140, 70, 55), Color3.fromRGB(120, 60, 50), Color3.fromRGB(155, 95, 70) }) }),
	table.freeze({ Name = "Civic", Material = Enum.Material.Concrete, Colors = table.freeze({ Color3.fromRGB(185, 180, 170), Color3.fromRGB(165, 160, 150), Color3.fromRGB(200, 195, 185) }) }),
	table.freeze({ Name = "Downtown", Material = Enum.Material.Slate, Colors = table.freeze({ Color3.fromRGB(85, 95, 110), Color3.fromRGB(70, 80, 95), Color3.fromRGB(100, 110, 125) }) }),
})
-- World polish Batch 1 (N3): the one approved geometry exception. Building_3_3_1 ran 0.5 stud into
-- OUTLAW MOTORS' west wall; its east edge moves in by 2.5 studs (west edge unchanged), leaving a
-- 2-stud gap. Every other building keeps its exact generated geometry.
CityLayout.BUILDING_EAST_INSET = table.freeze({ Building_3_3_1 = 2.5 })

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

CityLayout.STOP_LINE_GAP = 2 -- studs between the stop line and the intersection square
CityLayout.STOP_LINE_DEPTH = 1.2 -- along the road
CityLayout.STOP_LINE_INNER = 0.6 -- clearance from the centre of the road (the yellow line is 0.8 wide)
CityLayout.STOP_LINE_CURB = 1 -- clearance from the curb

export type StopLineArm = { Name: string, Center: Vector3, SizeX: number, SizeZ: number, Side: string, X: number, Z: number }

-- The road arms entering each grid intersection: north (-Z), south (+Z), west (-X), east (+X).
-- An arm exists where a road continues past the intersection square: inside the grid, plus the
-- connector roads north of the z = -300 line. The connector-highway joins are not included.
function CityLayout.stopLineApproaches(): { StopLineArm }
	local half = CityLayout.ROAD_WIDTH / 2
	local lines = CityLayout.GRID_LINES
	local first, last = lines[1], lines[#lines]
	local offset = half + CityLayout.STOP_LINE_GAP + CityLayout.STOP_LINE_DEPTH / 2
	local across = half - CityLayout.STOP_LINE_INNER - CityLayout.STOP_LINE_CURB
	local lateral = CityLayout.STOP_LINE_INNER + across / 2
	local arms = {}
	for _, X in lines do
		for _, Z in lines do
			local function arm(side: string, dx: number, dz: number, sizeX: number, sizeZ: number)
				table.insert(arms, { Name = `StopLine_{X}_{Z}_{side}`, Center = Vector3.new(X + dx, 0, Z + dz), SizeX = sizeX, SizeZ = sizeZ, Side = side, X = X, Z = Z })
			end
			-- Right-hand traffic: a car heading +Z keeps to -X, heading -Z to +X, heading +X to +Z,
			-- heading -X to -Z (Roblox right vectors).
			if Z > first or table.find(CityLayout.CONNECTOR_XS, X) then
				arm("N", -lateral, -offset, across, CityLayout.STOP_LINE_DEPTH) -- arriving northbound side, heading +Z
			end
			if Z < last then
				arm("S", lateral, offset, across, CityLayout.STOP_LINE_DEPTH) -- heading -Z
			end
			if X > first then
				arm("W", -offset, lateral, CityLayout.STOP_LINE_DEPTH, across) -- heading +X
			end
			if X < last then
				arm("E", offset, -lateral, CityLayout.STOP_LINE_DEPTH, across) -- heading -X
			end
		end
	end
	return arms
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

-- Convenience store (Phase 4B): one robbable building on the east edge of block (-200, 0),
-- facing the x = -100 road, on a site checked free of buildings. Depth runs along X, the
-- open front faces +X. The holdout area is the interior; the register sits at the back.
CityLayout.STORE_ID = "Store1"
CityLayout.STORE_CENTER = Vector3.new(-132, 0, -60)
CityLayout.STORE_DEPTH = 24 -- along X
CityLayout.STORE_WIDTH = 30 -- along Z
CityLayout.STORE_HEIGHT = 12

export type StoreSpec = {
	Id: string,
	Parts: { PartSpec },
	Register: CFrame, -- top centre of the counter, where the prompt lives
	Area: { Center: Vector3, Size: Vector3 }, -- holdout box (interior plus the doorway)
	Sign: { Center: Vector3, Size: Vector3 },
}

function CityLayout.store(): StoreSpec
	local c = CityLayout.STORE_CENTER
	local hx = CityLayout.STORE_DEPTH / 2
	local hz = CityLayout.STORE_WIDTH / 2
	local h = CityLayout.STORE_HEIGHT
	local floorTop = CityLayout.CURB_TOP + 0.2
	local wallColor = Color3.fromRGB(205, 190, 160)
	local trim = Color3.fromRGB(40, 120, 70)
	local parts: { PartSpec } = {}
	local function add(name: string, x: number, z: number, sizeX: number, sizeZ: number, partTop: number, thickness: number, color: Color3, material: Enum.Material, canCollide: boolean?)
		table.insert(parts, slab(name, "Store", c.X + x, c.Z + z, sizeX, sizeZ, partTop, thickness, color, material, canCollide ~= false))
	end
	add("StoreFloor", 0, 0, 2 * hx, 2 * hz, floorTop, 0.4, Color3.fromRGB(215, 215, 205), Enum.Material.SmoothPlastic)
	add("StoreRoof", 0, 0, 2 * hx + 2, 2 * hz + 2, floorTop + h + 1, 1, trim, Enum.Material.Concrete)
	add("StoreWallBack", -hx - 0.5, 0, 1, 2 * hz + 2, floorTop + h, h, wallColor, Enum.Material.Brick)
	add("StoreWallNorth", 0, -hz - 0.5, 2 * hx, 1, floorTop + h, h, wallColor, Enum.Material.Brick)
	add("StoreWallSouth", 0, hz + 0.5, 2 * hx, 1, floorTop + h, h, wallColor, Enum.Material.Brick)
	-- Front: glass panes either side of a 10-stud doorway, and a header above it.
	local pane = hz - 5
	add("StoreFrontNorth", hx + 0.5, -hz + pane / 2, 1, pane, floorTop + h, h, Color3.fromRGB(150, 200, 220), Enum.Material.Glass)
	add("StoreFrontSouth", hx + 0.5, hz - pane / 2, 1, pane, floorTop + h, h, Color3.fromRGB(150, 200, 220), Enum.Material.Glass)
	add("StoreFrontHeader", hx + 0.5, 0, 1, 10, floorTop + h, 3, wallColor, Enum.Material.Brick)
	-- Counter with the register, and two shelves.
	add("StoreCounter", -hx + 5, 0, 3, 10, floorTop + 3.5, 3.5, Color3.fromRGB(120, 80, 50), Enum.Material.Wood)
	add("StoreRegister", -hx + 5, 2, 1.6, 1.6, floorTop + 4.6, 1.1, Color3.fromRGB(30, 30, 35), Enum.Material.SmoothPlastic)
	add("StoreShelfNorth", 2, -hz + 4, 10, 2, floorTop + 6, 6, Color3.fromRGB(70, 90, 160), Enum.Material.SmoothPlastic)
	add("StoreShelfSouth", 2, hz - 4, 10, 2, floorTop + 6, 6, Color3.fromRGB(160, 70, 60), Enum.Material.SmoothPlastic)
	return {
		Id = CityLayout.STORE_ID,
		Parts = parts,
		Register = CFrame.new(c.X - hx + 5, floorTop + 4.6, c.Z + 2),
		Area = { Center = Vector3.new(c.X + 0.5, floorTop + h / 2, c.Z), Size = Vector3.new(2 * hx + 3, h + 4, 2 * hz) },
		Sign = { Center = Vector3.new(c.X + hx + 1.2, floorTop + h + 2.5, c.Z), Size = Vector3.new(0.4, 4, 20) },
	}
end

-- Car dealership (Phase 4C): one showroom on the north edge of block (200, 200), facing the
-- z = 100 road, on a site checked free of buildings. Width runs along X; the open front
-- faces -Z. A sales desk with the shop prompt, and one display car on the floor.
CityLayout.DEALERSHIP_CENTER = Vector3.new(200, 0, 136)
CityLayout.DEALERSHIP_WIDTH = 40 -- along X
CityLayout.DEALERSHIP_DEPTH = 30 -- along Z
CityLayout.DEALERSHIP_HEIGHT = 14

export type DealershipSpec = {
	Parts: { PartSpec },
	Desk: CFrame, -- top centre of the sales desk, where the prompt lives
	Display: CFrame, -- where the display car stands (wheels on the floor)
	Sign: { Center: Vector3, Size: Vector3 },
}

function CityLayout.dealership(): DealershipSpec
	local c = CityLayout.DEALERSHIP_CENTER
	local hx = CityLayout.DEALERSHIP_WIDTH / 2
	local hz = CityLayout.DEALERSHIP_DEPTH / 2
	local h = CityLayout.DEALERSHIP_HEIGHT
	local floorTop = CityLayout.CURB_TOP + 0.2
	local wallColor = Color3.fromRGB(230, 232, 236)
	local trim = Color3.fromRGB(30, 60, 120)
	local glass = Color3.fromRGB(150, 200, 220)
	local parts: { PartSpec } = {}
	local function add(name: string, x: number, z: number, sizeX: number, sizeZ: number, partTop: number, thickness: number, color: Color3, material: Enum.Material)
		table.insert(parts, slab(name, "Dealership", c.X + x, c.Z + z, sizeX, sizeZ, partTop, thickness, color, material, true))
	end
	add("DealerFloor", 0, 0, 2 * hx, 2 * hz, floorTop, 0.4, Color3.fromRGB(200, 200, 205), Enum.Material.Marble)
	add("DealerRoof", 0, 0, 2 * hx + 2, 2 * hz + 2, floorTop + h + 1, 1, trim, Enum.Material.Concrete)
	add("DealerWallBack", 0, hz + 0.5, 2 * hx + 2, 1, floorTop + h, h, wallColor, Enum.Material.Concrete)
	add("DealerWallWest", -hx - 0.5, 0, 1, 2 * hz, floorTop + h, h, wallColor, Enum.Material.Concrete)
	add("DealerWallEast", hx + 0.5, 0, 1, 2 * hz, floorTop + h, h, wallColor, Enum.Material.Concrete)
	-- Front (-Z): glass either side of a 14-stud doorway, header above it.
	local pane = hx - 7
	add("DealerFrontWest", -hx + pane / 2, -hz - 0.5, pane, 1, floorTop + h, h, glass, Enum.Material.Glass)
	add("DealerFrontEast", hx - pane / 2, -hz - 0.5, pane, 1, floorTop + h, h, glass, Enum.Material.Glass)
	add("DealerFrontHeader", 0, -hz - 0.5, 14, 1, floorTop + h, 4, wallColor, Enum.Material.Concrete)
	add("DealerDesk", -hx + 8, hz - 6, 8, 3, floorTop + 3.5, 3.5, Color3.fromRGB(60, 60, 70), Enum.Material.SmoothPlastic)
	return {
		Parts = parts,
		Desk = CFrame.new(c.X - hx + 8, floorTop + 3.5, c.Z + hz - 6),
		Display = CFrame.new(c.X + 6, floorTop, c.Z + 2) * CFrame.Angles(0, math.rad(-35), 0),
		Sign = { Center = Vector3.new(c.X, floorTop + h + 3, c.Z - hz - 1.2), Size = Vector3.new(24, 4, 0.4) },
	}
end

-- Street-name signs (N4). Plain names are approved for the one-sign prototype only; a
-- full-city rollout needs its own approval. East-west streets count from the highway side.
CityLayout.STREET_NAMES_EW = table.freeze({ [-300] = "1st St", [-100] = "2nd St", [100] = "3rd St", [300] = "4th St" })
CityLayout.STREET_NAMES_NS = table.freeze({ [-300] = "A Ave", [-100] = "B Ave", [100] = "C Ave", [300] = "D Ave" })
-- Junction and sidewalk-corner offset of every sign: the approved prototype at (100, 100), then
-- Stage A (the rest of the plaza ring). Each corner puts the sign's one weak approach on the grid
-- edge side (docs/N4_STREET_SIGN_ROLLOUT_PLAN.md).
CityLayout.STREET_SIGNS = table.freeze({
	{ X = 100, Z = 100, CornerX = 22, CornerZ = 22 },
	{ X = -100, Z = -100, CornerX = -22, CornerZ = -22 },
	{ X = 100, Z = -100, CornerX = 22, CornerZ = 22 },
	{ X = -100, Z = 100, CornerX = -22, CornerZ = -22 },
})
CityLayout.STREET_SIGN_POST = Vector3.new(0.4, 10.4, 0.4)
CityLayout.STREET_SIGN_BLADE_LENGTH = 7
CityLayout.STREET_SIGN_BLADE_HEIGHT = 1.5
CityLayout.STREET_SIGN_BLADE_THICKNESS = 0.2
CityLayout.STREET_SIGN_EW_Y = 8.6 -- centre height of the blade naming the east-west street
CityLayout.STREET_SIGN_NS_Y = 10.2 -- centre height of the blade naming the north-south street

export type StreetSignLabel = { Part: string, Text: string, Faces: { Enum.NormalId } }
export type StreetSignSpec = { Name: string, X: number, Z: number, Parts: { PartSpec }, Labels: { StreetSignLabel } }

-- One post and two perpendicular blades on a sidewalk corner. Each blade runs along the street
-- it names and carries the name on both faces, so drivers read it from both directions. The
-- blades are cantilevered: each starts at a post face and extends away from the junction, so the
-- post never covers the text. All parts are visual only (CityBuilder.buildStreetSigns turns off
-- collision, query, touch, shadow).
function CityLayout.streetSigns(): { StreetSignSpec }
	local result = {}
	local post = CityLayout.STREET_SIGN_POST
	local length, height, thick = CityLayout.STREET_SIGN_BLADE_LENGTH, CityLayout.STREET_SIGN_BLADE_HEIGHT, CityLayout.STREET_SIGN_BLADE_THICKNESS
	local postColor, bladeColor = Color3.fromRGB(110, 110, 110), Color3.fromRGB(0, 102, 51)
	for _, sign in CityLayout.STREET_SIGNS do
		local x, z = sign.X + sign.CornerX, sign.Z + sign.CornerZ
		-- Away from the junction (towards the inside of the block).
		local reachX = math.sign(sign.CornerX) * (post.X / 2 + length / 2)
		local reachZ = math.sign(sign.CornerZ) * (post.Z / 2 + length / 2)
		local function part(name: string, px: number, y: number, pz: number, size: Vector3, color: Color3): PartSpec
			return { Name = name, Group = "StreetSigns", Center = Vector3.new(px, y, pz), Size = size, Color = color, Material = Enum.Material.SmoothPlastic, CanCollide = false }
		end
		table.insert(result, {
			Name = `StreetSign_{sign.X}_{sign.Z}`,
			X = sign.X,
			Z = sign.Z,
			Parts = {
				part("Post", x, CityLayout.CURB_TOP + post.Y / 2, z, post, postColor),
				part("Blade_EW", x + reachX, CityLayout.STREET_SIGN_EW_Y, z, Vector3.new(length, height, thick), bladeColor),
				part("Blade_NS", x, CityLayout.STREET_SIGN_NS_Y, z + reachZ, Vector3.new(thick, height, length), bladeColor),
			},
			Labels = {
				{ Part = "Blade_EW", Text = CityLayout.STREET_NAMES_EW[sign.Z], Faces = { Enum.NormalId.Front, Enum.NormalId.Back } },
				{ Part = "Blade_NS", Text = CityLayout.STREET_NAMES_NS[sign.X], Faces = { Enum.NormalId.Right, Enum.NormalId.Left } },
			},
		})
	end
	return result
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

	-- Stop lines (N5, stop-line Batch 1): one per road arm entering a grid intersection, 2 studs
	-- before the 36x36 intersection square, across the incoming half of the arm only (right-hand
	-- traffic), from 0.6 studs off the centre line to 1 stud inside the curb. Visual only: built
	-- non-colliding (CityBuilder then also turns off query, touch and shadow).
	for _, arm in CityLayout.stopLineApproaches() do
		add(slab(arm.Name, "Markings", arm.Center.X, arm.Center.Z, arm.SizeX, arm.SizeZ, MARK_TOP, MARK_THICKNESS, COLORS.White, Enum.Material.SmoothPlastic, false))
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
						local roll = rng:NextInteger(1, #BUILDING_COLORS) -- kept: preserves the RNG sequence
						local district = CityLayout.DISTRICTS[bi]
						local color = district.Colors[(roll - 1) % #district.Colors + 1]
						local name = `Building_{bi}_{bj}_{q}`
						local inset = CityLayout.BUILDING_EAST_INSET[name] or 0
						local spec = slab(name, "Buildings", cx + offset.X * quarter - inset / 2, cz + offset.Y * quarter, w - inset, d, curb + h, h, color, district.Material, true)
						spec.PhysicsMaterial = Enum.Material.SmoothPlastic
						add(spec)
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
