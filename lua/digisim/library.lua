local function list_files(directory)
	local pfile = assert(
		io.popen(("find '%s' -mindepth 1 -maxdepth 1 -type f -printf '%%f\\0'"):format(directory), "r")
	)
	local list = pfile:read("*a")
	pfile:close()
	local folders = {}
	for filename in string.gmatch(list, "[^%z]+") do
		table.insert(folders, filename)
	end
	return folders
end

---@param simulation simulation
return function(simulation)
	local path = debug.getinfo(1).source
	if path:len() > 1 and path:sub(1, 1) == "@" then
		path = path:sub(2)
		local idx = 0
		while true do
			local i = path:find("/", idx + 1)
			if not i then
				break
			end
			idx = i
		end
		if idx > 0 then
			path = path:sub(1, idx)
		end
		io.stderr:write(path .. "\n")
		for _, x in ipairs(list_files(path .. "library")) do
			if x:match("^.*[.]lua$") then
				require("digisim.library." .. x:sub(1, x:len() - 4))(simulation)
			end
		end
	end
end
