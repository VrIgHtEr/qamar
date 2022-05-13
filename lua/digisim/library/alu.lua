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

			circuit:new_nor(zero, { width = width })
			circuit:cp(width, alu, "out", 1, zero, "in", 1)
			circuit:c(zero, "q", alu, "zero")

			circuit:new_ripple_adder(adder, { width = width })
			circuit:cp(1, alu, "cin", 1, adder, "cin", 1)
			circuit:cp(width, adder, "sum", 1, alu, "out", 1)
			circuit:cp(1, adder, "carry", 1, alu, "carry", 1)

			for i = 1, width do
				local xa = n .. "xa" .. (i - 1)
				circuit:new_xor(xa)
				circuit:cp(1, alu, "a", i, xa, "in", 1)
				circuit:cp(1, alu, "nota", 1, xa, "in", 2)
				circuit:cp(1, xa, "q", 1, adder, "a", i)

				local xb = n .. "xb" .. (i - 1)
				circuit:new_xor(xb)
				circuit:cp(1, alu, "b", i, xb, "in", 1)
				circuit:cp(1, alu, "notb", 1, xb, "in", 2)
				circuit:cp(1, xb, "q", 1, adder, "b", i)
			end
		end
	)
end
