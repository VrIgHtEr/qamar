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
	if c.trace then
		for _, o in ipairs(c.outputs) do
			self.trace:get(o.name)
		end
	end
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
		constructor(s, c.name, trace)
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

simulation:register_component(
	"sr_latch",
	2,
	2,
	---@param circuit simulation
	---@param name string
	---@param trace boolean
	function(circuit, name, trace)
		local na = name .. "___a"
		local nb = name .. "___b"
		circuit
			:new_nand(na, trace)
			:new_nand(nb, trace)
			:_(na, nb, 1)
			:_(nb, na, 2)
			:alias_input(name, 2, na, 1)
			:alias_input(name, 1, nb, 2)
			:alias_output(na, 1, name, 1)
			:alias_output(nb, 1, name, 2)
	end
)

simulation:register_component(
	"gated_sr_latch",
	3,
	2,
	---@param circuit simulation
	---@param name string
	---@param trace boolean
	function(circuit, name, trace)
		local nl = name .. "___l"
		local na = name .. "___a"
		local nb = name .. "___b"
		circuit
			:new_sr_latch(nl, trace)
			:new_and(na)
			:new_and(nb)
			:_(na, nl, 1)
			:_(nb, nl, 2)
			:alias_input(name, 1, na, 1)
			:alias_input(name, 3, na, 2)
			:alias_input(name, 2, nb, 1)
			:alias_input(name, 3, nb, 2)
			:alias_output(nl, 1, name, 1)
			:alias_output(nl, 2, name, 2)
	end
)

simulation:register_component(
	"jk_flipflop",
	3,
	2,
	---@param circuit simulation
	---@param name string
	---@param trace boolean
	function(circuit, name, trace)
		local nl = name .. "___l"
		local nj = name .. "___nj"
		local nk = name .. "___nk"
		local aj = name .. "___aj"
		local ak = name .. "___ak"
		circuit
			:new_sr_latch(nl, trace)
			:new_nand(nj)
			:new_nand(nk)
			:alias_input(name, 3, nj, 1)
			:alias_input(name, 3, nk, 1)
			:_(nj, nl, 1)
			:_(nk, nl, 2)
			:new_and(aj)
			:new_and(ak)
			:_(aj, nj, 2)
			:_(ak, nk, 2)
			:alias_input(name, 1, aj, 1)
			:alias_input(name, 2, ak, 1)
			:_(nl, 1, ak, 2)
			:_(nl, 2, aj, 2)
			:alias_output(nl, 1, name, 1)
			:alias_output(nl, 2, name, 2)
	end
)

simulation:register_component(
	"ms_jk_flipflop",
	4,
	2,
	---@param circuit simulation
	---@param name string
	---@param trace boolean
	function(circuit, name, trace)
		local q = name .. "___q"
		local m = name .. "___m"
		local qj = name .. "___qj"
		local qk = name .. "___qk"
		local mj = name .. "___mj"
		local mk = name .. "___mk"
		local lj = name .. "___lj"
		local lk = name .. "___lk"

		circuit
			:new_sr_latch(q, trace)
			:new_sr_latch(m)
			:alias_output(q, 1, name, 1)
			:alias_output(q, 2, name, 2)
			:new_nand(qj)
			:new_nand(qk)
			:_(qj, q, 1)
			:_(qk, q, 2)
			:alias_input(name, 4, qj, 1)
			:alias_input(name, 4, qk, 1)
			:_(m, 1, qj, 2)
			:_(m, 2, qk, 2)
			:new_nand(mj)
			:new_nand(mk)
			:_(mj, m, 1)
			:_(mk, m, 2)
			:alias_input(name, 3, mj, 1)
			:alias_input(name, 3, mk, 1)
			:new_and(lj)
			:new_and(lk)
			:_(lj, mj, 2)
			:_(lk, mk, 2)
			:alias_input(name, 1, lj, 1)
			:alias_input(name, 2, lk, 1)
			:_(q, 1, lk, 2)
			:_(q, 2, lj, 2)
	end
)

simulation:register_component("edge_detector", 1, 2, function(circuit, name, trace)
	-- ~CLK - inverted clock
	circuit:new_not(name .. "___CLK_", trace)
	circuit:alias_input(name, 1, name .. "___CLK_", 1)

	-- CLK_RISING - clock rising edge detector
	circuit
		:new_buffer(name .. "___clk1", trace)
		:alias_input(name, 1, name .. "___clk1", 1)
		:new_buffer(name .. "___clk2", trace)
		:_(name .. "___clk1", name .. "___clk2")
		:new_buffer(name .. "___clk3", trace)
		:_(name .. "___clk2", name .. "___clk3")
		:new_buffer(name .. "___clk4", trace)
		:_(name .. "___clk3", name .. "___clk4")
		:new_buffer(name .. "___clk5", trace)
		:_(name .. "___clk4", name .. "___clk5")
		:new_buffer(name .. "___clk6", trace)
		:_(name .. "___clk5", name .. "___clk6")
		:new_not(name .. "___nclk", trace)
		:_(name .. "___clk6", name .. "___nclk")
		:new_and(name .. "___CLK_RISING", true, trace)
		:alias_input(name, 1, name .. "___CLK_RISING", 1)
		:_(name .. "___nclk", name .. "___CLK_RISING", 2)

	-- CLK_FALLING - clock falling edge detector
	circuit
		:new_buffer(name .. "___clk1_", trace)
		:_(name .. "___CLK_", name .. "___clk1_")
		:new_buffer(name .. "___clk2_", trace)
		:_(name .. "___clk1_", name .. "___clk2_")
		:new_buffer(name .. "___clk3_", trace)
		:_(name .. "___clk2_", name .. "___clk3_")
		:new_buffer(name .. "___clk4_", trace)
		:_(name .. "___clk3_", name .. "___clk4_")
		:new_buffer(name .. "___clk5_", trace)
		:_(name .. "___clk4_", name .. "___clk5_")
		:new_buffer(name .. "___clk6_", trace)
		:_(name .. "___clk5_", name .. "___clk6_")
		:new_not(name .. "___nclk_", trace)
		:_(name .. "___clk6_", name .. "___nclk_")
		:new_and(name .. "___CLK_FALLING", true, trace)
		:_(name .. "___nclk_", name .. "___CLK_FALLING")
		:_(name .. "___CLK_", name .. "___CLK_FALLING")

	circuit:alias_output(name, 1, name .. "___CLK_RISING", 1)
	circuit:alias_output(name, 2, name .. "___CLK_FALLING", 1)
end)

return simulation
