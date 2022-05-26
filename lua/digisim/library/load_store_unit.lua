---@class simulation
---@field new_load_store_unit fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"load_store_unit",
		---@param s simulation
		---@param f string
		---@param opts boolean
		function(s, f, opts)
			opts = opts or { file = nil }
			opts.names = {
				inputs = {
					{ "address", 32 },
					"rising",
					"falling",
					"trigin",
					"b16",
					"b32",
					"rst~",
					"sext",
				},
				outputs = { "trigout", { "out", 32 } },
			}
			s:add_component(f, opts)

			local trig = f .. ".trig"
			local s0 = f .. ".s0"
			local s1 = f .. ".s1"
			local s2 = f .. ".s2"
			local s3 = f .. ".s3"
			local control = f .. ".control"
			local address = f .. ".address"
			local sram = f .. ".sram"
			local t = f .. ".t"

			do
				local ct = f .. ".ct"
				s:new_and_bank(ct):c(f, "rising", ct, "a"):c(f, "trigin", ct, "b")
				local startclk = f .. ".startclk"
				s:new_and_bank(startclk):c(ct, "q", startclk, "a")
				local nstarted = f .. ".nstarted"
				s:new_nor(nstarted, { width = 4 })
				local nstartedorfinished = f .. ".nstartedorfinished"
				s
					:new_or_bank(nstartedorfinished)
					:c(nstarted, "q", nstartedorfinished, "a")
					:c(f, "trigout", nstartedorfinished, "b")
					:c(nstartedorfinished, "q", startclk, "b")
				s:new_and_bank(trig):c(f, "trigin", trig, "a"):c(nstartedorfinished, "q", trig, "b")

				local smux = f .. ".smux"
				s:new_mux_bank(smux, { width = 1, bits = 32 })
				s:c(trig, "q", smux, "sel")
				s:c(f, "address", smux, "d1")

				s:new_sram(sram, { width = 32, file = opts.file })
				s:c("VCC", "q", sram, "oe")
				s:c("GND", "q", sram, "write")
				s:c(smux, "out", sram, "address")

				s:new_ms_d_flipflop_bank(control, { width = 2 })
				s:cp(1, f, "b16", 1, control, "d", 1)
				s:cp(1, f, "b32", 1, control, "d", 2)
				s:c(startclk, "q", control, "rising")
				s:c(f, "falling", control, "falling")
				s:c(f, "rst~", control, "rst~")

				local amux = f .. ".amux"
				s:new_mux_bank(amux, { bits = 32, width = 1 })
				s:c(trig, "q", amux, "sel")
				s:c(f, "address", amux, "d1")
				s:new_ms_d_flipflop_bank(address, { width = 32 })
				s:c(amux, "out", address, "d")
				s:c(f, "rising", address, "rising")
				s:c(f, "falling", address, "falling")
				s:c(f, "rst~", address, "rst~")
				s:c(address, "q", smux, "d0")

				local pd
				for i = 1, 32 do
					local d = f .. ".increment.a" .. (i - 1)
					s:new_half_adder(d)
					s:cp(1, d, "sum", 1, amux, "d0", i)
					s:cp(1, address, "q", i, d, "a", 1)
					if i == 1 then
						s:c("VCC", "q", d, "b")
					else
						s:c(pd, "carry", d, "b")
					end
					pd = d
				end

				local f8 = f .. ".f8"
				s:new_and(f8):cp(2, control, "q~", 1, f8, "in", 1)
				local f16 = f .. ".f16"
				s:new_and(f16):cp(1, control, "q", 1, f16, "in", 1):cp(1, control, "q~", 2, f16, "in", 2)
				local f32 = f .. ".f32"
				s:new_and(f32):cp(2, control, "q", 1, f32, "in", 1)
				s
					:new_ms_d_flipflop(s0)
					:c(trig, "q", s0, "d")
					:c(f, "rising", s0, "rising")
					:c(f, "falling", s0, "falling")
					:c(f, "rst~", s0, "rst~")
					:cp(1, s0, "q", 1, nstarted, "in", 1)
				local bs0 = f .. ".bs0"
				s:new_and_bank(bs0):c(s0, "q", bs0, "a"):cp(1, control, "q", 1, bs0, "b", 1)
				s
					:new_ms_d_flipflop(s1)
					:c(bs0, "q", s1, "d")
					:c(f, "rising", s1, "rising")
					:c(f, "falling", s1, "falling")
					:c(f, "rst~", s1, "rst~")
					:cp(1, s1, "q", 1, nstarted, "in", 2)
				local bs1 = f .. ".bs1"
				s:new_and_bank(bs1):c(s1, "q", bs1, "a"):cp(1, control, "q", 2, bs1, "b", 1)
				s
					:new_ms_d_flipflop(s2)
					:c(bs1, "q", s2, "d")
					:c(f, "rising", s2, "rising")
					:c(f, "falling", s2, "falling")
					:c(f, "rst~", s2, "rst~")
					:cp(1, s2, "q", 1, nstarted, "in", 3)
				local bs2 = f .. ".bs2"
				s:new_and_bank(bs2):c(s2, "q", bs2, "a"):cp(1, control, "q", 2, bs2, "b", 1)
				s
					:new_ms_d_flipflop(s3)
					:c(bs2, "q", s3, "d")
					:c(f, "rising", s3, "rising")
					:c(f, "falling", s3, "falling")
					:c(f, "rst~", s3, "rst~")
					:cp(1, s3, "q", 1, nstarted, "in", 4)

				local trigout = f .. ".trigout"
				s:new_or(trigout, { width = 3 }):c(trigout, "q", f, "trigout")
				local trigout0 = trigout .. 0
				s
					:new_and_bank(trigout0)
					:cp(1, trigout0, "q", 1, trigout, "in", 1)
					:c(s0, "q", trigout0, "a")
					:c(f8, "q", trigout0, "b")
				local trigout1 = trigout .. 1
				s
					:new_and_bank(trigout1)
					:cp(1, trigout1, "q", 1, trigout, "in", 2)
					:c(s1, "q", trigout1, "a")
					:c(f16, "q", trigout1, "b")
				local trigout3 = trigout .. 3
				s
					:new_and_bank(trigout3)
					:cp(1, trigout3, "q", 1, trigout, "in", 3)
					:c(s3, "q", trigout3, "a")
					:c(f32, "q", trigout3, "b")

				s:new_tristate_buffer(t, { width = 32 })
				s:c(f, "trigout", t, "en")
				s:c(t, "q", f, "out")

				local m1 = f .. ".m1"
				s:new_mux_bank(m1, { bits = 8, width = 1 })
				s:cp(8, m1, "out", 1, t, "a", 9)
				local m1s = f .. ".m1s"
				s:new_or_bank(m1s):c(f16, "q", m1s, "a"):c(f32, "q", m1s, "b")
				s:cp(1, m1s, "q", 1, m1, "sel", 1)
				local m3 = f .. ".m3"
				s:new_mux_bank(m3, { bits = 16, width = 1 })
				s:cp(16, m3, "out", 1, t, "a", 17)
				s:cp(1, f32, "q", 1, m3, "sel", 1)

				local w0 = f .. ".w0"
				s:new_and_bank(w0):c(f, "rising", w0, "a"):c(s0, "q", w0, "b")
				local b0 = f .. ".b0"
				s
					:new_ms_d_flipflop_bank(b0, { width = 8 })
					:c(sram, "out", b0, "d")
					:c(f, "rst~", b0, "rst~")
					:cp(8, b0, "q", 1, t, "a", 1)
					:c(w0, "q", b0, "rising")
					:c(f, "falling", b0, "falling")
				local w1 = f .. ".w1"
				s:new_and_bank(w1):c(f, "rising", w1, "a"):c(s1, "q", w1, "b")
				local b1 = f .. ".b1"
				s
					:new_ms_d_flipflop_bank(b1, { width = 8 })
					:c(sram, "out", b1, "d")
					:c(f, "rst~", b1, "rst~")
					:cp(8, b1, "q", 1, m1, "d1", 1)
					:c(w1, "q", b1, "rising")
					:c(f, "falling", b1, "falling")
				local w2 = f .. ".w2"
				s:new_and_bank(w2):c(f, "rising", w2, "a"):c(s2, "q", w2, "b")
				local b2 = f .. ".b2"
				s
					:new_ms_d_flipflop_bank(b2, { width = 8 })
					:c(sram, "out", b2, "d")
					:c(f, "rst~", b2, "rst~")
					:cp(8, b2, "q", 1, m3, "d1", 1)
					:c(w2, "q", b2, "rising")
					:c(f, "falling", b2, "falling")
				local w3 = f .. ".w3"
				s:new_and_bank(w3):c(f, "rising", w3, "a"):c(s3, "q", w3, "b")
				local b3 = f .. ".b3"
				s
					:new_ms_d_flipflop_bank(b3, { width = 8 })
					:c(sram, "out", b3, "d")
					:c(f, "rst~", b3, "rst~")
					:cp(8, b3, "q", 1, m3, "d1", 9)
					:c(w3, "q", b3, "rising")
					:c(f, "falling", b3, "falling")

				local padding = f .. ".padding"
				s:new_or_bank(padding)
				local padding0 = padding .. 0
				s:new_and_bank(padding0)
				s:c(padding0, "q", padding, "a")
				s:c(f16, "q", padding0, "a")
				s:cp(1, b0, "q", 8, padding0, "b", 1)
				local padding1 = padding .. 1
				s:new_and_bank(padding1)
				s:c(padding1, "q", padding, "b")
				s:c(f32, "q", padding1, "a")
				s:cp(1, b1, "q", 8, padding1, "b", 1)
				for i = 1, 8 do
					s:cp(1, padding, "q", 1, m1, "d0", i)
				end
				for i = 1, 16 do
					s:cp(1, padding, "q", 1, m3, "d0", i)
				end
			end
		end
	)
end
