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
				},
				outputs = {
					{ "out", width },
					"carry",
					"zero",
				},
			}

			circuit:add_component(alu, nil, opts)
			local n = alu .. "."
			local adder = n .. "adder"
			local zero = n .. "zero"
			local xa = n .. "xa"
			local xb = n .. "xb"

			circuit:new_nor(zero, { width = width })
			circuit:cp(width, alu, "out", 1, zero, "in", 1)
			circuit:c(zero, "q", alu, "zero")

			circuit:new_ripple_adder(adder, { width = width })
			circuit:cp(1, alu, "cin", 1, adder, "cin", 1)
			circuit:cp(width, adder, "sum", 1, alu, "out", 1)
			circuit:cp(1, adder, "carry", 1, alu, "carry", 1)

			circuit:new_xor_bank(xa, { width = width })
			circuit:c(alu, "a", xa, "a")
			circuit:c(xa, "q", adder, "a")

			circuit:new_xor_bank(xb, { width = width })
			circuit:c(alu, "b", xb, "a")
			circuit:c(xb, "q", adder, "b")

			for i = 1, width do
				circuit:cp(1, alu, "nota", 1, xa, "b", i)
				circuit:cp(1, alu, "notb", 1, xb, "b", i)
			end
		end
	)
end
