local DEBUG_TRACE_ALL_OUTPUTS = false

local STARTUP_TICKS = 12
local CLOCK_PERIOD_TICKS = 32

---@class simulation
---@field components table<string,component>
---@field connections table<string,connection>
---@field queue deque
---@field time number
---@field trace table<string,sample[]>
local simulation = {}
local queue = require("qamar.util.deque")

---@class signal
local signal = {
	BOTTOM = -3,
	unknown = -2,
	z = -1,
	low = 0,
	high = 1,
	TOP = 2,
}

do
	---@class pin
	---@field name string
	---@field value signal
	---@field timestamp number
	---@field component component
	---@field connections table<string,connection>
	local pin = {}
	do
		local MT = { __index = pin }

		function pin.new(name, comp)
			local ret = setmetatable({
				name = name,
				timestamp = 0,
				value = signal.unknown,
				connections = {},
				component = comp,
			}, MT)
			return ret
		end
	end

	---@class component
	---@field name string
	---@field inputs pin[]
	---@field outputs pin[]
	---@field step function
	---@field trace boolean
	---@field trace_inputs boolean
	local component = {}
	do
		local MT = { __index = component }

		function component.new(name, inputs, outputs, handler)
			if type(name) ~= "string" or name == "" then
				error("invalid name")
			end
			if type(inputs) ~= "number" or type(outputs) ~= "number" or type(handler) ~= "function" then
				error("invalid inputs")
			end
			inputs, outputs = math.floor(inputs), math.floor(outputs)
			if inputs < 0 or outputs < 0 or (inputs == 0 and outputs == 0) then
				error("invalid inputs")
			end
			local ret = setmetatable({
				name = name,
				inputs = {},
				outputs = {},
			}, MT)
			for i = 1, inputs do
				ret.inputs[i] = pin.new("[" .. i .. "]" .. name, ret)
			end
			for i = 1, outputs do
				ret.outputs[i] = pin.new(name .. "[" .. i .. "]", ret)
			end

			function ret.step(timestamp, ...)
				local parts = { ... }
				for i = 1, #parts do
					if parts[i] == signal.unknown or parts[i] == signal.z then
						parts[i] = math.random(0, 1)
					end
				end
				local o = { handler(timestamp, unpack(parts)) }
				if #o ~= outputs then
					error("handler " .. name .. " returned " .. #o .. " outputs but expected " .. outputs)
				end
				for i, x in ipairs(o) do
					if type(x) ~= "number" then
						error("handler " .. name .. " returned invalid type " .. type(x) .. " at index " .. i)
					end
					x = math.floor(x)
					if x <= signal.unknown or x >= signal.TOP then
						error("handler " .. name .. " returned invalid value " .. x .. " at index " .. i)
					end
				end
				return unpack(o)
			end

			return ret
		end
	end

	---@class connection
	---@field name string
	---@field a pin
	---@field b pin
	local connection = {}
	do
		local MT = { __index = connection }

		---@param name string
		---@param a pin
		---@param b pin
		---@return connection
		function connection.new(name, a, b)
			local ret = setmetatable({
				name = name,
				a = a,
				b = b,
			}, MT)
			a.connections[name] = ret
			b.connections[name] = ret
			return ret
		end
	end

	local MT = { __index = simulation }

	function simulation.new()
		local ret = setmetatable({
			components = {},
			connections = {},
			time = 0,
			next_connection_id = 0,
			queue = queue(),
			trace = {},
		}, MT)
		return ret
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
				if vim.tbl_count(x.connections) == 0 then
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

	function simulation:add_component(name, inputs, outputs, handler, trace, trace_inputs)
		if type(name) ~= "string" or not name:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
			error("invalid name")
		end
		if self.components[name] then
			error("component already exists: " .. name)
		end
		local c = component.new(name, inputs, outputs, handler)
		c.trace = trace and true or false or DEBUG_TRACE_ALL_OUTPUTS
		c.trace_inputs = trace_inputs and true or false
		self.components[name] = c
		return self
	end

	function simulation:new_nand(name, trace, trace_inputs)
		return self:add_component(name, 2, 1, function(_, a, b)
			return (a == signal.high and b == signal.high) and signal.low or signal.high
		end, trace, trace_inputs)
	end

	function simulation:new_nor(name, trace, trace_inputs)
		return self:add_component(name, 2, 1, function(_, a, b)
			return (a == signal.high or b == signal.high) and signal.low or signal.high
		end, trace, trace_inputs)
	end

	function simulation:new_xnor(name, trace, trace_inputs)
		return self:add_component(name, 2, 1, function(_, a, b)
			return (a == signal.high and b == signal.low or a == signal.low and b == signal.high) and signal.low
				or signal.high
		end, trace, trace_inputs)
	end

	function simulation:new_and(name, trace, trace_inputs)
		return self:add_component(name, 2, 1, function(_, a, b)
			return (a == signal.high and b == signal.high) and signal.high or signal.low
		end, trace, trace_inputs)
	end

	function simulation:new_xor(name, trace, trace_inputs)
		return self:add_component(name, 2, 1, function(_, a, b)
			return (a == signal.high and b == signal.low or a == signal.low and b == signal.high) and signal.high
				or signal.low
		end, trace, trace_inputs)
	end

	function simulation:new_or(name, trace, trace_inputs)
		return self:add_component(name, 2, 1, function(_, a, b)
			return (a == signal.high or b == signal.high) and signal.high or signal.low
		end, trace, trace_inputs)
	end

	function simulation:new_not(name, trace, trace_inputs)
		return self:add_component(name, 1, 1, function(_, a)
			return a == signal.low and signal.high or signal.low
		end, trace, trace_inputs)
	end

	function simulation:new_buffer(name, trace, trace_inputs)
		return self:add_component(name, 1, 1, function(_, a)
			return a
		end, trace, trace_inputs)
	end

	---@class sample
	---@field time number
	---@field value signal

	local function add_trace(sim, name, time, sig)
		local trace = sim.trace[name]
		if not trace then
			trace = {}
			sim.trace[name] = trace
		end
		table.insert(trace, { time = time, value = sig })
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
				local inputs = {}
				for i, x in ipairs(c.inputs) do
					inputs[i] = x.value
				end
				local outputs = { c.step(self.time, unpack(inputs)) }
				for i, value in ipairs(outputs) do
					local output = c.outputs[i]
					if output.value ~= value then
						if c.trace then
							add_trace(self, output.name, self.time, value)
						end
						output.value = value
						output.timestamp = self.time
						--prt(output.timestamp .. ":" .. vim.inspect(inputs) .. ":" .. output.name .. ":" .. output.value)
						for _, conn in pairs(output.connections) do
							if not nextdirty[conn.b.component.name] then
								nextdirty[conn.b.component.name] = conn.b.component
								nextcount = nextcount + 1
							end
							if conn.b.timestamp > self.time then
								error("future time")
							end
							if conn.b.timestamp <= self.time then
								conn.b.timestamp = self.time
								if conn.b.value ~= value and conn.b.component.trace_inputs then
									add_trace(self, conn.b.name, self.time, value)
								end
								conn.b.value = value
								--prt(string.rep(" ", tostring(conn.b.timestamp):len()) .. " " .. conn.b.name)
							else
								conn.b.timestamp = self.time
								if conn.b.value ~= value then
									if conn.b.value == signal.unknown or conn.b.value == signal.z then
										if conn.b.component.trace_inputs then
											add_trace(self, conn.b.name, self.time, value)
										end
										conn.b.value = value
										--prt(string.rep(" ", tostring(conn.b.timestamp):len()) .. " " .. conn.b.name)
									elseif
										conn.b.value == signal.low and value == signal.high
										or value == signal.low and conn.b.value == signal.high
									then
										error("mixed signals!!!")
									else
										conn.b.value = value
										if conn.b.component.trace_inputs then
											add_trace(self, conn.b.name, self.time, value)
										end
										--prt(string.rep(" ", tostring(conn.b.timestamp):len()) .. " " .. conn.b.name)
									end
								end
							end
						end
					else
						--if #output.component.inputs > 0 then prt( self.time .. ":" .. vim.inspect(inputs) .. ":" .. output.name .. ":" .. output.value .. ":SAME") end
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
end

do
	vim.api.nvim_exec("mes clear", true)

	local circuit = simulation.new()

	-- ~RST - inverted reset signal. Only low for the first "startup_ticks" ticks. High otherwise
	circuit:add_component("RST_", 0, 1, function(time)
		return time < STARTUP_TICKS and signal.low or signal.high
	end, true)

	-- CLK - clock with period "clock_period_ticks"
	circuit:add_component("CLK", 0, 1, function(ts)
		ts = ts % CLOCK_PERIOD_TICKS
		return ts < CLOCK_PERIOD_TICKS / 2 and signal.low or signal.high
	end, true)

	-- ~CLK - inverted clock
	circuit:new_not("CLK_"):_("CLK", "CLK_")

	-- CLK_RISING - clock rising edge detector
	circuit
		:new_buffer("clk1")
		:_("CLK", "clk1")
		:new_buffer("clk2")
		:_("clk1", "clk2")
		:new_buffer("clk3")
		:_("clk2", "clk3")
		:new_buffer("clk4")
		:_("clk3", "clk4")
		:new_buffer("clk5")
		:_("clk4", "clk5")
		:new_buffer("clk6")
		:_("clk5", "clk6")
		:new_not("nclk")
		:_("clk6", "nclk")
		:new_and("CLK_RISING", true)
		:_("nclk", "CLK_RISING")
		:_("CLK", "CLK_RISING")

	-- CLK_FALLING - clock falling edge detector
	circuit
		:new_buffer("clk1_")
		:_("CLK_", "clk1_")
		:new_buffer("clk2_")
		:_("clk1_", "clk2_")
		:new_buffer("clk3_")
		:_("clk2_", "clk3_")
		:new_buffer("clk4_")
		:_("clk3_", "clk4_")
		:new_buffer("clk5_")
		:_("clk4_", "clk5_")
		:new_buffer("clk6_")
		:_("clk5_", "clk6_")
		:new_not("nclk_")
		:_("clk6_", "nclk_")
		:new_and("CLK_FALLING", true)
		:_("nclk_", "CLK_FALLING")
		:_("CLK_", "CLK_FALLING")

	-- slave SR latch
	circuit
		:new_nand("Q", true)
		:new_nand("Q_", true)
		:_("Q", "Q_")
		:_("Q_", "Q")
		:new_nand("S")
		:new_nand("S_")
		:_("S", "Q")
		:_("S_", "Q_")
		:_("CLK_FALLING", "S")
		:_("CLK_FALLING", "S_")

	-- master SR latch
	circuit
		:new_nand("M")
		:new_nand("M_")
		:_("M", "M_")
		:_("M_", "M")
		:_("M", "S")
		:_("M_", "S_")
		:new_nand("C")
		:new_nand("C_")
		:_("C", "M")
		:_("C_", "M_")
		:_("CLK_RISING", "C")
		:_("CLK_RISING", "C_")
		:new_and("J")
		:new_and("K")
		:_("J", "C")
		:_("K", "C_")
		:_("Q", "K")
		:_("Q_", "J")

	-- data pin
	circuit:add_component("DATA", 0, 1, function(time)
		return time * 0.5 % CLOCK_PERIOD_TICKS < CLOCK_PERIOD_TICKS / 2 and signal.low or signal.high
	end, true)

	-- connect data pin to jk flip flop
	circuit:new_not("ND"):_("DATA", "ND")
	circuit:_("DATA", "J")
	circuit:_("ND", "K")

	for _ = 1, CLOCK_PERIOD_TICKS * 3 do
		circuit:step()
	end

	local max = 0
	local maxtime = 0
	for k, t in pairs(circuit.trace) do
		if k:sub(1, 1) ~= "[" then
			max = math.max(max, k:len())
			maxtime = math.max(maxtime, t[#t].time)
		end
	end
	maxtime = maxtime + CLOCK_PERIOD_TICKS
	max = max + 2
	local traces = {}
	for k in pairs(circuit.trace) do
		if k:sub(1, 1) ~= "[" then
			table.insert(
				traces,
				table.concat({ k, ": ", string.rep(" ", max - (k:len() + 2)), circuit:get_trace(k, maxtime) })
			)
		end
	end
	max = 0
	for _, x in ipairs(traces) do
		max = math.max(max, x:len())
	end
	max = max + 5

	table.sort(traces)
	local first = true
	local lines = {}
	for _, x in ipairs(traces) do
		if first then
			first = false
		else
			table.insert(lines, "--")
			--			print("--")
		end
		table.insert(lines, "--" .. x)
		--		print(x)
	end

	table.insert(lines, "")
	vim.api.nvim_buf_set_text(vim.api.nvim_get_current_buf(), -1, 0, -1, 0, lines)
end

return simulation

--[[
]]
