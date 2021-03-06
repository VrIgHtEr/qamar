---@diagnostic disable: need-check-nil
local signal = require("digisim.signal")
local port = require("digisim.port")
local DEBUG_MODE = require("digisim.constants").DEBUG_MODE

---@class component
---@field name string
---@field ports table<string,port>
---@field inports port[]
---@field outports port[]
---@field step function
---@field trace boolean
local component = {}
local MT = { __index = component }

function component.new(name, handler, opts)
	if type(name) ~= "string" or name == "" then
		error("invalid name")
	end
	opts = opts or {}
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
		inports = {},
		outports = {},
		ports = {},
	}, MT)
	local names = opts.names.inputs
	local inputs = #names
	for i = 1, inputs do
		local pinname
		local n = names[i]
		local width

		if type(n) == "string" then
			width = 1
			pinname = n
		elseif type(n) ~= "table" or #n == 0 then
			error("invalid port definition")
		elseif #n < 2 then
			width = 1
			pinname = n[1]
			if type(pinname) ~= "string" then
				error("invalid port definition")
			end
		elseif type(n[1]) ~= "string" or type(n[2]) ~= "number" then
			error("invalid port definition")
		else
			width = math.floor(n[2])
			pinname = n[1]
			if width < 1 then
				error("invalid port definition")
			end
		end
		n = name .. "." .. pinname

		ret.inports[i] = port.new(n, width, ret, true)
		ret.ports[pinname] = ret.inports[i]
	end
	names = opts.names.outputs
	local outputs = #names
	for i = 1, outputs do
		local pinname
		local n = names[i]
		local width

		if type(n) == "string" then
			width = 1
			pinname = n
		elseif type(n) ~= "table" or #n == 0 then
			error("invalid port definition")
		elseif #n < 2 then
			width = 1
			pinname = n[1]
			if type(pinname) ~= "string" then
				error("invalid port definition")
			end
		elseif type(n[1]) ~= "string" or type(n[2]) ~= "number" then
			error("invalid port definition")
		else
			width = math.floor(n[2])
			pinname = n[1]
			if width < 1 then
				error("invalid port definition")
			end
		end
		n = name .. "." .. pinname

		ret.outports[i] = port.new(n, width, ret, false)
		ret.ports[pinname] = ret.outports[i]
	end

	if handler then
		function ret.step(timestamp, ...)
			local parts = { ... }
			for i = 1, #parts do
				if type(parts[i]) == "table" then
					for j, x in ipairs(parts[i]) do
						if x == signal.unknown or x == signal.z then
							parts[i][j] = 0 --math.random(0, 1)
						end
					end
				elseif parts[i] == signal.unknown or parts[i] == signal.z then
					parts[i] = 0 --math.random(0, 1)
				end
			end
			local o = { handler(timestamp, unpack(parts)) }
			if #o < outputs or (#parts == 0 and #o > outputs + 1 or #parts > 0 and #o > outputs) then
				error("handler " .. name .. " returned " .. #o .. " outputs but expected " .. outputs)
			end
			if DEBUG_MODE then
				for i = 1, outputs do
					local x = o[i]
					if type(x) == "number" then
						x = math.floor(x)
						if x <= signal.unknown or x >= signal.TOP then
							error("handler " .. name .. " returned invalid value " .. x .. " at index " .. i)
						end
					elseif type(x) == "table" then
						if ret.outports[i].bits ~= #x then
							error(
								"Component "
									.. ret.name
									.. " returned "
									.. #x
									.. " bits in output "
									.. i
									.. " (expected "
									.. ret.outports[i].bits
									.. ")"
							)
						end
						for j, v in ipairs(x) do
							if type(v) ~= "number" then
								error(
									"handler "
										.. name
										.. " returned invalid type "
										.. type(v)
										.. " at index "
										.. i
										.. "["
										.. j
										.. "]"
								)
							end
							v = math.floor(v)
							if v <= signal.BOTTOM or v >= signal.TOP then
								error(
									"handler "
										.. name
										.. " returned invalid value "
										.. v
										.. " at index "
										.. i
										.. "["
										.. j
										.. "]"
								)
							end
						end
					else
						error("handler " .. name .. " returned invalid type " .. type(x) .. " at index " .. i)
					end
				end
			end
			local sleep = o[outputs + 1]
			if sleep ~= nil then
				if type(sleep) ~= "number" or sleep < 0 then
					error("invalid sleep period")
				end
				sleep = math.floor(sleep)
			else
				sleep, o[outputs + 1] = 0, 0
			end
			return unpack(o)
		end
	end

	return ret
end

return component
