---@class zigcomp
---@field id number
local Component = {}
local Component_MT = {
	__index = Component,
}

---@param id number
---@return zigcomp
function Component.new(id)
	if type(id) ~= "number" or id < 0 then
		error("invalid id")
	end
	return setmetatable({ id = math.floor(id) }, Component_MT)
end

local base_env = {
	math = math,
	pairs = pairs,
	ipairs = ipairs,
	getfenv = getfenv,
	tostring = tostring,
	print = print,
}
local env_mt = { __index = base_env }

local function create_env(id)
	local env = setmetatable({}, env_mt)
	function env.printid()
		print(id)
	end
	return env
end

function Component:construct(constructor, ...)
	local old_env = getfenv(constructor)
	setfenv(constructor, create_env(self.id))
	local ret = { pcall(constructor, ...) }
	setfenv(constructor, old_env)
	if ret[1] then
		table.remove(ret, 1)
		return unpack(ret)
	else
		error(ret[2])
	end
end

return Component
