---@class simulation
---@field new_alu fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"alu",
		---@param sim simulation
		---@param alu string
		---@param opts boolean
		function(sim, alu, opts)
			opts = opts or { width = 1 }
			local width = opts.width or 1
			if type(width) ~= "number" then
				error("invalid width type")
			end
			if width < 1 then
				error("invalid width")
			end
			opts.names = {
				inputs = {
					{ "a", width },
					{ "b", width },
					"cin",
					"nota",
					"notb",
					{ "sel", 2 },
					{ "oe" },
				},
				outputs = {
					{ "out", width },
					"carry",
					"zero",
				},
			}

			sim:add_component(alu, nil, opts)
			local n = alu .. "."
			local f0 = n .. "adder"
			local f1 = n .. "and"
			local f2 = n .. "or"
			local f3 = n .. "xor"
			local zero = n .. "zero"
			local xa = n .. "xa"
			local xb = n .. "xb"
			local lm = n .. "lm"
			local out = n .. "out"

			-- zero flag
			if width == 1 then
				sim:new_not(zero)
				sim:cp(1, alu, "out", 1, zero, "a", 1)
			else
				sim:new_nor(zero, { width = width })
				sim:cp(width, alu, "out", 1, zero, "in", 1)
			end
			sim:c(zero, "q", alu, "zero")

			--output tristate buffer
			sim:new_tristate_buffer(out, { width = width })
			sim:c(alu, "oe", out, "en")
			sim:c(out, "q", alu, "out")

			-- output multiplexer, selects either the adder, AND, OR or XOR output
			sim:new_mux_bank(lm, { width = 2, bits = width })
			sim:c(alu, "sel", lm, "sel")
			sim:c(lm, "out", out, "a")

			--- conditional inverter for input A
			sim:new_xor_bank(xa, { width = width })
			sim:c(alu, "a", xa, "a")
			for i = 1, width do
				sim:cp(1, alu, "nota", 1, xa, "b", i)
			end

			--- conditional inverter for input B
			sim:new_xor_bank(xb, { width = width })
			sim:c(alu, "b", xb, "a")
			for i = 1, width do
				sim:cp(1, alu, "notb", 1, xb, "b", i)
			end

			--arithmetic section
			sim:new_ripple_adder(f0, { width = width })
			sim:c(xa, "q", f0, "a")
			sim:c(xb, "q", f0, "b")
			sim:cp(1, alu, "cin", 1, f0, "cin", 1)
			sim:cp(1, f0, "carry", 1, alu, "carry", 1)
			sim:c(f0, "sum", lm, "d0")

			-- AND section
			sim:new_and_bank(f1, { width = width })
			sim:c(xa, "q", f1, "a")
			sim:c(xb, "q", f1, "b")
			sim:c(f1, "q", lm, "d1")

			-- OR section
			sim:new_or_bank(f2, { width = width })
			sim:c(xa, "q", f2, "a")
			sim:c(xb, "q", f2, "b")
			sim:c(f2, "q", lm, "d2")

			-- XOR section
			sim:new_xor_bank(f3, { width = width })
			sim:c(xa, "q", f3, "a")
			sim:c(xb, "q", f3, "b")
			sim:c(f3, "q", lm, "d3")
			return sim
		end
	)
end
