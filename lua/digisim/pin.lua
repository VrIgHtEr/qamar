local net = require("digisim.net")

---@class pin
---@field name string
---@field net net
---@field component component
---@field connections table<string,connection>
local pin = {}
local MT = { __index = pin }

function pin.new(name, comp)
	local ret = setmetatable({
		name = name,
		net = net.new(),
		connections = {},
		component = comp,
	}, MT)
	ret.net:add_pin(ret)
	return ret
end

return pin
