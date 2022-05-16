local queue = require("qamar.util.deque")
local constants = require("digisim.constants")
local component = require("digisim.component")
local connection = require("digisim.connection")
local vcd = require("digisim.vcd")

local sigstr = vcd.sigstr

---@class simulation
---@field components table<string,component>
---@field connections table<string,connection>
---@field queue deque
---@field time number
---@field trace vcd
---@field simulation_started boolean
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
		simulation_started = false,
	}, MT)
	return ret
end

function simulation:init_nets()
	for _, v in pairs(self.components) do
		if v.trace then
			if constants.TRACE_INPUTS then
				for _, p in ipairs(v.inports) do
					self.trace:get(p.name, p.bits)
				end
			end
			for _, p in ipairs(v.outports) do
				self.trace:get(p.name, p.bits)
				for _, output in ipairs(p.pins) do
					local sensitivity_list = {}
					for _, x in pairs(output.net.pins) do
						if x.is_input and x.port.component.step then
							sensitivity_list[x.port.component] = true
						end
					end
					output.net.sensitivity_list = {}
					for x in pairs(sensitivity_list) do
						table.insert(output.net.sensitivity_list, x)
					end
					local trace_ports = {}
					for _, x in pairs(output.net.pins) do
						if
							((x.port.is_input and constants.TRACE_INPUTS) or not x.port.is_input)
							and x.port.component.trace
						then
							trace_ports[x.port] = true
						end
					end
					output.net.trace_ports = {}
					for x in pairs(trace_ports) do
						table.insert(output.net.trace_ports, x)
					end
				end
			end
		end
	end
end

function simulation:add_component(name, handler, opts)
	if self.simulation_started then
		error("simulation started - cannot add new component")
	end
	if type(name) ~= "string" then
		error("invalid name")
	end
	if self.components[name] then
		error("component already exists: " .. name)
	end
	if opts == nil then
		opts = {}
	elseif type(opts) ~= "table" then
		error("invalid opts type")
	end
	local c = component.new(name, handler, { names = opts.names })
	c.trace = opts.trace and true or false or constants.DEBUG_TRACE_ALL_OUTPUTS
	self.components[name] = c
	return self
end

function simulation:register_component(name, constructor)
	if type(name) ~= "string" or not name:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
		error("invalid name")
	end
	if self["new_" .. name] then
		error("Component already registered: " .. name)
	end
	self["new_" .. name] = function(s, n, opts)
		if s.components[n] then
			error("component already exists")
		end
		constructor(s, n, opts)
		return s
	end
	return self
end

---@param a string
---@param b string
---@param porta string
---@param portb string
---@return simulation
function simulation:c(a, porta, b, portb)
	if self.simulation_started then
		error("simulation started - cannot add new component")
	end
	local ca, cb = self.components[a], self.components[b]
	if not ca then
		error("component not found: " .. a)
	end
	if not cb then
		error("component not found: " .. b)
	end
	local pa, pb = ca.ports[porta], cb.ports[portb]
	if not pa then
		error("port not found " .. a .. "." .. porta)
	end
	if not pb then
		error("port not found " .. b .. "." .. portb)
	end
	if pa.bits ~= pb.bits then
		error("cannot automatically connect vectors of different sizes")
	end
	return self:cp(pa.bits, a, porta, 1, b, portb, 1)
end

---@param len number
---@param a string
---@param porta string
---@param starta number
---@param b string
---@param portb string
---@param startb number
---@return simulation
function simulation:cp(len, a, porta, starta, b, portb, startb)
	if self.simulation_started then
		error("simulation started - cannot add new component")
	end
	local ca, cb = self.components[a], self.components[b]
	if not ca then
		error("component not found: " .. a)
	end
	if not cb then
		error("component not found: " .. b)
	end
	local pa, pb = ca.ports[porta], cb.ports[portb]
	if not pa then
		error("port not found " .. a .. "." .. porta)
	end
	if not pb then
		error("port not found " .. b .. "." .. portb)
	end
	if len < 1 then
		error("invalid length")
	end
	if starta < 1 or pa.bits - starta + 1 < len then
		error("out of range port access")
	end
	if startb < 1 or pb.bits - startb + 1 < len then
		error("out of range port access")
	end
	for i = 1, len do
		local na = pa.name .. "[" .. (starta + i - 1) .. "]" .. pb.name .. "[" .. (startb + i - 1) .. "]"
		if self.connections[na] then
			error("connection already exists: " .. na)
		end
		self.connections[na] = connection.new(na, pa.pins[starta + i - 1], pb.pins[startb + i - 1])
	end
	return self
end

---@param sim simulation
---@param name string
---@param time number
---@param sig signal
local function add_trace(sim, name, time, sig)
	sim.trace:trace(name, time, sig)
end

local signal = require("digisim.signal")

---@param a signal
---@param b signal
local function resolve(a, b)
	if a == signal.weakhigh then
		if b == signal.z or b == signal.high or b == signal.weakhigh then
			return signal.high
		elseif b == signal.low then
			return signal.low
		else
			return signal.unknown
		end
	elseif a == signal.weaklow then
		if b == signal.z or b == signal.low or b == signal.weaklow then
			return signal.low
		elseif b == signal.high then
			return signal.high
		else
			return signal.unknown
		end
	elseif a == signal.z then
		if b == signal.z then
			return signal.z
		elseif b == signal.weaklow or b == signal.low then
			return signal.low
		elseif b == signal.weakhigh or b == signal.high then
			return signal.high
		else
			return signal.unknown
		end
	elseif a == signal.low then
		if b == signal.weaklow or b == signal.weakhigh or b == signal.low or b == signal.z then
			return signal.low
		else
			return signal.unknown
		end
	elseif a == signal.high then
		if b == signal.weakhigh or b == signal.weaklow or b == signal.z or b == signal.high then
			return signal.high
		else
			return signal.unknown
		end
	else
		return signal.unknown
	end
end

---@param time number
---@param p port
local function latch_values(time, p)
	for _, x in ipairs(p.pins) do
		if time > x.net.timestamp then
			local sig = signal.z
			for _, z in pairs(x.net.pins) do
				if not z.is_input then
					sig = resolve(sig, z.value)
				end
			end
			x.net.latched_value = sig
			x.net.timestamp = time
		end
	end
end

local function tbl_count(tbl)
	local ret = -#tbl
	for _ in pairs(tbl) do
		ret = ret + 1
	end
	return ret
end

function simulation:step()
	if not self.simulation_started then
		self:init_nets()
		self.simulation_started = true
	end
	local maxstep = 1000
	local ticks = 0

	---@type table<string,component>
	local dirty = {}
	local roots = {}
	local count = 0
	for name, x in pairs(self.components) do
		if #x.inports == 0 then
			roots[name] = x
			count = count + 1
		end
	end
	if count == 0 then
		error("must have at least one component with zero inputs")
	end
	repeat
		local nextdirty = {}
		self.time = self.time + 1
		for k, v in pairs(roots) do
			dirty[k] = v
		end
		for _, c in pairs(dirty) do
			for _, p in ipairs(c.inports) do
				latch_values(self.time, p)
			end
		end
		---@type table<port,boolean>
		local trace_ports = {}

		for _, c in pairs(dirty) do
			if c.step then
				local inputs = {}
				for i, p in ipairs(c.inports) do
					if p.bits == 1 then
						inputs[i] = p.pins[1].net.latched_value
					else
						local v = {}
						inputs[i] = v

						for j, x in ipairs(p.pins) do
							v[j] = x.net.latched_value
						end
					end
				end
				local outputs = { c.step(self.time, unpack(inputs)) }

				---@param output pin
				local function handle_output_value(value, output)
					if output.value ~= value then
						output.value = value
						for _, x in ipairs(output.net.trace_ports) do
							trace_ports[x] = true
						end
						for _, x in ipairs(output.net.sensitivity_list) do
							if x ~= output then
								nextdirty[x.name] = x
							end
						end
					end
				end

				for i, value in ipairs(outputs) do
					local output = c.outports[i]
					if output.bits == 1 then
						handle_output_value(value, output.pins[1])
					else
						for j, x in ipairs(output.pins) do
							handle_output_value(value[j], x)
						end
					end
				end
			end
		end

		for p in pairs(trace_ports) do
			latch_values(self.time + 1, p)
			local val
			if p.bits == 1 then
				val = sigstr(p.pins[1].net.latched_value)
			else
				val = { "b" }
				local len = #p.pins
				for i = 1, len do
					local x = p.pins[len - i + 1]
					val[i + 1] = sigstr(x.net.latched_value)
				end
				table.insert(val, " ")
				val = table.concat(val)
			end
			add_trace(self, p.name, self.time, val)
		end

		dirty = nextdirty
		count = tbl_count(dirty)
		maxstep = maxstep - 1
		ticks = ticks + 1
		if maxstep == 0 then
			error("circuit failed to stabilize")
		end
	until count == 0
	return self, ticks
end

require("digisim.library")(simulation)

return simulation
