local luaup = require("../luau_packages/luaup")
local pathfs = require("../lune_packages/pathfs")
local serde = require("@lune/serde")
local stdio = require("@lune/stdio")

local parse = luaup.parse
local visit = luaup.visit

local function checkUsed(state, identifier: string)
	if state.dependencies[identifier] ~= nil then
		state.dependencies[identifier] = true
	end
	if state.devDependencies[identifier] ~= nil then
		state.devDependencies[identifier] = true
	end
end

local pesdePackageFolder: {
	[string]: boolean
} = {
	roblox_packages = true,
	luau_packages = true,
	lune_packages = true
}

local visitor = visit.visitor()
visitor.visit_var = function(state, node)
	if node.root.kind == "name" then
		checkUsed(state, node.root.tok.text)
	end
	local lastSecondSuffix = node.suffixes[#node.suffixes - 1]
	if lastSecondSuffix then
		if lastSecondSuffix.kind == "nameindex" then
			local name = lastSecondSuffix.name.text
			if pesdePackageFolder[name] then
				local lastSuffix = node.suffixes[#node.suffixes]
				if lastSuffix then
					if lastSuffix.kind == "nameindex" then
						checkUsed(state, lastSuffix.name.text)
					end
				end
			end
		end
	end
end

local function scan(state, dirPath: pathfs.AsPath)
	for _, path in pathfs.readDir(dirPath) do
		path = pathfs.getNoCurDirPathOf(pathfs.Path.from(dirPath):join(path))

		local isPesdePackageFolder = false
		for folderName in pesdePackageFolder do
			if path:equal(pathfs.Path.from(folderName)) then
				isPesdePackageFolder = true
				break
			end
		end
		if isPesdePackageFolder then
			continue
		end

		if path:equal(pathfs.Path.from("lune_packages")) then
			continue
		end
		if path:equal(pathfs.Path.from("roblox_packages")) then
			continue
		end
		if pathfs.isDir(path) then
			scan(state, path)
		elseif pathfs.isFile(path) then
			if path:extension() == "luau" or path:extension() == "lua" then
				local parsed = parse(pathfs.readFile(path))
				if parsed.success then
					visit.visit(visitor, state, parsed.cst)
				else
					stdio.write(stdio.color("yellow"))
					print(`WARNING: Skipped a lua file '{path}' due to unable to be parsed. ({parsed.error.message})`)
					stdio.write(stdio.color("reset"))
				end
			end
		end
	end
end

local function scanRoot(
	rootPath: pathfs.AsPath
): { count: number, dependencies: { string }, devDependencies: { string } }
	local state = {
		dependencies = {},
		devDependencies = {},
	}

	local pesde = serde.decode("toml", pathfs.readFile("pesde.toml"))

	if pesde.dependencies then
		for k, v in pesde.dependencies do
			state.dependencies[k] = false
		end
	end

	if pesde.dev_dependencies then
		for k, v in pesde.dev_dependencies do
			state.devDependencies[k] = false
		end
	end

	scan(state, rootPath)

	local unusedDeps = {
		dependencies = {},
		devDependencies = {},
		count = 0,
	}

	for name, used in state.dependencies do
		if used == false then
			table.insert(unusedDeps.dependencies, name)
			unusedDeps.count += 1
		end
	end

	for name, used in state.devDependencies do
		if used == false then
			table.insert(unusedDeps.devDependencies, name)
			unusedDeps.count += 1
		end
	end

	return unusedDeps
end

return {
	scan = scanRoot,
}
