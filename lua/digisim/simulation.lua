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

function simulation:add_component(name, inputs, outputs, handler, opts)
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
	local c = component.new(name, inputs, outputs, handler)
	c.trace = opts.trace and true or false or constants.DEBUG_TRACE_ALL_OUTPUTS
	if c.trace and handler then
		for _, o in ipairs(c.outputs) do
			self.trace:get(o.name)
		end
	end
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

---@param a string
---@param b string
---@param output number
---@param input number
---@return simulation
function simulation:alias_input(a, output, b, input)
	local ca, cb = self.components[a], self.components[b]
	if not ca then
		error("component not found: " .. a)
	end
	if not cb then
		error("component not found: " .. b)
	end
	local o, i = ca.inputs[output], cb.inputs[input]
	if not o then
		error("input not found " .. "[" .. tostring(output) .. "]" .. a)
	end
	if not i then
		error("input not found " .. "[" .. tostring(input) .. "]" .. b)
	end
	o.net:merge(i.net)
	return self
end

---@param a string
---@param b string
---@param output number
---@param input number
---@return simulation
function simulation:alias_output(a, output, b, input)
	local ca, cb = self.components[a], self.components[b]
	if not ca then
		error("component not found: " .. a)
	end
	if not cb then
		error("component not found: " .. b)
	end
	local o, i = ca.outputs[output], cb.outputs[input]
	if not o then
		error("output not found " .. "[" .. tostring(output) .. "]" .. a)
	end
	if not i then
		error("output not found " .. "[" .. tostring(input) .. "]" .. b)
	end
	o.net:merge(i.net)
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
						if c.trace then
							add_trace(self, output.name, self.time, value)
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
		if #ca.outputs > 1 then
			error("output not specified and component has multiple outputs")
		end
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

require("digisim.library")(simulation)

return simulation
