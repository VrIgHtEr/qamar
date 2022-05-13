---@class simulation
---@field new_alu function

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"alu",
		---@param circuit simulation
		---@param alu string
		---@param opts boolean
		function(circuit, alu, opts)
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
				},
				outputs = {
					{ "out", width },
					"carry",
					"zero",
				},
			}

			circuit:add_component(alu, nil, opts)
			local n = alu .. "."
			local f0 = n .. "adder"
			local f1 = n .. "and"
			local f2 = n .. "or"
			local f3 = n .. "xor"
			local zero = n .. "zero"
			local xa = n .. "xa"
			local xb = n .. "xb"
			local lm = n .. "lm"

			-- zero flag
			circuit:new_nor(zero, { width = width })
			circuit:cp(width, alu, "out", 1, zero, "in", 1)
			circuit:c(zero, "q", alu, "zero")

			-- output multiplexer, selects either the adder, AND, OR or XOR output
			circuit:new_mux_bank(lm, { width = 2, bits = width })
			circuit:c(alu, "sel", lm, "sel")
			circuit:c(lm, "out", alu, "out")

			--- conditional inverter for input A
			circuit:new_xor_bank(xa, { width = width })
			circuit:c(alu, "a", xa, "a")
			for i = 1, width do
				circuit:cp(1, alu, "nota", 1, xa, "b", i)
			end

			--- conditional inverter for input B
			circuit:new_xor_bank(xb, { width = width })
			circuit:c(alu, "b", xb, "a")
			for i = 1, width do
				circuit:cp(1, alu, "notb", 1, xb, "b", i)
			end

			--arithmetic section
			circuit:new_ripple_adder(f0, { width = width })
			circuit:c(xa, "q", f0, "a")
			circuit:c(xb, "q", f0, "b")
			circuit:cp(1, alu, "cin", 1, f0, "cin", 1)
			circuit:cp(1, f0, "carry", 1, alu, "carry", 1)
			circuit:c(f0, "sum", lm, "d0")

			-- AND section
			circuit:new_and_bank(f1, { width = width })
			circuit:c(xa, "q", f1, "a")
			circuit:c(xb, "q", f1, "b")
			circuit:c(f1, "q", lm, "d1")

			-- OR section
			circuit:new_or_bank(f2, { width = width })
			circuit:c(xa, "q", f2, "a")
			circuit:c(xb, "q", f2, "b")
			circuit:c(f2, "q", lm, "d2")

			-- XOR section
			circuit:new_xor_bank(f3, { width = width })
			circuit:c(xa, "q", f3, "a")
			circuit:c(xb, "q", f3, "b")
			circuit:c(f3, "q", lm, "d3")
		end
	)
end
