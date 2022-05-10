local pin = require("digisim.pin")

---@class port
---@field bits number
---@field pins pin[]
local port = {}
local MT = { __index = port }

function port.new(name, bits, comp, is_input)
	if bits == nil then
		bits = 1
	end
	if type(bits) ~= "number" or bits < 1 then
		error("invalid bits value")
	end
	bits = math.floor(bits)
	local ret = setmetatable({
		bits = bits,
		pins = {},
	}, MT)
	if bits == 1 then
		ret.pins[1] = pin.new(1, name, comp, is_input)
	else
		for i = 1, bits do
			ret.pins[i] = pin.new(i, name .. "[" .. i .. "]", comp, is_input)
		end
	end
	return ret
end

return port
