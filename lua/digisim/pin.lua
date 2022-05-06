local signal = require("digisim.signal")

---@class pin
---@field name string
---@field value signal
---@field timestamp number
---@field component component
---@field connections table<string,connection>
local pin = {}
local MT = { __index = pin }

function pin.new(name, comp)
	local ret = setmetatable({
		name = name,
		timestamp = 0,
		value = signal.unknown,
		connections = {},
		component = comp,
	}, MT)
	return ret
end

return pin
