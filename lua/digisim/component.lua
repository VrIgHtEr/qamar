---@diagnostic disable: need-check-nil
local signal = require("digisim.signal")
local pin = require("digisim.pin")

---@class component
---@field name string
---@field inputs pin[]
---@field outputs pin[]
---@field step function
---@field trace boolean
local component = {}
local MT = { __index = component }

function component.new(name, inputs, outputs, handler, opts)
	if type(name) ~= "string" or name == "" then
		error("invalid name")
	end
	if opts == nil then
		if type(handler) == "table" then
			handler, opts = nil, handler
		elseif handler == nil or type(handler) == "function" then
			opts = {}
		else
			error("invalid opts type")
		end
	elseif type(opts) ~= "table" then
		error("invalid opts type")
	end
	if type(inputs) ~= "number" or type(outputs) ~= "number" or (handler ~= nil and type(handler) ~= "function") then
		error("invalid inputs")
	end
	inputs, outputs = math.floor(inputs), math.floor(outputs)
	if inputs < 0 or outputs < 0 or (inputs == 0 and outputs == 0) then
		error("invalid inputs")
	end
	if opts.names == nil then
		opts.names = {}
	elseif type(opts.names) ~= "table" then
		error("invalid opts.names type")
	end
	if opts.names.inputs == nil then
		opts.names.inputs = {}
	elseif type(opts.names.inputs) ~= "table" then
		error("invalid opts.names.inputs type")
	end
	if opts.names.outputs == nil then
		opts.names.outputs = {}
	elseif type(opts.names.outputs) ~= "table" then
		error("invalid opts.names.outputs type")
	end
	local ret = setmetatable({
		name = name,
		inputs = {},
		outputs = {},
	}, MT)
	local names = opts.names.inputs
	for i = 1, inputs do
		local n = names[i]
		if n then
			n = name .. "." .. n
		else
			n = "[" .. i .. "]" .. name
		end
		ret.inputs[i] = pin.new(n, ret, true)
	end
	names = opts.names.outputs
	for i = 1, outputs do
		local n = names[i]
		if n then
			n = name .. "." .. n
		else
			n = name .. "[" .. i .. "]"
		end
		ret.outputs[i] = pin.new(n, ret, false)
	end

	if handler then
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
	end

	return ret
end

return component
