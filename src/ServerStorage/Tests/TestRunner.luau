--!strict
-- Runs every ModuleScript named "*.spec" in a folder. Each spec returns { [testName]: () -> () }.
-- Prints one line per failure and a summary line: "[Tests] N passed, M failed".
local TestRunner = {}

export type Result = { passed: number, failed: number, failures: { string } }

function TestRunner.run(folder: Instance): Result
	local result: Result = { passed = 0, failed = 0, failures = {} }
	local specs = {}
	for _, child in folder:GetChildren() do
		if child:IsA("ModuleScript") and child.Name:match("%.spec$") then
			table.insert(specs, child)
		end
	end
	table.sort(specs, function(a, b)
		return a.Name < b.Name
	end)
	for _, spec in specs do
		local loaded, suite = pcall(require, spec)
		if not loaded then
			result.failed += 1
			table.insert(result.failures, `{spec.Name}: failed to load: {suite}`)
			continue
		end
		local names = {}
		for name in suite do
			table.insert(names, name)
		end
		table.sort(names)
		for _, name in names do
			local ok, err = pcall(suite[name])
			if ok then
				result.passed += 1
			else
				result.failed += 1
				table.insert(result.failures, `{spec.Name} > {name}: {err}`)
			end
		end
	end
	for _, failure in result.failures do
		warn(`[Tests] FAIL {failure}`)
	end
	print(`[Tests] {result.passed} passed, {result.failed} failed`)
	return result
end

return TestRunner
