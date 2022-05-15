---@class net
---@field name string
---@field parent net
---@field pins table<string,pin>
---@field num_pins pin[]
---@field timestamp number
---@field latched_value signal
---@field trace_ports port[]
---@field sensitivity_list component[]
local net = {}
local MT = { __index = net }

function net.new()
	local ret = setmetatable({
		pins = {},
		num_pins = 0,
		timestamp = 0,
	}, MT)
	return ret
end

function net:add_pin(pin)
	if self.pins[pin.name] then
		error("pin already added to net")
	end
	self.pins[pin.name] = pin
	self.num_pins = self.num_pins + 1
end

function net:merge(n)
	if n ~= self then
		for _, v in pairs(n.pins) do
			self:add_pin(v)
			v.net = self
		end
	end
end

return net
