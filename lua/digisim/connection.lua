---@class connection
---@field name string
---@field a pin
---@field b pin
local connection = {}
local MT = { __index = connection }

---@param name string
---@param a pin
---@param b pin
---@return connection
function connection.new(name, a, b)
	local ret = setmetatable({
		name = name,
		a = a,
		b = b,
	}, MT)
	a.connections[name] = ret
	b.connections[name] = ret
	if a.net ~= b.net then
		if a.net.num_pins < b.net.num_pins then
			a, b = b, a
		end
		a.net:merge(b.net)
	end
	return ret
end

return connection
