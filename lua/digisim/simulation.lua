local queue = require("qamar.util.deque")
local constants = require("digisim.constants")
local component = require("digisim.component")
local connection = require("digisim.connection")
local signal = require("digisim.signal")
local vcd = require("digisim.trace.vcd")

---@class simulation
---@field components table<string,component>
---@field connections table<string,connection>
---@field queue deque
---@field time number
---@field trace vcd
local simulation = {}
local MT = { __index = simulation }

function simulation.new()
	local ret = setmetatable({
		components = {},
		connections = {},
		time = 0,
		next_connection_id = 0,
		queue = queue(),
		trace = vcd.new(),
	}, MT)
	return ret
end

function simulation:add_component(name, inputs, outputs, handler, trace)
	if type(name) ~= "string" or not name:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
		error("invalid name")
	end
	if self.components[name] then
		error("component already exists: " .. name)
	end
	local c = component.new(name, inputs, outputs, handler)
	c.trace = trace and true or false or constants.DEBUG_TRACE_ALL_OUTPUTS
	self.components[name] = c
	return self
end

function simulation:register_component(name, inputs, outputs, constructor)
	if type(name) ~= "string" or not name:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
		error("invalid name")
	end
	if self["new_" .. name] then
		error("Component already registered: " .. name)
	end
	self["new_" .. name] = function(s, n, trace)
		if s.components[n] then
			error("component already exists")
		end
		local c = component.new(n, inputs, outputs, function() end)
		c.step = nil
		s.components[n] = c
		constructor(s, c, trace)
		return s
	end
	return self
end

local function tbl_count(x)
	local amt = -#x
	for _ in pairs(x) do
		amt = amt + 1
	end
	return amt
end

---@param a string
---@param b string
---@param output number
---@param input number
---@return simulation
function simulation:connect(a, output, b, input)
	local ca, cb = self.components[a], self.components[b]
	if not ca then
		error("component not found: " .. a)
	end
	if not cb then
		error("component not found: " .. b)
	end
	local o, i = ca.outputs[output], cb.inputs[input]
	if not o then
		error("output not found " .. a .. "[" .. tostring(output) .. "]")
	end
	if not i then
		error("input not found " .. b .. "[" .. tostring(input) .. "]")
	end
	local na = a .. "[" .. output .. "]" .. "[" .. input .. "]" .. b
	if self.connections[na] then
		error("connection already exists: " .. na)
	end
	self.connections[na] = connection.new(na, o, i)
	return self
end

---@class sample
---@field time number
---@field value signal

---@param sim simulation
---@param name string
---@param time number
---@param sig signal
local function add_trace(sim, name, time, sig)
	sim.trace:trace(name, time, sig)
end

function simulation:step()
	--local prt = function(_) end
	--prt("---------------------------------------------------------")
	local maxstep = 10000

	---@type table<string,component>
	local dirty = {}
	local roots = {}
	local count = 0
	for name, x in pairs(self.components) do
		if #x.inputs == 0 then
			roots[name] = x
			count = count + 1
		end
	end
	if count == 0 then
		error("must have at least one component with zero inputs")
	end
	--prt(self.time)
	repeat
		local nextdirty = {}
		local nextcount = 0
		self.time = self.time + 1
		for k, v in pairs(roots) do
			dirty[k] = v
		end
		for _, c in pairs(dirty) do
			if c.step then
				local inputs = {}
				for i, x in ipairs(c.inputs) do
					inputs[i] = x.net.value
				end
				local outputs = { c.step(self.time, unpack(inputs)) }
				for i, value in ipairs(outputs) do
					local output = c.outputs[i]
					if output.net.value ~= value then
						--if output.net.timestamp <= self.time then
						output.net.value = value
						output.net.timestamp = self.time
						if c.trace then
							add_trace(self, output.name, self.time, value)
						end
						--else
						--end

						for _, x in pairs(output.net.pins) do
							if x ~= output and x.component.step then
								if not nextdirty[x.component.name] then
									nextdirty[x.component.name] = x.component
									nextcount = nextcount + 1
								end
							end
						end

						--prt(output.timestamp .. ":" .. vim.inspect(inputs) .. ":" .. output.name .. ":" .. output.value)
					else
						--if #output.component.inputs > 0 then prt( self.time .. ":" .. vim.inspect(inputs) .. ":" .. output.name .. ":" .. output.value .. ":SAME") end
					end
				end
			end
		end
		dirty = nextdirty
		count = nextcount
		maxstep = maxstep - 1
		if maxstep == 0 then
			error("circuit failed to stabilize")
		end
	until count == 0
	return self
end

function simulation:_(a, output, b, input)
	local args
	if input ~= nil then
		args = 4
	elseif b ~= nil then
		args = 3
	elseif output ~= nil then
		args = 2
	elseif a ~= nil then
		args = 1
	else
		args = 0
	end
	if args < 2 then
		error("invalid number of arguments")
	end
	if type(a) ~= "string" then
		error("invalid argument type")
	end
	if args == 2 then
		b, output = output, nil
	elseif args == 3 then
		if type(output) == "number" then
			if type(b) ~= "string" then
				error("invalid argument type")
			end
		elseif type(output) == "string" then
			input = b
			b = output
			output = nil
			if type(input) ~= "number" then
				error("invalid argument type")
			end
		else
			error("invalid argument type")
		end
	else
		if type(b) ~= "string" or type(output) ~= "number" or type(input) ~= "number" then
			error("invalid argument type")
		end
	end
	local ca, cb = self.components[a], self.components[b]
	if not ca then
		error("component not found: " .. a)
	end
	if not cb then
		error("component not found: " .. b)
	end
	if #ca.outputs == 0 then
		error("component has no outputs")
	end
	if not output then
		-- if #ca.outputs > 1 then error("output not specified and component has multiple outputs") end
		output = 1
	end
	if #cb.inputs == 0 then
		error("component has no inputs")
	end
	if not input then
		for i, x in ipairs(cb.inputs) do
			if tbl_count(x.connections) == 0 then
				input = i
				break
			end
		end
		if not input then
			error("could not find unused input")
		end
	end
	return self:connect(a, output, b, input)
end

function simulation:new_nand(name, trace)
	return self:add_component(name, 2, 1, function(_, a, b)
		return (a == signal.high and b == signal.high) and signal.low or signal.high
	end, trace)
end

function simulation:new_nor(name, trace)
	return self:add_component(name, 2, 1, function(_, a, b)
		return (a == signal.high or b == signal.high) and signal.low or signal.high
	end, trace)
end

function simulation:new_xnor(name, trace)
	return self:add_component(name, 2, 1, function(_, a, b)
		return (a == signal.high and b == signal.low or a == signal.low and b == signal.high) and signal.low
			or signal.high
	end, trace)
end

function simulation:new_and(name, trace)
	return self:add_component(name, 2, 1, function(_, a, b)
		return (a == signal.high and b == signal.high) and signal.high or signal.low
	end, trace)
end

function simulation:new_xor(name, trace)
	return self:add_component(name, 2, 1, function(_, a, b)
		return (a == signal.high and b == signal.low or a == signal.low and b == signal.high) and signal.high
			or signal.low
	end, trace)
end

function simulation:new_or(name, trace)
	return self:add_component(name, 2, 1, function(_, a, b)
		return (a == signal.high or b == signal.high) and signal.high or signal.low
	end, trace)
end

function simulation:new_not(name, trace)
	return self:add_component(name, 1, 1, function(_, a)
		return a == signal.low and signal.high or signal.low
	end, trace)
end

function simulation:new_buffer(name, trace)
	return self:add_component(name, 1, 1, function(_, a)
		return a
	end, trace)
end

local chars = {
	unknown = "░",
	full_z = "█",
	full_low = "▄",
	full_high = "▀",
	z_low = "▚",
	z_high = "▞",
	left_half = "▌",
	low_high = "▛",
	high_low = "▙",
}

function simulation:get_trace(name, maxtime)
	local trace = self.trace[name]
	if trace then
		maxtime = maxtime or trace[#trace].time + 1
		local ret = {}
		local char = chars.unknown
		local sig = signal.unknown
		local time = 0
		for _, t in ipairs(trace) do
			while time < t.time do
				time = time + 1
				if sig == signal.unknown then
					char = chars.unknown
				elseif sig == signal.z then
					char = chars.full_z
				elseif sig == signal.low then
					char = chars.full_low
				elseif sig == signal.high then
					char = chars.full_high
				else
					error("invalid value")
				end
				ret[time] = char
			end
			time = time + 1
			if sig == signal.unknown then
				if t.value == signal.unknown then
					char = chars.unknown
				elseif t.value == signal.z then
					char = chars.full_z
				elseif t.value == signal.low then
					char = chars.full_low
				elseif t.value == signal.high then
					char = chars.full_high
				else
					error("invalid value")
				end
			elseif sig == signal.z then
				if t.value == signal.unknown then
					char = chars.unknown
				elseif t.value == signal.z then
					char = chars.full_z
				elseif t.value == signal.low then
					char = chars.z_low
				elseif t.value == signal.high then
					char = chars.z_high
				else
					error("invalid value")
				end
			elseif sig == signal.low then
				if t.value == signal.unknown then
					char = chars.unknown
				elseif t.value == signal.z then
					char = chars.left_half
				elseif t.value == signal.low then
					char = chars.full_low
				elseif t.value == signal.high then
					char = chars.low_high
				else
					error("invalid value")
				end
			elseif sig == signal.high then
				if t.value == signal.unknown then
					char = chars.unknown
				elseif t.value == signal.z then
					char = chars.left_half
				elseif t.value == signal.low then
					char = chars.high_low
				elseif t.value == signal.high then
					char = chars.full_high
				else
					error("invalid value")
				end
			else
				error("invalid value")
			end
			sig = t.value
			ret[time] = char
		end
		while time < maxtime do
			time = time + 1
			if sig == signal.unknown then
				char = chars.unknown
			elseif sig == signal.z then
				char = chars.full_z
			elseif sig == signal.low then
				char = chars.full_low
			elseif sig == signal.high then
				char = chars.full_high
			else
				error("invalid value")
			end
			ret[time] = char
		end
		return table.concat(ret)
	end
	return ""
end

return simulation
