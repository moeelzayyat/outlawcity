local ServerScriptService = game:GetService("ServerScriptService")
local CityLayout = require(ServerScriptService.Server.World.CityLayout)
local Assert = require(script.Parent.Assert)

local blueprint = CityLayout.createBlueprint()

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
}
