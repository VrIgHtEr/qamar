local constants = require("digisim.constants")
local component = require("digisim.component")
local connection = require("digisim.connection")
local pq = require("digisim.pq")
local vcd = require("digisim.vcd")
local sigstr = vcd.sigstr
local DEBUG_MODE = constants.DEBUG_MODE

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
	ret:add_component("VCC", { names = { outputs = { "q" } } }, function()
		return 1
	end)
	ret:add_component("GND", { names = { outputs = { "q" } } }, function()
		return 0
	end)
	return ret
end
local signal = require("digisim.signal")

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
						if not x.is_input and x.port.component.step then
							table.insert(drivers, x)
						end
					end
					input.net.drivers = drivers
				end
				if #input.net.drivers == 0 then
					error("disconnected input: " .. input.name)
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
						if not x.is_input and x.port.component.step then
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
	local mark = {}
	for n, v in pairs(self.components) do
		if v.trace then
			mark[n] = true
		end
		for _, port in ipairs(v.inports) do
			for _, pin in pairs(port.pins) do
				for _, driver in ipairs(pin.net.drivers) do
					mark[driver.port.component.name] = true
					mark[n] = true
				end
			end
		end
	end
	for x in pairs(mark) do
		self.components[x] = nil
	end
	self.connections = nil
	for _, v in pairs(self.components) do
		for _, port in ipairs(v.inports) do
			for _, pin in pairs(port.pins) do
				pin.net.pins = nil
				pin.net.num_pins = nil
			end
		end
		for _, port in ipairs(v.outports) do
			for _, pin in pairs(port.pins) do
				pin.connections = nil
				local newpins = {}
				local newpincount = 0
				for n, netpin in pairs(pin.net.pins) do
					if self.components[netpin.port.component.name] then
						newpins[n] = netpin
						newpincount = newpincount + 1
					end
				end
				pin.net.pins = newpins
				pin.net.num_pins = newpincount
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
		error("cannot automatically connect vectors of different sizes: " .. pa.name .. " - " .. pb.name)
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
		error("out of range port access: " .. a .. ":" .. porta .. ":" .. starta .. ":" .. len)
	end
	if startb < 1 or pb.bits - startb + 1 < len then
		error("out of range port access: " .. b .. ":" .. portb .. ":" .. startb .. ":" .. len)
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

---@param self simulation
---@param c string
---@param p string
---@return port
local function find_port(self, c, p)
	local ca = self.components[c]
	if not ca then
		error("component not found: " .. tostring(c))
	end
	local pa = ca.ports[p]
	if not pa then
		error("port not found " .. tostring(c) .. "." .. tostring(p))
	end
	return pa
end

local function default_pin_len(self, a, porta, pina, len)
	local p = find_port(self, a, porta)
	pina = pina == nil and 1 or pina
	if type(pina) ~= "number" or pina < 1 or pina > p.bits then
		error("invalid pin number")
	end
	if len == nil then
		len = p.bits - pina + 1
	elseif type(len) ~= "number" or len < 1 or len > (p.bits - pina + 1) then
		error("invalid length")
	end
	return pina, len
end

---@param a string
---@param porta string
---@param pina number
---@param b string
---@param portb string
---@param startb number|nil
---@param len number|nil
---@return simulation
function simulation:fanout(a, porta, pina, b, portb, startb, len)
	startb, len = default_pin_len(self, b, portb, startb, len)
	if len < 1 then
		error("invalid length")
	end
	for i = 1, len do
		self:cp(1, a, porta, pina, b, portb, startb + i - 1)
	end
	return self
end

---@param a string
---@param porta string
---@param pina number|nil
---@param len number|nil
---@return simulation
function simulation:high(a, porta, pina, len)
	pina, len = default_pin_len(self, a, porta, pina, len)
	for i = 1, len do
		self:cp(1, "VCC", "q", 1, a, porta, pina + i - 1)
	end
	return self
end

---@param a string
---@param porta string
---@param pina number|nil
---@param len number|nil
---@return simulation
function simulation:low(a, porta, pina, len)
	pina, len = default_pin_len(self, a, porta, pina, len)
	for i = 1, len do
		self:cp(1, "GND", "q", 1, a, porta, pina + i - 1)
	end
	return self
end

---@param a string
---@param porta string
---@param pina number|nil
---@param len number|nil
---@return simulation
function simulation:pullup(a, porta, pina, len)
	pina, len = default_pin_len(self, a, porta, pina, len)
	local pull = a .. "." .. porta .. "#up" .. (pina - 1) .. "#" .. len
	return self:new_pullup(pull, { width = len }):cp(len, pull, "q", 1, a, porta, pina)
end

---@param a string
---@param porta string
---@param pina number|nil
---@param len number|nil
---@return simulation
function simulation:pulldown(a, porta, pina, len)
	pina, len = default_pin_len(self, a, porta, pina, len)
	local pull = a .. "." .. porta .. "#down" .. (pina - 1) .. "#" .. len
	return self:new_pulldown(pull, { width = len }):cp(len, pull, "q", 1, a, porta, pina)
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
	signal.unknown,
	signal.unknown,
	signal.unknown,
	signal.unknown,
	signal.unknown,
	signal.unknown,
	signal.unknown,
	signal.unknown,
	signal.weak,
	signal.weak,
	signal.weak,
	signal.weak,
	signal.low,
	signal.high,
	signal.unknown,
	signal.weak,
	signal.weakhigh,
	signal.weak,
	signal.weakhigh,
	signal.low,
	signal.high,
	signal.unknown,
	signal.weak,
	signal.weak,
	signal.weaklow,
	signal.weaklow,
	signal.low,
	signal.high,
	signal.unknown,
	signal.weak,
	signal.weakhigh,
	signal.weaklow,
	signal.z,
	signal.low,
	signal.high,
	signal.unknown,
	signal.low,
	signal.low,
	signal.low,
	signal.low,
	signal.low,
	signal.unknown,
	signal.unknown,
	signal.high,
	signal.high,
	signal.high,
	signal.high,
	signal.unknown,
	signal.high,
}

---@param a signal
---@param b signal
local function resolve(a, b)
	if
		DEBUG_MODE
		and (a == nil or b == nil or a < signal.unknown or a > signal.high or b < signal.unknown or b > signal.high)
	then
		return signal.unknown
	end
	return restable[(7 * (a - signal.unknown) + (b - signal.unknown)) + 1]
end

---@param time number
---@param p port
local function latch_values(time, p)
	for _, x in ipairs(p.pins) do
		if time > x.net.timestamp then
			local sig = signal.z
			for _, z in ipairs(x.net.drivers) do
				sig = resolve(sig, z.value)
			end
			if sig == signal.low or sig == signal.weaklow then
				x.net.latched_value = signal.low
			elseif sig == signal.high or sig == signal.weakhigh then
				x.net.latched_value = signal.high
			elseif sig == signal.z then
				x.net.latched_value = signal.z
			else
				x.net.latched_value = signal.unknown
			end
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

local inputs = {}

function simulation:step()
	if not self.simulation_started then
		self:init_nets()
		self.simulation_started = true
	end
	local maxstep = 1000
	local ticks = 0

	---@type table<string,component>
	local dirty = {}
	if self.time == 0 then
		for k, v in pairs(self.roots) do
			dirty[k] = v
		end
	else
		local _, nexttimestamp = self.queue:peek()
		if nexttimestamp ~= nil then
			self.time = nexttimestamp - 1
		end
	end
	local count
	repeat
		local nextdirty = {}
		self.time = self.time + 1
		while true do
			local val, ts = self.queue:peek()
			if ts == nil or ts > self.time then
				break
			end
			dirty[val.name] = val
			self.queue:pop()
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
				for i = #c.inports, 1, -1 do
					inputs[i] = nil
				end

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
				local numoutputs = #outputs - 1
				local sleep = outputs[numoutputs + 1]
				if sleep > 0 then
					self.queue:push(self.time + sleep, c)
				end
				for i = 1, numoutputs do
					local value = outputs[i]
					local output = c.outports[i]
					if output.bits == 1 then
						handle_output_value(value, output.pins[1])
					else
						if #value ~= output.bits then
							error(c.name .. ": " .. output.bits .. " " .. #value)
						end
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
