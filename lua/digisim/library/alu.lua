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
					"notb",
					{ "sel", 3 },
					{ "oe" },
					"u",
				},
				outputs = {
					{ "out", width },
					"zero",
					"lt",
				},
			}

			sim:add_component(alu, opts)
			local n = alu .. "."
			local zero = n .. "zero"
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

			sim:new_mux_bank(lm, { width = 3, bits = width })
			sim:c(alu, "sel", lm, "sel")
			sim:c(lm, "out", out, "a")

			--- conditional inverter for input B
			sim:new_xor_bank(xb, { width = width })
			sim:c(alu, "b", xb, "a")
			for i = 1, width do
				sim:cp(1, alu, "notb", 1, xb, "b", i)
			end

			--arithmetic section
			local f0 = alu .. ".adder"
			sim:new_ripple_adder(f0, { width = width })
			sim:c(alu, "a", f0, "a")
			sim:c(xb, "q", f0, "b")
			sim:cp(1, alu, "cin", 1, f0, "cin", 1)
			sim:c(f0, "sum", lm, "d0")

			local nsel2 = alu .. ".nsel2"
			sim:new_not(nsel2):cp(1, alu, "sel", 3, nsel2, "a", 1)
			local f15 = alu .. ".sll"
			sim:new_barrel_shifter(f15, { width = 5 })
			sim:c(nsel2, "q", f15, "left")
			sim:c(alu, "cin", f15, "arithmetic")
			sim:c(alu, "a", f15, "a")
			sim:cp(5, alu, "b", 1, f15, "b", 1)
			sim:c(f15, "q", lm, "d1")
			sim:c(f15, "q", lm, "d5")

			local f2 = alu .. ".slt"
			sim:new_pulldown(f2, { width = width }):c(f2, "q", lm, "d2")

			local f3 = alu .. ".sltu"
			sim:new_pulldown(f3, { width = width }):c(f3, "q", lm, "d3")

			local f4 = alu .. ".xor"
			sim:new_xor_bank(f4, { width = width })
			sim:c(alu, "a", f4, "a")
			sim:c(xb, "q", f4, "b")
			sim:c(f4, "q", lm, "d4")

			local f6 = alu .. ".or"
			sim:new_or_bank(f6, { width = width })
			sim:c(alu, "a", f6, "a")
			sim:c(xb, "q", f6, "b")
			sim:c(f6, "q", lm, "d6")

			local f7 = alu .. ".and"
			sim:new_and_bank(f7, { width = width })
			sim:c(alu, "a", f7, "a")
			sim:c(xb, "q", f7, "b")
			sim:c(f7, "q", lm, "d7")

			local comparator = alu .. ".comparator"
			sim:new_comparator(comparator, { width = width })
			sim:cp(width - 1, alu, "a", 1, comparator, "a", 1)
			sim:cp(width - 1, alu, "b", 1, comparator, "b", 1)

			local s = alu .. ".signed"
			sim:new_and_bank(s):c(alu, "u", s, "a")

			local cx = alu .. ".cx"
			sim
				:new_xor_bank(cx, { width = 2 })
				:cp(1, s, "q", 1, cx, "a", 1)
				:cp(1, s, "q", 1, cx, "a", 2)
				:cp(1, alu, "a", width, cx, "b", 1)
				:cp(1, alu, "b", width, cx, "b", 2)
				:cp(1, cx, "q", 1, comparator, "a", width)
				:cp(1, cx, "q", 2, comparator, "b", width)

			local lt = alu .. ".lt"
			sim:new_not(lt):c(comparator, "q", lt, "a"):c(lt, "q", alu, "lt")
		end
	)
end
