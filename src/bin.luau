local lib = require("./lib")

local function printUnusedDependencies(deps: { string }, format: string)
	for _, name in deps do
		print(format:format(name))
	end
end

local unusedDeps = lib.scan(".")

if unusedDeps.count > 0 then
	print("unused dependencies:")
	printUnusedDependencies(unusedDeps.dependencies, "`%s`")
	printUnusedDependencies(unusedDeps.devDependencies, "`%s` (dev-dependency)")
else
	print("All deps seem to have been used.")
end
