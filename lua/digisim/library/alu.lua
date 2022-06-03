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
			local xa = n .. "xa"
			local xb = n .. "xb"
			local lm = n .. "lm"
			local out = n .. "out"

			--output tristate buffer
			sim:new_tristate_buffer(out, { width = width })
			sim:c(alu, "oe", out, "en")
			sim:c(out, "q", alu, "out")

			sim:new_mux_bank(lm, { width = 3, bits = width })
			sim:c(alu, "sel", lm, "sel")
			sim:c(lm, "out", out, "a")

			-- zero flag
			if width == 1 then
				sim:new_not(zero)
				sim:cp(1, lm, "d0", 1, zero, "a", 1)
			else
				sim:new_nor(zero, { width = width })
				sim:cp(width, lm, "d0", 1, zero, "in", 1)
			end
			sim:c(zero, "q", alu, "zero")

			--- conditional inverter for input A
			sim:new_xor_bank(xa, { width = width })
			sim:c(alu, "a", xa, "a")

			--- conditional inverter for input B
			sim:new_xor_bank(xb, { width = width })
			sim:c(alu, "b", xb, "a")
			sim:fanout(alu, "notb", 1, xb, "b", 1, width)

			--arithmetic section
			local f0 = alu .. ".adder"
			sim:new_ripple_adder(f0, { width = width })
			sim:c(xa, "q", f0, "a")
			sim:c(xb, "q", f0, "b")
			sim:cp(1, alu, "cin", 1, f0, "cin", 1)
			sim:c(f0, "sum", lm, "d0")

			local nsel2 = alu .. ".nsel2"
			sim:new_not(nsel2):cp(1, alu, "sel", 3, nsel2, "a", 1)
			local f15 = alu .. ".sll"
			sim:new_barrel_shifter(f15, { width = 5 })
			sim:c(nsel2, "q", f15, "left")
			sim:c(alu, "cin", f15, "arithmetic")
			sim:c(xa, "q", f15, "a")
			sim:cp(5, xb, "q", 1, f15, "b", 1)
			sim:c(f15, "q", lm, "d1")
			sim:c(f15, "q", lm, "d5")

			--slt/u
			local comp = alu .. ".comp"
			sim:new_comparator(comp, { width = width })
			sim:cp(width - 1, xa, "q", 1, comp, "a", 1)
			sim:cp(width - 1, xb, "q", 1, comp, "b", 1)
			local inva = alu .. ".inva"
			sim:new_and_bank(inva):c(nsel2, "q", inva, "a"):cp(1, alu, "sel", 2, inva, "b", 1)
			sim:fanout(inva, "q", 1, xa, "b", 1, width)
			--slt
			sim:cp(1, comp, "q", 1, lm, "d2", 1)
			sim:pulldown(lm, "d2", 2, width - 1)
			--sltu
			sim:cp(1, comp, "q", 1, lm, "d3", 1)
			sim:pulldown(lm, "d3", 2, width - 1)

			local f4 = alu .. ".xor"
			sim:new_xor_bank(f4, { width = width })
			sim:c(xa, "q", f4, "a")
			sim:c(xb, "q", f4, "b")
			sim:c(f4, "q", lm, "d4")

			local f6 = alu .. ".or"
			sim:new_or_bank(f6, { width = width })
			sim:c(xa, "q", f6, "a")
			sim:c(xb, "q", f6, "b")
			sim:c(f6, "q", lm, "d6")

			local f7 = alu .. ".and"
			sim:new_and_bank(f7, { width = width })
			sim:c(xa, "q", f7, "a")
			sim:c(xb, "q", f7, "b")
			sim:c(f7, "q", lm, "d7")

			local u = alu .. ".u"
			sim:new_or_bank(u):c(alu, "u", u, "a"):cp(1, alu, "sel", 1, u, "b", 1)
			local signed = alu .. ".signed"
			sim:new_not(signed):c(u, "q", signed, "a")

			local cx = alu .. ".cx"
			sim
				:new_xor_bank(cx, { width = 2 })
				:cp(1, signed, "q", 1, cx, "a", 1)
				:cp(1, signed, "q", 1, cx, "a", 2)
				:cp(1, xa, "q", width, cx, "b", 1)
				:cp(1, xb, "q", width, cx, "b", 2)
				:cp(1, cx, "q", 1, comp, "a", width)
				:cp(1, cx, "q", 2, comp, "b", width)

			local nzero = alu .. ".nzero"
			sim:new_not(nzero):c(alu, "zero", nzero, "a")
			local a_le_b = alu .. ".a_le_b"
			sim:new_not(a_le_b):c(comp, "q", a_le_b, "a")
			local lt = alu .. ".lt"
			sim:new_and_bank(lt):c(nzero, "q", lt, "a"):c(a_le_b, "q", lt, "b"):c(lt, "q", alu, "lt")
		end
	)
end
