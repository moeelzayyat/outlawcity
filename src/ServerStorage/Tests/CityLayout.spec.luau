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
		-- approved exception, recorded from the place before World Polish Batch 1.
		local rows = {}
		for _, spec in blueprint.Parts do
			if spec.Name ~= "Building_3_3_1" then
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
}
