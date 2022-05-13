local net = require("digisim.net")
local signal = require("digisim.signal")

---@class pin
---@field num number
---@field name string
---@field net net
---@field port port
---@field connections table<string,connection>
---@field is_input boolean
---@field value signal
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
		value = signal.z,
	}, MT)
	ret.net:add_pin(ret)
	return ret
end

return pin
