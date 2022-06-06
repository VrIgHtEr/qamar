---@class simulation
---@field new_load_unit fun(circuit:simulation,name:string,opts:table|nil):simulation

local bits = 32
local byte_bits = 8
local control_bits = 2

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"load_unit",
		---@param s simulation
		---@param f string
		---@param opts boolean
		function(s, f, opts)
			opts = opts or { file = nil }
			opts.names = {
				inputs = {
					{ "address", bits },
					{ "control", control_bits },
					"rising",
					"falling",
					"trigin",
					"rst~",
					"sext",
				},
				outputs = { "trigout", { "out", bits } },
			}
			s:add_component(f, opts)

			local sram = f .. ".sram"
			s:new_sram(sram, { file = opts.file, width = bits, data_width = byte_bits })
			s:c("VCC", "q", sram, "oe")
			s:c("GND", "q", sram, "write")

			local sram_pd = f .. ".sram_pd"
			s:new_pulldown(sram_pd, { width = byte_bits }):c(sram_pd, "q", sram, "in")

			local addrmux = f .. ".addrmux"
			s:new_mux_bank(addrmux, { width = 1, bits = bits })
			s:c(f, "address", addrmux, "d0")
			s:c(addrmux, "out", sram, "address")

			local addr = f .. ".addr"
			s:new_ms_d_flipflop_bank(addr, { width = bits })
			s:c(f, "rising", addr, "rising")
			s:c(f, "falling", addr, "falling")
			s:c(f, "rst~", addr, "rst~")
			s:c(addrmux, "out", addr, "d")

			do
				local pti
				for i = 1, bits do
					local ti = f .. ".adder.b" .. (i - 1)
					s:new_half_adder(ti)
					s:cp(1, addr, "q", i, ti, "a", 1)
					if i == 1 then
						s:c("VCC", "q", ti, "b")
					else
						s:c(pti, "carry", ti, "b")
					end
					s:cp(1, ti, "sum", 1, addrmux, "d1", i)
					pti = ti
				end
			end

			local sc = f .. ".sc"
			s:new_and_bank(sc)
			s:c(f, "rising", sc, "a")

			local ctrl = f .. ".ctrl"
			s:new_ms_d_flipflop_bank(ctrl, { width = control_bits })
			s:c(f, "control", ctrl, "d")
			s:c(f, "rst~", ctrl, "rst~")
			s:c(sc, "q", ctrl, "rising")
			s:c(f, "falling", ctrl, "falling")

			local s0 = f .. ".s0"
			s:new_ms_d_flipflop(s0):c(f, "rst~", s0, "rst~"):c(f, "falling", s0, "falling"):c(f, "rising", s0, "rising")
			local s1 = f .. ".s1"
			s:new_ms_d_flipflop(s1):c(f, "rst~", s1, "rst~"):c(f, "falling", s1, "falling"):c(f, "rising", s1, "rising")
			local s2 = f .. ".s2"
			s:new_ms_d_flipflop(s2):c(f, "rst~", s2, "rst~"):c(f, "falling", s2, "falling"):c(f, "rising", s2, "rising")
			local s3 = f .. ".s3"
			s
				:new_ms_d_flipflop(s3)
				:c(f, "rst~", s3, "rst~")
				:c(f, "falling", s3, "falling")
				:c(f, "rising", s3, "rising")
				:c(s2, "q", s3, "d")

			local st = f .. ".st"
			s:new_or(st, { width = 4 })
			s:cp(1, s0, "q", 1, st, "in", 1)
			s:cp(1, s1, "q", 1, st, "in", 2)
			s:cp(1, s2, "q", 1, st, "in", 3)
			s:cp(1, s3, "q", 1, st, "in", 4)
			s:c(st, "q", addrmux, "sel")

			local nst = f .. ".nst"
			s:new_not(nst)
			s:c(st, "q", nst, "a")

			local ti = f .. ".ti"
			s:new_and_bank(ti):c(f, "trigin", ti, "a"):c(nst, "q", ti, "b"):c(ti, "q", sc, "b"):c(ti, "q", s0, "d")

			local oe00 = f .. ".oe00"
			s:new_and(oe00)
			s:cp(2, ctrl, "q~", 1, oe00, "in", 1)
			local oe0 = f .. ".oe0"
			s:new_and(oe0)
			s:cp(1, oe00, "q", 1, oe0, "in", 1)
			s:cp(1, s0, "q", 1, oe0, "in", 2)
			local oe10 = f .. ".oe10"
			s:new_and(oe10)
			s:cp(1, ctrl, "q", 1, oe10, "in", 1)
			s:cp(1, ctrl, "q~", 2, oe10, "in", 2)
			local oe1 = f .. ".oe1"
			s:new_and(oe1)
			s:cp(1, oe10, "q", 1, oe1, "in", 1)
			s:cp(1, s1, "q", 1, oe1, "in", 2)
			local oe = f .. ".oe"
			s:new_or(oe, { width = 3 })
			s:cp(1, oe0, "q", 1, oe, "in", 1)
			s:cp(1, oe1, "q", 1, oe, "in", 2)
			s:cp(1, s3, "q", 1, oe, "in", 3)
			s:c(oe, "q", f, "trigout")

			local noe = f .. ".noe"
			s:new_not(noe):c(oe, "q", noe, "a")

			local a0 = f .. ".a0"
			s:new_and_bank(a0):c(noe, "q", a0, "a"):c(s0, "q", a0, "b"):c(a0, "q", s1, "d")
			local a1 = f .. ".a1"
			s:new_and_bank(a1):c(noe, "q", a1, "a"):c(s1, "q", a1, "b"):c(a1, "q", s2, "d")

			local output = f .. ".output"
			s:new_tristate_buffer(output, { width = bits })
			s:c(output, "q", f, "out")
			s:c(oe, "q", output, "en")

			local lb0 = f .. ".lb0"
			s:new_and_bank(lb0):c(s0, "d", lb0, "a"):c(f, "rising", lb0, "b")
			local lb1 = f .. ".lb1"
			s:new_and_bank(lb1):c(s1, "d", lb1, "a"):c(f, "rising", lb1, "b")
			local lb2 = f .. ".lb2"
			s:new_and_bank(lb2):c(s2, "d", lb2, "a"):c(f, "rising", lb2, "b")
			local lb3 = f .. ".lb3"
			s:new_and_bank(lb3):c(s3, "d", lb3, "a"):c(f, "rising", lb3, "b")

			local b0 = f .. ".b0"
			s:new_ms_d_flipflop_bank(b0, { width = byte_bits })
			s:c(f, "rst~", b0, "rst~")
			s:c(f, "falling", b0, "falling")
			s:c(lb0, "q", b0, "rising")
			s:c(sram, "out", b0, "d")
			s:cp(byte_bits, b0, "q", 1, output, "a", 1)
			local b1 = f .. ".b1"
			s:new_ms_d_flipflop_bank(b1, { width = byte_bits })
			s:c(f, "rst~", b1, "rst~")
			s:c(f, "falling", b1, "falling")
			s:c(lb1, "q", b1, "rising")
			s:c(sram, "out", b1, "d")
			local b2 = f .. ".b2"
			s:new_ms_d_flipflop_bank(b2, { width = byte_bits })
			s:c(f, "rst~", b2, "rst~")
			s:c(f, "falling", b2, "falling")
			s:c(lb2, "q", b2, "rising")
			s:c(sram, "out", b2, "d")
			local b3 = f .. ".b3"
			s:new_ms_d_flipflop_bank(b3, { width = byte_bits })
			s:c(f, "rst~", b3, "rst~")
			s:c(f, "falling", b3, "falling")
			s:c(lb3, "q", b3, "rising")
			s:c(sram, "out", b3, "d")

			local m16 = f .. ".m16"
			s:new_mux_bank(m16, { bits = byte_bits, width = 1 })
			s:cp(byte_bits, m16, "out", 1, output, "a", 9)
			s:c(b1, "q", m16, "d1")
			s:cp(1, ctrl, "q", 1, m16, "sel", 1)
			local m32 = f .. ".m32"
			s:new_mux_bank(m32, { bits = byte_bits * 2, width = 1 })
			s:cp(byte_bits * 2, m32, "out", 1, output, "a", 17)
			s:cp(byte_bits, b2, "q", 1, m32, "d1", 1)
			s:cp(byte_bits, b3, "q", 1, m32, "d1", 9)
			s:cp(1, ctrl, "q", 2, m32, "sel", 1)

			local sext0 = f .. ".sext0"
			s:new_and_bank(sext0)
			s:c(oe00, "q", sext0, "a")
			s:cp(1, b0, "q", byte_bits, sext0, "b", 1)
			local sext1 = f .. ".sext1"
			s:new_and_bank(sext1)
			s:c(oe10, "q", sext1, "a")
			s:cp(1, b1, "q", byte_bits, sext1, "b", 1)
			local sext = f .. ".sext"
			s:new_or_bank(sext)
			s:c(sext0, "q", sext, "a")
			s:c(sext1, "q", sext, "b")
			local sign = f .. ".sign"
			s:new_and_bank(sign)
			s:c(f, "sext", sign, "a")
			s:c(sext, "q", sign, "b")

			for i = 1, 8 do
				s:cp(1, sign, "q", 1, m16, "d0", i)
			end
			for i = 1, 16 do
				s:cp(1, sign, "q", 1, m32, "d0", i)
			end
		end
	)
end
