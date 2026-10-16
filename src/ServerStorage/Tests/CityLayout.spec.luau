local ServerScriptService = game:GetService("ServerScriptService")
local CityLayout = require(ServerScriptService.Server.World.CityLayout)
local Assert = require(script.Parent.Assert)

local blueprint = CityLayout.createBlueprint()

-- Recorded from the place before World Polish Batch 1 (blueprint signature 8b66ade9 over 186 parts; see docs/audits/2026-10-15_world-polish-batch1).
local BASELINE_ROWS = 186
local BASELINE_GEOMETRY_HASH = "8b66ade9"
local BASELINE_3_3_1_HEIGHT = 46

local function rect(spec)
	local c, s = spec.Center, spec.Size
	return c.X - s.X / 2, c.X + s.X / 2, c.Z - s.Z / 2, c.Z + s.Z / 2
end

local function onDrivable(x: number, z: number): boolean
	for _, spec in blueprint.Parts do
		if spec.Group == "Roads" or spec.Group == "Plaza" or spec.Group == "Highway" then
			local x1, x2, z1, z2 = rect(spec)
			if x >= x1 and x <= x2 and z >= z1 and z <= z2 then
				return true
			end
		end
	end
	return false
end

return {
	["parts have positive sizes and unique names"] = function()
		local seen = {}
		for _, spec in blueprint.Parts do
			Assert.truthy(spec.Size.X > 0 and spec.Size.Y > 0 and spec.Size.Z > 0, `{spec.Name} size`)
			Assert.truthy(not seen[spec.Name], `duplicate name {spec.Name}`)
			seen[spec.Name] = true
		end
	end,
	["drivable surfaces never overlap"] = function()
		local surfaces = {}
		for _, spec in blueprint.Parts do
			if spec.Group == "Roads" or spec.Group == "Plaza" or spec.Group == "Highway" then
				table.insert(surfaces, spec)
			end
		end
		for i = 1, #surfaces do
			local ax1, ax2, az1, az2 = rect(surfaces[i])
			for j = i + 1, #surfaces do
				local bx1, bx2, bz1, bz2 = rect(surfaces[j])
				local overlapX = math.min(ax2, bx2) - math.max(ax1, bx1)
				local overlapZ = math.min(az2, bz2) - math.max(az1, bz1)
				Assert.truthy(overlapX <= 1e-6 or overlapZ <= 1e-6, `{surfaces[i].Name} overlaps {surfaces[j].Name}`)
			end
		end
	end,
	["every spawn sits on a drivable surface"] = function()
		Assert.truthy(#blueprint.Spawns >= 4, "enough spawns")
		for _, spawn in blueprint.Spawns do
			local p = spawn.CFrame.Position
			Assert.truthy(onDrivable(p.X, p.Z), `{spawn.Name} is off-road`)
			Assert.near(p.Y, CityLayout.ROAD_TOP, 1e-6, `{spawn.Name} height`)
		end
	end,
	["connectors link the grid to the highway"] = function()
		local southEdge = CityLayout.HIGHWAY_Z + CityLayout.HIGHWAY_WIDTH / 2
		for _, x in CityLayout.CONNECTOR_XS do
			Assert.truthy(onDrivable(x, southEdge + 1), `connector {x} near highway`)
			Assert.truthy(onDrivable(x, -CityLayout.GRID_EXTENT - 1), `connector {x} near grid`)
			Assert.truthy(onDrivable(x, southEdge - 1), `highway above connector {x}`)
		end
	end,
	["grid is fully connected along every line"] = function()
		local E = CityLayout.GRID_EXTENT
		for _, line in CityLayout.GRID_LINES do
			for t = -E + 1, E - 1, 4 do
				Assert.truthy(onDrivable(t, line), `gap on east-west road {line} at x={t}`)
				Assert.truthy(onDrivable(line, t), `gap on north-south road {line} at z={t}`)
			end
		end
	end,
	["civilian spawns are in the plaza, apart, and clear of vehicle pads"] = function()
		local spawns = blueprint.CivilianSpawns
		Assert.truthy(#spawns >= 4, "enough civilian spawns")
		local plazaHalf = (CityLayout.GRID_LINES[3] - CityLayout.GRID_LINES[2] - CityLayout.ROAD_WIDTH) / 2
		for i, spawn in spawns do
			local p = spawn.CFrame.Position
			Assert.truthy(math.abs(p.X) < plazaHalf - 4 and math.abs(p.Z) < plazaHalf - 4, `{spawn.Name} outside plaza`)
			for j = i + 1, #spawns do
				Assert.truthy((spawns[j].CFrame.Position - p).Magnitude >= 15, `{spawn.Name} too close to {spawns[j].Name}`)
			end
			for _, pad in blueprint.Spawns do
				Assert.truthy((pad.CFrame.Position - p).Magnitude >= 20, `{spawn.Name} too close to pad {pad.Name}`)
			end
		end
	end,
	["world polish: every generated part keeps its baseline geometry except Building_3_3_1"] = function()
		-- Signature of all generated parts (name, group, centre, size, collision) except the one
		-- approved exception, recorded from the place before World Polish Batch 1. The stop lines
		-- (stop-line Batch 1) are new parts and are checked by their own tests below.
		local rows = {}
		for _, spec in blueprint.Parts do
			if spec.Name ~= "Building_3_3_1" and spec.Name:sub(1, 9) ~= "StopLine_" then
				table.insert(rows, string.format("%s|%s|%.3f,%.3f,%.3f|%.3f,%.3f,%.3f|%s", spec.Name, spec.Group, spec.Center.X, spec.Center.Y, spec.Center.Z, spec.Size.X, spec.Size.Y, spec.Size.Z, tostring(spec.CanCollide)))
			end
		end
		table.sort(rows)
		local text = table.concat(rows, "\n")
		local h = 2166136261
		for i = 1, #text do
			h = bit32.bxor(h, string.byte(text, i))
			local lo = bit32.band(h, 0xFFFF) * 16777619
			local hi = bit32.rshift(h, 16) * 16777619
			h = bit32.band(lo + bit32.lshift(bit32.band(hi, 0xFFFF), 16), 0xFFFFFFFF)
		end
		Assert.equal(#rows, BASELINE_ROWS, "part count without the exception")
		Assert.equal(string.format("%08x", h), BASELINE_GEOMETRY_HASH, "generated geometry changed")
	end,
	["world polish: Building_3_3_1 keeps its west edge and clears the dealership by at least 1 stud"] = function()
		local building
		local count = 0
		for _, spec in blueprint.Parts do
			if spec.Group == "Buildings" then
				count += 1
			end
			if spec.Name == "Building_3_3_1" then
				building = spec
			end
		end
		Assert.equal(count, 24, "no buildings added or removed")
		Assert.truthy(building ~= nil, "Building_3_3_1 exists")
		local x1, x2, z1, z2 = rect(building)
		Assert.equal(x1, 138.5, "west edge unchanged")
		Assert.equal(x2, 177, "east edge moved in by 2.5")
		Assert.equal(building.Size.Y, BASELINE_3_3_1_HEIGHT, "height unchanged")
		for _, part in CityLayout.dealership().Parts do
			local dx1, dx2, dz1, dz2 = rect(part)
			local gapX = math.max(dx1 - x2, x1 - dx2)
			local gapZ = math.max(dz1 - z2, z1 - dz2)
			Assert.truthy(math.max(gapX, gapZ) >= 1, `{part.Name} within 1 stud of Building_3_3_1`)
		end
	end,
	["world polish: districts by column, built-in materials, collision physics unchanged"] = function()
		for _, spec in blueprint.Parts do
			if spec.Group == "Buildings" then
				local column = tonumber(spec.Name:match("^Building_(%d)_"))
				local district = CityLayout.DISTRICTS[column]
				Assert.equal(spec.Material, district.Material, spec.Name)
				Assert.truthy(table.find(district.Colors, spec.Color) ~= nil, `{spec.Name} colour`)
				Assert.equal(spec.PhysicsMaterial, Enum.Material.SmoothPlastic, `{spec.Name} physics`)
				Assert.truthy(spec.Material ~= Enum.Material.Glass, "no glass")
			end
		end
	end,
	["stop lines: exactly 50, one per approach (6 four-arm, 6 three-arm, 4 two-arm intersections)"] = function()
		local lines, names, perIntersection = {}, {}, {}
		for _, spec in blueprint.Parts do
			if spec.Name:sub(1, 9) == "StopLine_" then
				table.insert(lines, spec)
				Assert.truthy(not names[spec.Name], `duplicate {spec.Name}`)
				names[spec.Name] = true
				local x, z = spec.Name:match("^StopLine_(%-?%d+)_(%-?%d+)_")
				local key = `{x},{z}`
				perIntersection[key] = (perIntersection[key] or 0) + 1
			end
		end
		Assert.equal(#lines, 50)
		local histogram = { [2] = 0, [3] = 0, [4] = 0 }
		for _, n in perIntersection do
			histogram[n] += 1
		end
		Assert.equal(histogram[4], 6)
		Assert.equal(histogram[3], 6)
		Assert.equal(histogram[2], 4)
	end,
	["stop lines: on the road, incoming half, 2 studs before the square, clear of centre lines"] = function()
		local function inside(a, b) -- rect a fully inside rect b
			local ax1, ax2, az1, az2 = rect(a)
			local bx1, bx2, bz1, bz2 = rect(b)
			return ax1 >= bx1 - 1e-4 and ax2 <= bx2 + 1e-4 and az1 >= bz1 - 1e-4 and az2 <= bz2 + 1e-4
		end
		local function overlaps(a, b)
			local ax1, ax2, az1, az2 = rect(a)
			local bx1, bx2, bz1, bz2 = rect(b)
			return ax1 < bx2 and bx1 < ax2 and az1 < bz2 and bz1 < az2
		end
		local half = CityLayout.ROAD_WIDTH / 2
		for _, arm in CityLayout.stopLineApproaches() do
			local spec
			for _, s in blueprint.Parts do
				if s.Name == arm.Name then
					spec = s
				end
			end
			Assert.truthy(spec ~= nil, arm.Name)
			Assert.near(spec.Center.Y + spec.Size.Y / 2, 0.25, 1e-4, `{arm.Name} top`)
			Assert.near(spec.Size.Y, 0.05, 1e-4, `{arm.Name} thickness`)
			Assert.near(math.max(spec.Size.X, spec.Size.Z), 16.4, 1e-4, `{arm.Name} length`) -- Vector3 is single precision
			Assert.near(math.min(spec.Size.X, spec.Size.Z), 1.2, 1e-4, `{arm.Name} depth`)
			Assert.equal(spec.CanCollide, false)
			Assert.equal(spec.Color, Color3.fromRGB(235, 235, 235))
			Assert.equal(spec.Material, Enum.Material.SmoothPlastic)
			local onRoad = false
			for _, r in blueprint.Parts do
				if r.Group == "Roads" and inside(spec, r) then
					onRoad = true
				end
			end
			Assert.truthy(onRoad, `{arm.Name} not fully on one road part`)
			for _, m in blueprint.Parts do
				if m.Name:match("^Line") then
					Assert.truthy(not overlaps(spec, m), `{arm.Name} overlaps {m.Name}`)
				end
			end
			-- 2 studs before the square, on the incoming (right-hand) half
			local dx, dz = spec.Center.X - arm.X, spec.Center.Z - arm.Z
			local near = half + 2
			if arm.Side == "N" then
				Assert.near(dz + 0.6, -near, 1e-4, arm.Name)
				Assert.truthy(dx < 0, `{arm.Name} wrong half`)
			elseif arm.Side == "S" then
				Assert.near(dz - 0.6, near, 1e-4, arm.Name)
				Assert.truthy(dx > 0, `{arm.Name} wrong half`)
			elseif arm.Side == "W" then
				Assert.near(dx + 0.6, -near, 1e-4, arm.Name)
				Assert.truthy(dz > 0, `{arm.Name} wrong half`)
			else
				Assert.near(dx - 0.6, near, 1e-4, arm.Name)
				Assert.truthy(dz < 0, `{arm.Name} wrong half`)
			end
		end
	end,
	["street signs: exactly four signs (prototype + Stage A), each 3 parts and 4 labels"] = function()
		local signs = CityLayout.streetSigns()
		Assert.equal(#signs, 4)
		Assert.equal(signs[1].Name, "StreetSign_100_100", "the approved prototype stays first")
		local expected = { StreetSign_100_100 = true, ["StreetSign_-100_-100"] = true, ["StreetSign_100_-100"] = true, ["StreetSign_-100_100"] = true }
		local seen = {}
		for _, sign in signs do
			Assert.truthy(expected[sign.Name], `unexpected sign {sign.Name}`)
			Assert.truthy(not seen[sign.Name], `duplicate sign {sign.Name}`)
			seen[sign.Name] = true
			Assert.equal(#sign.Parts, 3)
			local names = {}
			for _, part in sign.Parts do
				names[part.Name] = true
				Assert.equal(part.CanCollide, false, `{sign.Name} {part.Name} collides`)
				Assert.equal(part.Material, Enum.Material.SmoothPlastic)
			end
			Assert.truthy(names.Post and names.Blade_EW and names.Blade_NS, `{sign.Name} part names`)
			local faces = 0
			for _, label in sign.Labels do
				faces += #label.Faces
			end
			Assert.equal(faces, 4)
		end
	end,
	["street signs: sizes, heights, orientation and plain names"] = function()
		for _, sign in CityLayout.streetSigns() do
			local parts = {}
			for _, part in sign.Parts do
				parts[part.Name] = part
			end
			local post, ew, ns = parts.Post, parts.Blade_EW, parts.Blade_NS
			Assert.near(post.Size.X, 0.4, 1e-4, "post width")
			Assert.near(post.Size.Y, 10.4, 1e-4, "post height")
			Assert.near(post.Center.Y - post.Size.Y / 2, CityLayout.CURB_TOP, 1e-4, "post stands on the sidewalk")
			-- Each blade runs along the street it names: EW along X (faces +-Z), NS along Z (faces +-X).
			Assert.near(ew.Size.X, 7, 1e-4, "EW length")
			Assert.near(ew.Size.Y, 1.5, 1e-4, "EW height")
			Assert.near(ew.Size.Z, 0.2, 1e-4, "EW thickness")
			Assert.near(ns.Size.Z, 7, 1e-4, "NS length")
			Assert.near(ns.Size.Y, 1.5, 1e-4, "NS height")
			Assert.near(ns.Size.X, 0.2, 1e-4, "NS thickness")
			Assert.near(ew.Center.Y, 8.6, 1e-4, "EW height")
			Assert.near(ns.Center.Y, 10.2, 1e-4, "NS height")
			Assert.truthy(ns.Center.Y - ns.Size.Y / 2 > ew.Center.Y + ew.Size.Y / 2, "blades don't intersect")
			Assert.truthy(ns.Center.Y + ns.Size.Y / 2 <= post.Center.Y + post.Size.Y / 2 + 1e-4, "post reaches the top blade")
			for _, label in sign.Labels do
				if label.Part == "Blade_EW" then
					Assert.equal(label.Text, CityLayout.STREET_NAMES_EW[sign.Z], `{sign.Name} EW name`)
					Assert.truthy(table.find(label.Faces, Enum.NormalId.Front) and table.find(label.Faces, Enum.NormalId.Back), "EW faces")
				else
					Assert.equal(label.Part, "Blade_NS")
					Assert.equal(label.Text, CityLayout.STREET_NAMES_NS[sign.X], `{sign.Name} NS name`)
					Assert.truthy(table.find(label.Faces, Enum.NormalId.Right) and table.find(label.Faces, Enum.NormalId.Left), "NS faces")
				end
			end
		end
	end,
	["street signs: exact posts and names (prototype unchanged, Stage A as approved)"] = function()
		local want = {
			StreetSign_100_100 = { 122, 122, "3rd St", "C Ave" },
			["StreetSign_-100_-100"] = { -122, -122, "2nd St", "B Ave" },
			["StreetSign_100_-100"] = { 122, -78, "2nd St", "C Ave" },
			["StreetSign_-100_100"] = { -122, 78, "3rd St", "B Ave" },
		}
		for _, sign in CityLayout.streetSigns() do
			local w = want[sign.Name]
			Assert.truthy(w ~= nil, sign.Name)
			Assert.near(sign.Parts[1].Center.X, w[1], 1e-4, `{sign.Name} post x`)
			Assert.near(sign.Parts[1].Center.Z, w[2], 1e-4, `{sign.Name} post z`)
			for _, label in sign.Labels do
				Assert.equal(label.Text, if label.Part == "Blade_EW" then w[3] else w[4], `{sign.Name} {label.Part}`)
			end
		end
	end,
	["street signs: full footprints on the sidewalk, clear of roads, markings, buildings and pads"] = function()
		local function inside(a, b)
			local ax1, ax2, az1, az2 = rect(a)
			local bx1, bx2, bz1, bz2 = rect(b)
			return ax1 >= bx1 - 1e-4 and ax2 <= bx2 + 1e-4 and az1 >= bz1 - 1e-4 and az2 <= bz2 + 1e-4
		end
		local function gap(a, b) -- horizontal gap between two footprints (negative or 0 = touching/overlap)
			local ax1, ax2, az1, az2 = rect(a)
			local bx1, bx2, bz1, bz2 = rect(b)
			local dx = math.max(bx1 - ax2, ax1 - bx2, 0)
			local dz = math.max(bz1 - az2, az1 - bz2, 0)
			if dx == 0 and dz == 0 then
				return -1
			end
			return math.sqrt(dx * dx + dz * dz)
		end
		local others = {}
		for _, spec in blueprint.Parts do
			table.insert(others, spec)
		end
		for _, spec in CityLayout.store().Parts do
			table.insert(others, spec)
		end
		for _, spec in CityLayout.dealership().Parts do
			table.insert(others, spec)
		end
		for _, sign in CityLayout.streetSigns() do
			for _, part in sign.Parts do
				local label = `{sign.Name} {part.Name}`
				local onSidewalk = false
				for _, spec in blueprint.Parts do
					if spec.Group == "Sidewalks" and inside(part, spec) then
						onSidewalk = true
					end
				end
				Assert.truthy(onSidewalk, `{label} footprint not fully on one sidewalk`)
				local nearestRoad = math.huge
				for _, spec in others do
					local g = gap(part, spec)
					if spec.Group == "Roads" or spec.Group == "Highway" or spec.Group == "Plaza" or spec.Group == "Markings" then
						Assert.truthy(g > 0, `{label} overlaps {spec.Name}`)
						if spec.Group == "Roads" then
							nearestRoad = math.min(nearestRoad, g)
						end
					elseif spec.Group == "Buildings" or spec.Group == "Store" or spec.Group == "Dealership" then
						Assert.truthy(g >= 3, `{label} within 3 studs of {spec.Name}`)
					end
				end
				-- Measured face to road edge: the post 3.8 studs, the cantilevered blades 3.9 studs.
				Assert.near(nearestRoad, if part.Name == "Post" then 3.8 else 3.9, 1e-4, `{label} distance to the nearest road edge`)
			end
			local post = sign.Parts[1]
			for _, spawn in blueprint.Spawns do
				local d = (Vector3.new(spawn.CFrame.X, 0, spawn.CFrame.Z) - Vector3.new(post.Center.X, 0, post.Center.Z)).Magnitude
				Assert.truthy(d >= 3 + 9, `{sign.Name} within reach of vehicle pad {spawn.Name}`) -- pad half-diagonal < 9
			end
		end
	end,
	["street signs: blades are cantilevered off the post, so the post covers no text"] = function()
		local function box(p)
			local c, s = p.Center, p.Size
			return c.X - s.X / 2, c.X + s.X / 2, c.Y - s.Y / 2, c.Y + s.Y / 2, c.Z - s.Z / 2, c.Z + s.Z / 2
		end
		local function sharedVolume(a, b)
			local ax1, ax2, ay1, ay2, az1, az2 = box(a)
			local bx1, bx2, by1, by2, bz1, bz2 = box(b)
			return math.max(0, math.min(ax2, bx2) - math.max(ax1, bx1)) * math.max(0, math.min(ay2, by2) - math.max(ay1, by1)) * math.max(0, math.min(az2, bz2) - math.max(az1, bz1))
		end
		for _, sign in CityLayout.streetSigns() do
			local parts = {}
			for _, part in sign.Parts do
				parts[part.Name] = part
			end
			local post, ew, ns = parts.Post, parts.Blade_EW, parts.Blade_NS
			Assert.near(sharedVolume(ew, post), 0, 1e-6, `{sign.Name} EW blade passes through the post`)
			Assert.near(sharedVolume(ns, post), 0, 1e-6, `{sign.Name} NS blade passes through the post`)
			Assert.near(sharedVolume(ew, ns), 0, 1e-6, `{sign.Name} blades intersect`)
			-- Each blade starts at the post face on the side away from the junction.
			local sx = math.sign(post.Center.X - sign.X)
			local sz = math.sign(post.Center.Z - sign.Z)
			local px1, px2, _, _, pz1, pz2 = box(post)
			local ex1, ex2, _, _, ez1, ez2 = box(ew)
			local nx1, nx2, _, _, nz1, nz2 = box(ns)
			Assert.near(if sx > 0 then ex1 else ex2, if sx > 0 then px2 else px1, 1e-4, `{sign.Name} EW blade starts at the post face away from the junction`)
			Assert.near(if sz > 0 then nz1 else nz2, if sz > 0 then pz2 else pz1, 1e-4, `{sign.Name} NS blade starts at the post face away from the junction`)
			Assert.truthy(ez1 >= pz1 - 1e-4 and ez2 <= pz2 + 1e-4, "EW blade stays within the post's depth")
			Assert.truthy(nx1 >= px1 - 1e-4 and nx2 <= px2 + 1e-4, "NS blade stays within the post's width")
			if sign.Name == "StreetSign_100_100" then
				-- The approved prototype is unchanged.
				Assert.near(ew.Center.X, 125.7, 1e-4, "EW centre x")
				Assert.near(ew.Center.Z, 122, 1e-4, "EW centre z")
				Assert.near(ns.Center.X, 122, 1e-4, "NS centre x")
				Assert.near(ns.Center.Z, 125.7, 1e-4, "NS centre z")
			end
		end
	end,
}
