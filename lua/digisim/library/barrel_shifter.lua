---@class simulation
---@field new_barrel_shifter fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"barrel_shifter",
		---@param sim simulation
		---@param shift string
		---@param opts boolean
		function(sim, shift, opts)
			opts = opts or { width = 1 }
			local width = opts.width or 1
			if type(width) ~= "number" or width < 1 or width > 16 then
				error("invalid width type")
			end
			width = math.floor(width)
			local num_bits = math.pow(2, width)
			opts.names = {
				inputs = {
					{ "a", num_bits },
					{ "b", width },
					"arithmetic",
					"left",
				},
				outputs = {
					{ "q", num_bits },
				},
			}
			sim:add_component(shift, opts)

			local n = shift .. "."

			local input = n .. "input"
			sim:new_mux_bank(input, { bits = num_bits, width = 1 })
			sim:c(shift, "left", input, "sel")
			sim:c(shift, "a", input, "d0")
			for i = 1, num_bits do
				sim:cp(1, shift, "a", i, input, "d1", num_bits - i + 1)
			end

			for i = 1, width do
				local shift_amt = math.pow(2, i - 1)
				local s = n .. "s" .. (i - 1)
				sim:new_mux_bank(s, { bits = num_bits, width = 1 })
				sim:cp(1, shift, "b", i, s, "sel", 1)
				local prev = i == 1 and input or (n .. "s" .. (i - 2))
				sim:c(prev, "out", s, "d0")
				sim:cp(num_bits - shift_amt, prev, "out", shift_amt + 1, s, "d1", 1)
				local a = n .. "a" .. (i - 1)
				sim:new_and(a)
				sim:cp(1, shift, "arithmetic", 1, a, "in", 1)
				sim:cp(1, prev, "out", num_bits, a, "in", 2)
				for j = num_bits - shift_amt + 1, num_bits do
					sim:cp(1, a, "q", 1, s, "d1", j)
				end
			end

			local output = n .. "output"
			sim:new_mux_bank(output, { bits = num_bits, width = 1 })
			sim:c(shift, "left", output, "sel")
			sim:c(output, "out", shift, "q")

			local last = n .. "s" .. (width - 1)
			sim:c(last, "out", output, "d0")
			for i = 1, num_bits do
				sim:cp(1, last, "out", i, output, "d1", num_bits - i + 1)
			end

			return sim
		end
	)
end
