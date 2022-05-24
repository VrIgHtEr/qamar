local constants = require("digisim.constants")
local component = require("digisim.component")
local connection = require("digisim.connection")
local pq = require("digisim.pq")
local vcd = require("digisim.vcd")
local sigstr = vcd.sigstr
local concat = table.concat
local push = pq.push
local peek = pq.peek
local pop = pq.pop
local pairs = pairs
local ipairs = ipairs

local unknown, weak, weaklow, weakhigh, disconnected, low, high
do
	local signal = require("digisim.signal")
	unknown = signal.unknown
	weak = signal.weak
	weaklow = signal.weaklow
	weakhigh = signal.weakhigh
	disconnected = signal.z
	low = signal.low
	high = signal.high
end

---@class simulation
---@field components table<string,component>
---@field connections table<string,connection>
---@field time number
---@field trace vcd
---@field queue pq
---@field simulation_started boolean
local simulation = {}
local MT = { __index = simulation }

function simulation.new()
	local ret = setmetatable({
		components = {},
		connections = {},
		time = 0,
		next_connection_id = 0,
		trace = vcd.new(),
		queue = pq.new(),
		simulation_started = false,
	}, MT)
	return ret
end

function simulation:init_nets()
	if not self.roots then
		local count = 0
		self.roots = {}
		for name, x in pairs(self.components) do
			if #x.inports == 0 then
				self.roots[name] = x
				count = count + 1
			end
		end
		if count == 0 then
			error("must have at least one component with zero inputs")
		end
	end
	for _, v in pairs(self.components) do
		for _, p in ipairs(v.inports) do
			if v.trace and constants.TRACE_INPUTS then
				self.trace:get(p.name, p.bits)
			end
			for _, input in pairs(p.pins) do
				if not input.net.drivers then
					local drivers = {}
					for _, x in pairs(input.net.pins) do
						if not x.is_input then
							table.insert(drivers, x)
						end
					end
					input.net.drivers = drivers
				end
			end
		end
		for _, p in ipairs(v.outports) do
			if v.trace then
				self.trace:get(p.name, p.bits)
			end
			for _, output in ipairs(p.pins) do
				if not output.net.drivers then
					local drivers = {}
					for _, x in pairs(output.net.pins) do
						if not x.is_input then
							table.insert(drivers, x)
						end
					end
					output.net.drivers = drivers
				end
				if not output.net.sensitivity_list then
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
				end
				if not output.net.trace_ports then
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

function simulation:add_component(name, opts, handler)
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
	if pb.name < pa.name or (pa.name == pb.name and startb < starta) then
		pa, pb = pb, pa
		starta, startb = startb, starta
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

--[[
uuuuuuu
uwwww01
uwhwh01
uwwll01
uwhlz01
u00000u
u1111u1
--]]
local restable = {
	unknown,
	unknown,
	unknown,
	unknown,
	unknown,
	unknown,
	unknown,
	unknown,
	weak,
	weak,
	weak,
	weak,
	low,
	high,
	unknown,
	weak,
	weakhigh,
	weak,
	weakhigh,
	low,
	high,
	unknown,
	weak,
	weak,
	weaklow,
	weaklow,
	low,
	high,
	unknown,
	weak,
	weakhigh,
	weaklow,
	disconnected,
	low,
	high,
	unknown,
	low,
	low,
	low,
	low,
	low,
	unknown,
	unknown,
	high,
	high,
	high,
	high,
	unknown,
	high,
}

---@param a signal
---@param b signal
local function resolve(a, b)
	return a == nil
		or b == nil
		or a < unknown
		or a > high
		or b < unknown
		or b > high and unknown
		or restable[(7 * (a - unknown) + (b - unknown)) + 1]
end

---@param time number
---@param p port
local function latch_values(time, p)
	for _, x in ipairs(p.pins) do
		local net = x.net
		if time > net.timestamp then
			local sig = disconnected
			for _, z in ipairs(net.drivers) do
				sig = resolve(sig, z.value)
			end
			if sig == low or sig == weaklow then
				net.latched_value = low
			elseif sig == high or sig == weakhigh then
				net.latched_value = high
			elseif sig == disconnected then
				net.latched_value = disconnected
			else
				net.latched_value = unknown
			end
			net.timestamp = time
		end
	end
end

local next = next
local function is_empty(tbl)
	return next(tbl) == nil
end

local inputs = {}

---@param output pin
local function handle_output_value(value, output, trace_ports, nextdirty)
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

function simulation:step()
	if not self.simulation_started then
		self:init_nets()
		self.simulation_started = true
	end
	local maxstep = 1000
	local ticks = 0
	local queue = self.queue

	---@type table<string,component>
	local dirty = {}
	if self.time == 0 then
		for k, v in pairs(self.roots) do
			dirty[k] = v
		end
	else
		local _, nexttimestamp = peek(queue)
		if nexttimestamp ~= nil then
			self.time = nexttimestamp - 1
		end
	end
	repeat
		local nextdirty = {}
		local time = self.time + 1
		self.time = time
		while true do
			local val, ts = peek(queue)
			if ts == nil or ts > time then
				break
			end
			dirty[val.name] = val
			pop(queue)
		end
		for _, c in pairs(dirty) do
			for _, p in ipairs(c.inports) do
				latch_values(time, p)
			end
		end
		---@type table<port,boolean>
		local trace_ports = {}

		for _, c in pairs(dirty) do
			local step = c.step
			local name = c.name
			local inports = c.inports
			local outports = c.outports
			if step then
				for i, p in ipairs(inports) do
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
				local outputs = { step(time, unpack(inputs)) }
				for i = #inports, 1, -1 do
					inputs[i] = nil
				end

				local numoutputs = #outputs - 1
				local sleep = outputs[numoutputs + 1]
				if sleep > 0 then
					push(queue, time + sleep, c)
				end
				for i = 1, numoutputs do
					local value = outputs[i]
					local output = outports[i]
					local bits = output.bits
					if bits == 1 then
						handle_output_value(value, output.pins[1], trace_ports, nextdirty)
					else
						if #value ~= bits then
							error(name .. ": " .. bits .. " " .. #value)
						end
						for j, x in ipairs(output.pins) do
							handle_output_value(value[j], x, trace_ports, nextdirty)
						end
					end
				end
			end
		end

		for p in pairs(trace_ports) do
			latch_values(time + 1, p)
			local val
			local pins = p.pins
			if p.bits == 1 then
				val = sigstr(pins[1].net.latched_value)
			else
				val = { "b" }
				local len = #pins
				for i = 1, len do
					local x = pins[len - i + 1]
					val[i + 1] = sigstr(x.net.latched_value)
				end
				val[len + 1] = " "
				val = concat(val)
			end
			add_trace(self, p.name, time, val)
		end

		dirty = nextdirty
		maxstep = maxstep - 1
		ticks = ticks + 1
		if maxstep == 0 then
			error("circuit failed to stabilize")
		end
	until is_empty(dirty)
	return self, ticks
end

require("digisim.library")(simulation)

return simulation
