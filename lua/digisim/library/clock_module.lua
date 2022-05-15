---@class simulation
---@field new_clock_module fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"clock_module",
		---@param circuit simulation
		---@param name string
		---@param opts boolean
		function(circuit, name, opts)
			opts = opts or { period = 2, chain_length = 3 }
			opts.names = { inputs = {}, outputs = { "q", "~q", "rising", "falling" } }
			local period = opts.period
			if period == nil then
				period = 2
			end
			if type(period) ~= "number" then
				error("invalid clock period type")
			end
			if period < 2 then
				error("clock period too small")
			end

			local chain_length = opts.chain_length or 3
			if type(chain_length) ~= "number" then
				error("invalid chain_length type")
			end
			chain_length = math.floor(chain_length)
			if chain_length < 1 then
				error("invalid chain_length")
			end

			circuit:add_component(name, nil, opts)
			local clk = name .. "." .. "clk"
			circuit:new_clock(clk, { period = period }):c(clk, "q", name, "q")

			local rising = name .. ".rising"
			local falling = name .. ".falling"
			circuit:new_and_bank(rising):c(rising, "q", name, "rising")
			circuit:new_and_bank(falling):c(falling, "q", name, "falling")

			local a1 = name .. "." .. "a1"
			circuit:new_not(a1):c(clk, "q", a1, "a"):c(a1, "q", name, "~q"):c(clk, "q", rising, "a")

			local b1 = name .. "." .. "b1"
			circuit:new_not(b1):c(a1, "q", b1, "a"):c(a1, "q", falling, "a")

			for i = 2, chain_length do
				local a = name .. ".a" .. i
				local b = name .. ".b" .. i

				circuit:new_buffer(a):c(a1, "q", a, "a")
				circuit:new_buffer(b):c(b1, "q", b, "a")
				a1, b1 = a, b
			end
			circuit:c(a1, "q", rising, "b")
			circuit:c(b1, "q", falling, "b")
		end
	)
end
