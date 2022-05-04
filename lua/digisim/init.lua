---@class simulation
---@field components table<string,component>
---@field connections table<string,connection>
---@field queue deque
---@field time number
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
	local pin = {}
	do
		---@class pin
		---@field name string
		---@field value signal
		---@field timestamp number
		---@field component component
		---@field connections table<string,connection>
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

	local component = {}
	do
		---@class component
		---@field name string
		---@field inputs pin[]
		---@field outputs pin[]
		---@field step function
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
	local connection = {}
	do
		---@class connection
		---@field name string
		---@field a pin
		---@field b pin
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
		}, MT)
		return ret
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

	function simulation:add_component(name, inputs, outputs, handler)
		if type(name) ~= "string" or not name:match("^[a-zA-Z_][a-zA-Z0-9_]*$") then
			error("invalid name")
		end
		if self.components[name] then
			error("component already exists: " .. name)
		end
		local c = component.new(name, inputs, outputs, handler)
		self.components[name] = c
		return self
	end

	function simulation:and_gate(name)
		return self:add_component(name, 2, 1, function(_, a, b)
			return (a == signal.high and b == signal.high) and signal.high or signal.low
		end)
	end

	function simulation:or_gate(name)
		return self:add_component(name, 2, 1, function(_, a, b)
			return (a == signal.high or b == signal.high) and signal.high or signal.low
		end)
	end

	function simulation:not_gate(name)
		return self:add_component(name, 1, 1, function(_, a)
			return a == signal.low and signal.high or signal.low
		end)
	end

	function simulation:step()
		print("---------------------------------------------------------")

		---@type table<string,component>
		local dirty = {}
		local count = 0
		for name, x in pairs(self.components) do
			if #x.inputs == 0 then
				dirty[name] = x
				count = count + 1
			end
		end
		if count == 0 then
			error("must have at least one component with zero inputs")
		end
		print(self.time)
		repeat
			local nextdirty = {}
			local nextcount = 0
			for _, c in pairs(dirty) do
				local inputs = {}
				for i, x in ipairs(c.inputs) do
					inputs[i] = x.value
				end
				local outputs = { c.step(self.time, unpack(inputs)) }
				for i, value in ipairs(outputs) do
					local output = c.outputs[i]
					if output.value ~= value then
						output.value = value
						output.timestamp = self.time + 1
						print(output.timestamp .. ":" .. output.name .. ":" .. output.value)
						for _, conn in pairs(output.connections) do
							if not nextdirty[conn.b.component.name] then
								nextdirty[conn.b.component.name] = conn.b.component
								nextcount = nextcount + 1
							end
							if conn.b.timestamp > self.time + 1 then
								error("future time")
							end
							if conn.b.timestamp <= self.time then
								conn.b.timestamp = self.time + 1
								conn.b.value = value
								print(conn.b.timestamp .. ":" .. conn.b.name .. ":" .. conn.b.value)
							else
								conn.b.timestamp = self.time + 1
								if
									conn.b.value == value
									or conn.b.value == signal.unknown
									or conn.b.value == signal.z
								then
									conn.b.value = value
								elseif
									conn.b.value == signal.low and value == signal.high
									or value == signal.low and conn.b.value == signal.high
								then
									error("mixed signals!!!")
								else
									conn.b.value = value
									print(conn.b.timestamp .. ":" .. conn.b.name .. ":" .. conn.b.value)
								end
							end
						end
					end
				end
			end
			dirty = nextdirty
			count = nextcount
			self.time = self.time + 1
		until count == 0
		return self
	end
end

do
	vim.api.nvim_exec("mes clear", true)

	local sim = simulation.new()

	local base = 8
	sim
		:or_gate("top_or")
		:or_gate("bottom_or")
		:not_gate("top_not")
		:not_gate("bottom_not")
		:add_component("RESET", 0, 1, function(ts)
			local mod = ts % (base * 4)
			return (mod < base) and signal.high or signal.low
		end)
		:add_component("SET", 0, 1, function(ts)
			local mod = ts % (base * 4)
			return mod >= (base * 2) and mod < (base * 3) and signal.high or signal.low
		end)
		:add_component("OUTPUT", 1, 0, function()
			--	print(ts .. ":Q:" .. v)
		end)
		:add_component("INVERTED_OUTPUT", 1, 0, function()
			--	print(ts .. ":_Q:" .. v)
		end)
		:connect("top_or", 1, "top_not", 1)
		:connect("bottom_or", 1, "bottom_not", 1)
		:connect("bottom_not", 1, "top_or", 2)
		:connect("top_not", 1, "bottom_or", 1)
		:connect("RESET", 1, "top_or", 1)
		:connect("SET", 1, "bottom_or", 2)
		:connect("top_not", 1, "OUTPUT", 1)
		:connect("bottom_not", 1, "INVERTED_OUTPUT", 1)
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
		:step()
end

return simulation
