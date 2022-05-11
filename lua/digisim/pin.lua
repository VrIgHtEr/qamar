local net = require("digisim.net")

---@class pin
---@field num number
---@field name string
---@field net net
---@field port port
---@field connections table<string,connection>
---@field is_input boolean
local pin = {}
local MT = { __index = pin }

function pin.new(num, name, port, is_input)
	local ret = setmetatable({
		name = name,
		net = net.new(),
		connections = {},
		port = port,
		is_input = is_input and true or false,
		num = num,
	}, MT)
	ret.net:add_pin(ret)
	return ret
end

return pin
