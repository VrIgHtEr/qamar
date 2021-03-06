local pin = require("digisim.pin")

---@class port
---@field name string
---@field bits number
---@field pins pin[]
---@field is_input boolean
---@field component component
local port = {}
local MT = { __index = port }

---@param name string
---@param bits number
---@param comp component
---@param is_input boolean
---@return port
function port.new(name, bits, comp, is_input)
	if bits == nil then
		bits = 1
	end
	if type(name) ~= "string" then
		error("invalid name type")
	end
	if type(bits) ~= "number" or bits < 1 then
		error("invalid bits value")
	end
	bits = math.floor(bits)
	local ret = setmetatable({
		name = name,
		bits = bits,
		pins = {},
		is_input = is_input and true or false,
		component = comp,
	}, MT)
	if bits == 1 then
		ret.pins[1] = pin.new(1, name, ret, is_input)
	else
		for i = 1, bits do
			ret.pins[i] = pin.new(i, name .. "[" .. i .. "]", ret, is_input)
		end
	end
	return ret
end

return port
