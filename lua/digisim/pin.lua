local net = require("digisim.net")

---@class pin
---@field name string
---@field net net
---@field component component
---@field connections table<string,connection>
---@field is_input boolean
local pin = {}
local MT = { __index = pin }

function pin.new(name, comp, is_input)
	local ret = setmetatable({
		name = name,
		net = net.new(),
		connections = {},
		component = comp,
		is_input = is_input and true or false,
	}, MT)
	ret.net:add_pin(ret)
	return ret
end

return pin
