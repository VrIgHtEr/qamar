local signal = require("digisim.signal")
local pin = require("digisim.pin")

---@class component
---@field name string
---@field inputs pin[]
---@field outputs pin[]
---@field step function
---@field trace boolean
---@field trace_inputs boolean
local component = {}
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

return component
