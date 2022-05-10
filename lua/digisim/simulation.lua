local queue = require("qamar.util.deque")
local constants = require("digisim.constants")
local component = require("digisim.component")
local connection = require("digisim.connection")
local vcd = require("digisim.trace.vcd")

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

function simulation:update_net_names()
	for _, v in pairs(self.components) do
		for _, x in ipairs(v.inputs) do
			x.net.name = nil
		end
		for _, x in ipairs(v.outputs) do
			x.net.name = nil
		end
	end
	---@type table<net,boolean>
	local nets = {}
	for _, v in pairs(self.components) do
		if v.trace then
			for _, x in ipairs(v.outputs) do
				x.net.name = x.name
				nets[x.net] = true
			end
		end
	end
	for net in pairs(nets) do
		self.trace:get(net.name)
	end
end

function simulation:add_component(name, inputs, outputs, handler, opts)
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
	local c = component.new(name, inputs, outputs, handler, { names = opts.names })
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
---@param output number
---@param input number
---@return simulation
function simulation:connect(a, output, b, input)
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
--
---@param a string
---@param b string
---@param pina string
---@param pinb string
---@return simulation
function simulation:c(a, pina, b, pinb)
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
	local o, i = ca.pins[pina], cb.pins[pinb]
	if not o then
		error("pin not found " .. a .. "." .. pina)
	end
	if not i then
		error("pin not found " .. b .. "." .. pinb)
	end
	local na = a .. "[" .. o.num .. "]" .. "[" .. i.num .. "]" .. b
	if self.connections[na] then
		error("connection already exists: " .. na)
	end
	self.connections[na] = connection.new(na, o, i)
	return self
end

---@param sim simulation
---@param name string
---@param time number
---@param sig signal
local function add_trace(sim, name, time, sig)
	sim.trace:trace(name, time, sig)
end

function simulation:step()
	if not self.simulation_started then
		self:update_net_names()
		self.simulation_started = true
	end
	--local prt = function(_) end
	--prt("---------------------------------------------------------")
	local maxstep = 10000
	local ticks = 0

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
			for _, x in ipairs(c.inputs) do
				x.net.latched_value = x.net.value
			end
		end
		for _, c in pairs(dirty) do
			if c.step then
				local inputs = {}
				for i, x in ipairs(c.inputs) do
					inputs[i] = x.net.latched_value
				end
				local outputs = { c.step(self.time, unpack(inputs)) }
				for i, value in ipairs(outputs) do
					local output = c.outputs[i]
					if output.net.value ~= value then
						--if output.net.timestamp <= self.time then
						output.net.value = value
						output.net.timestamp = self.time
						if output.net.name ~= nil then
							add_trace(self, output.net.name, self.time, value)
						end
						--else
						--end

						for _, x in pairs(output.net.pins) do
							if x ~= output and x.is_input and x.component.step then
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
		ticks = ticks + 1
		if maxstep == 0 then
			error("circuit failed to stabilize")
		end
	until count == 0
	return self, ticks
end

require("digisim.library")(simulation)

return simulation
