---@class simulation
---@field new_sram fun(circuit:simulation,name:string,opts:table|nil):simulation

local bit = require("bit")
local signal = require("digisim.signal")

local function read_file(path)
	local file, err, data = io.open(path, "rb")
	if not file then
		return nil, err
	end
	data, err = file:read("*a")
	file:close()
	return data, err
end

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"sram",
		---@param sim simulation
		---@param sram string
		---@param opts boolean
		function(sim, sram, opts)
			opts = opts or { width = 1, data_width = 8, file = nil }
			local width = opts.width or 1
			if type(width) ~= "number" then
				error("invalid width type")
			end
			if width < 1 then
				error("invalid width")
			end
			local data_width = 8
			opts.names = {
				inputs = {
					{ "address", width },
					"oe",
					"write",
					{ "in", data_width },
				},
				outputs = { { "out", data_width } },
			}

			local prevWrite = signal.unknown
			local z = {}
			for i = 1, data_width do
				z[i] = signal.z
			end

			local memory = {}
			if opts.file then
				local data, err = read_file(opts.file)
				if not data then
					error(err)
				else
					for i = 1, data:len() do
						memory[i - 1] = string.byte(string.sub(data, i, i))
					end
				end
			end

			local paddress = nil
			local pval = nil
			local poe = nil

			local file = io.open(opts.file, "r+")

			sim:add_component(sram, opts, function(_, a, oe, write, input)
				local address = 0
				for i, x in ipairs(a) do
					address = bit.bor(address, bit.lshift(x, i - 1))
				end
				local data = 0
				for i, x in ipairs(input) do
					data = bit.bor(data, bit.lshift(x, i - 1))
				end
				if prevWrite == signal.low and write == signal.high then
					memory[address] = data
					if file ~= nil then
						file:seek("set", address)
						file:write(string.char(data))
						file:flush()
					end
					io.stderr:write("WRITE : " .. data .. " : " .. address .. "\n")
				end
				prevWrite = write
				if oe == signal.high then
					local ret = {}
					local val = memory[address] or 0
					for i = 0, data_width - 1 do
						ret[i + 1] = bit.band(1, bit.rshift(val, i))
					end
					if address ~= paddress or val ~= pval or poe ~= oe then
						paddress = address
						pval = val
						--						io.stderr:write("READ : " .. address .. " : " .. val .. "\n")
					end
					return ret
				else
					return z
				end
				poe = oe
			end)
			return sim
		end
	)
end
