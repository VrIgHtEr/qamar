---@class simulation
---@field new_instruction_store fun(circuit:simulation,name:string,opts:table|nil):simulation

local WIDTH = 32

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"instruction_store",
		---@param s simulation
		---@param f string
		---@param opts boolean
		function(s, f, opts)
			opts = opts or {}
			opts.names = {
				inputs = {
					"rst~",
					"rising",
					"falling",
					"isched",
					{ "opcode", 7 },
					{ "funct3", 3 },
					{ "d", WIDTH },
					{ "sram_out", 8 },
				},
				outputs = {
					"icomplete",
					"legal",
					"alu_oe",
					"rs1",
					"rs2",
					"imm",
					"sram_oe",
					"sram_write",
					{ "sram_address", WIDTH },
					{ "sram_in", 8 },
					{ "TEST_D", 32 },
				},
			}
			s:add_component(f, opts)

			local nopcode = f .. ".nopcode"
			s:new_not(nopcode, { width = 5 }):cp(5, f, "opcode", 3, nopcode, "a", 1)
			local nf3 = f .. ".nf3"
			s:new_not(nf3, { width = 3 }):c(f, "funct3", nf3, "a")
			local vnf3 = f .. ".vnf3"
			s:new_nand(vnf3):cp(2, f, "funct3", 1, vnf3, "in", 1)

			local a = f .. ".aliases"
			s
				:add_component(a, {
					names = { inputs = {
						"store",
						"load",
						"signed",
						{ "out", WIDTH },
					} },
				})
				:cp(1, f, "opcode", 6, a, "store", 1)
				:cp(1, nopcode, "q", 4, a, "load", 1)
				:cp(1, nf3, "q", 3, a, "signed", 1)
				:c(a, "out", f, "TEST_D")

			local valid_load1 = f .. ".vload1"
			s:new_and(valid_load1):cp(1, nf3, "q", 2, valid_load1, "in", 1):cp(1, f, "funct3", 3, valid_load1, "in", 2)
			local valid_load2 = f .. ".vload2"
			s
				:new_and(valid_load2)
				:cp(1, nf3, "q", 3, valid_load2, "in", 1)
				:cp(1, valid_load1, "q", 1, valid_load2, "in", 2)

			local valid_load = f .. ".vload"
			s:new_and(valid_load)
			s:cp(1, a, "load", 1, valid_load, "in", 1)
			s:cp(1, valid_load2, "q", 1, valid_load, "in", 2)

			local valid_store = f .. ".vstore"
			s:new_and(valid_store)
			s:cp(1, a, "store", 1, valid_store, "in", 1)
			s:cp(1, nf3, "q", 3, valid_store, "in", 2)

			local valid = f .. ".vloadstore"
			s:new_or_bank(valid):c(valid_load, "q", valid, "a"):c(valid_store, "q", valid, "b")

			local legal = f .. ".legal"
			s:new_and(legal, { width = 8 })
			s:cp(2, f, "opcode", 1, legal, "in", 1)
			s:cp(3, nopcode, "q", 1, legal, "in", 3)
			s:cp(1, nopcode, "q", 5, legal, "in", 6)
			s:cp(1, valid, "q", 1, legal, "in", 7)
			s:cp(1, vnf3, "q", 1, legal, "in", 8)

			-- only allow writes
			--s:cp(1, a, "store", 1, legal, "in", 9)

			local legalbuf = f .. ".legalbuf"
			s
				:new_tristate_buffer(legalbuf)
				:c(legal, "q", legalbuf, "en")
				:high(legalbuf, "a")
				:c(legalbuf, "q", f, "legal")

			local visched = f .. ".visched"
			s:new_and(visched):cp(1, f, "isched", 1, visched, "in", 1):cp(1, legal, "q", 1, visched, "in", 2)

			-- STAGE 0
			local stage0 = f .. ".stage0"
			s:new_ms_d_flipflop(stage0)
			s:c(f, "rst~", stage0, "rst~")
			s:c(f, "rising", stage0, "rising")
			s:c(f, "falling", stage0, "falling")
			s:c(visched, "q", stage0, "d")

			local activate_clk = f .. ".activate_clk"
			s:new_and_bank(activate_clk):c(f, "rising", activate_clk, "a"):c(stage0, "q", activate_clk, "b")
			local width_latch = f .. ".width"
			s:new_ms_d_flipflop_bank(width_latch, { width = 2 })
			s:c(f, "rst~", width_latch, "rst~")
			s:c(activate_clk, "q", width_latch, "rising")
			s:c(f, "falling", width_latch, "falling")
			s:cp(2, f, "funct3", 1, width_latch, "d", 1)

			local enable_h = f .. ".h"
			s:new_or(enable_h):c(width_latch, "q", enable_h, "in")

			local is_single_byte = f .. ".sb"
			s:new_not(is_single_byte):c(enable_h, "q", is_single_byte, "a")

			local address = f .. ".address"
			s:new_ms_d_flipflop_bank(address, { width = WIDTH })
			s:c(f, "rst~", address, "rst~")
			s:c(f, "rising", address, "rising")
			s:c(f, "falling", address, "falling")

			local addr_buf = f .. ".address_buf"
			s
				:new_tristate_buffer(addr_buf, { width = WIDTH })
				:c(address, "q", addr_buf, "a")
				:c(addr_buf, "q", f, "sram_address")

			local addr_d_buf = f .. ".addrdbuf"
			s
				:new_tristate_buffer(addr_d_buf, { width = WIDTH })
				:c(f, "d", addr_d_buf, "a")
				:c(stage0, "q", addr_d_buf, "en")
				:c(addr_d_buf, "q", address, "d")

			local inc = f .. ".addrinc"
			s
				:new_ripple_adder(inc, { width = WIDTH })
				:c(address, "q", inc, "a")
				:pulldown(inc, "b", 1)
				:pullup(inc, "cin")

			local addr_inc_buf = f .. ".addrincbuf"
			s
				:new_tristate_buffer(addr_inc_buf, { width = WIDTH })
				:c(inc, "sum", addr_inc_buf, "a")
				:c(stage0, "q~", addr_inc_buf, "en")
				:c(addr_inc_buf, "q", address, "d")

			local load_addr = f .. ".loadaddr"
			s
				:new_tristate_buffer(load_addr, { width = 3 })
				:c(stage0, "q", load_addr, "en")
				:high(load_addr, "a")
				:cp(1, load_addr, "q", 1, f, "rs1", 1)
				:cp(1, load_addr, "q", 2, f, "imm", 1)
				:cp(1, load_addr, "q", 3, f, "alu_oe", 1)

			-- STAGE 1
			local stage1 = f .. ".stage1"
			s:new_ms_d_flipflop(stage1)
			s:c(f, "rst~", stage1, "rst~")
			s:c(f, "rising", stage1, "rising")
			s:c(f, "falling", stage1, "falling")
			s:c(stage0, "q", stage1, "d")

			-- STAGE 2
			local stage2en = f .. ".stage2_en"
			s:new_and_bank(stage2en):c(stage1, "q", stage2en, "a"):c(enable_h, "q", stage2en, "b")
			local nstage2en = f .. ".stage2_en~"
			s:new_not(nstage2en):c(stage2en, "q", nstage2en, "a")
			local stage2 = f .. ".stage2"
			s:new_ms_d_flipflop(stage2)
			s:c(f, "rst~", stage2, "rst~")
			s:c(f, "rising", stage2, "rising")
			s:c(f, "falling", stage2, "falling")
			s:c(stage2en, "q", stage2, "d")

			-- STAGE 3
			local stage3en = f .. ".stage3_en"
			s:new_and_bank(stage3en):c(stage2, "q", stage3en, "a"):cp(1, width_latch, "q", 2, stage3en, "b", 1)
			local nstage3en = f .. ".stage3_en~"
			s:new_not(nstage3en):c(stage3en, "q", nstage3en, "a")
			local stage3 = f .. ".stage3"
			s:new_ms_d_flipflop(stage3)
			s:c(f, "rst~", stage3, "rst~")
			s:c(f, "rising", stage3, "rising")
			s:c(f, "falling", stage3, "falling")
			s:c(stage3en, "q", stage3, "d")

			-- STAGE 4
			local stage4 = f .. ".stage4"
			s:new_ms_d_flipflop(stage4)
			s:c(f, "rst~", stage4, "rst~")
			s:c(f, "rising", stage4, "rising")
			s:c(f, "falling", stage4, "falling")
			s:c(stage3, "q", stage4, "d")

			local comp1 = f .. ".c1"
			s:new_and_bank(comp1):c(stage1, "q", comp1, "a"):c(nstage2en, "q", comp1, "b")
			local comp2 = f .. ".c2"
			s:new_and_bank(comp2):c(stage2, "q", comp2, "a"):c(nstage3en, "q", comp2, "b")
			local comp = f .. ".c"
			s
				:new_or(comp, { width = 3 })
				:cp(1, comp1, "q", 1, comp, "in", 1)
				:cp(1, comp2, "q", 1, comp, "in", 2)
				:cp(1, stage4, "q", 1, comp, "in", 3)

			local stagec = f .. ".stagec"
			s:new_ms_d_flipflop(stagec)
			s:c(f, "rst~", stagec, "rst~")
			s:c(f, "rising", stagec, "rising")
			s:c(f, "falling", stagec, "falling")
			s:c(comp, "q", stagec, "d")

			local icomplete = f .. ".icomplete"
			s:new_tristate_buffer(icomplete):c(stagec, "q", icomplete, "en"):high(icomplete, "a")
			s:c(icomplete, "q", f, "icomplete")

			local active = f .. ".active"
			s
				:new_or(active, { width = 4 })
				:cp(1, stage1, "q", 1, active, "in", 1)
				:cp(1, stage2, "q", 1, active, "in", 2)
				:cp(1, stage3, "q", 1, active, "in", 3)
				:cp(1, stage4, "q", 1, active, "in", 4)
				:c(active, "q", addr_buf, "en")
			local writing = f .. ".writing"
			s:new_and(writing):cp(1, active, "q", 1, writing, "in", 1):cp(1, a, "store", 1, writing, "in", 2)

			local write = f .. ".write"
			s
				:new_tristate_buffer(write, { width = 3 })
				:c(writing, "q", write, "en")
				:cp(1, f, "rising", 1, write, "a", 1)
				:high(write, "a", 2)
				:cp(1, write, "q", 1, f, "sram_write", 1)
				:cp(1, write, "q", 2, f, "rs2", 1)
				:cp(1, write, "q", 3, f, "alu_oe", 1)

			local stage1w = f .. "stage1w"
			s:new_and_bank(stage1w):c(stage1, "q", stage1w, "a"):c(writing, "q", stage1w, "b")
			local b0 = f .. ".b0"
			s
				:new_tristate_buffer(b0, { width = 8 })
				:c(stage1w, "q", b0, "en")
				:cp(8, f, "d", 1, b0, "a", 1)
				:cp(8, b0, "q", 1, f, "sram_in", 1)
			local stage2w = f .. "stage2w"
			s:new_and_bank(stage2w):c(stage2, "q", stage2w, "a"):c(writing, "q", stage2w, "b")
			local b1 = f .. ".b1"
			s
				:new_tristate_buffer(b1, { width = 8 })
				:c(stage2w, "q", b1, "en")
				:cp(8, f, "d", 9, b1, "a", 1)
				:cp(8, b1, "q", 1, f, "sram_in", 1)
			local stage3w = f .. "stage3w"
			s:new_and_bank(stage3w):c(stage3, "q", stage3w, "a"):c(writing, "q", stage3w, "b")
			local b2 = f .. ".b2"
			s
				:new_tristate_buffer(b2, { width = 8 })
				:c(stage3w, "q", b2, "en")
				:cp(8, f, "d", 17, b2, "a", 1)
				:cp(8, b2, "q", 1, f, "sram_in", 1)
			local stage4w = f .. "stage4w"
			s:new_and_bank(stage4w):c(stage4, "q", stage4w, "a"):c(writing, "q", stage4w, "b")
			local b3 = f .. ".b3"
			s
				:new_tristate_buffer(b3, { width = 8 })
				:c(stage4w, "q", b3, "en")
				:cp(8, f, "d", 25, b3, "a", 1)
				:cp(8, b3, "q", 1, f, "sram_in", 1)

			local reading = f .. ".reading"
			s:new_and(reading):cp(1, active, "q", 1, reading, "in", 1):cp(1, a, "load", 1, reading, "in", 2)

			local stage1r = f .. "stage1r"
			s
				:new_and(stage1r, { width = 3 })
				:cp(1, stage1, "q", 1, stage1r, "in", 1)
				:cp(1, reading, "q", 1, stage1r, "in", 2)
				:cp(1, f, "rising", 1, stage1r, "in", 3)
			local in0 = f .. ".in0"
			s
				:new_ms_d_flipflop_bank(in0, { width = 8 })
				:c(f, "rst~", in0, "rst~")
				:c(f, "falling", in0, "falling")
				:c(stage1r, "q", in0, "rising")
				:c(f, "sram_out", in0, "d")

			local stage2r = f .. "stage2r"
			s
				:new_and(stage2r, { width = 3 })
				:cp(1, stage2, "q", 1, stage2r, "in", 1)
				:cp(1, reading, "q", 1, stage2r, "in", 2)
				:cp(1, f, "rising", 1, stage2r, "in", 3)
			local in1 = f .. ".in1"
			s
				:new_ms_d_flipflop_bank(in1, { width = 8 })
				:c(f, "rst~", in1, "rst~")
				:c(f, "falling", in1, "falling")
				:c(stage2r, "q", in1, "rising")
				:c(f, "sram_out", in1, "d")

			local stage3r = f .. "stage3r"
			s
				:new_and(stage3r, { width = 3 })
				:cp(1, stage3, "q", 1, stage3r, "in", 1)
				:cp(1, reading, "q", 1, stage3r, "in", 2)
				:cp(1, f, "rising", 1, stage3r, "in", 3)
			local in2 = f .. ".in2"
			s
				:new_ms_d_flipflop_bank(in2, { width = 8 })
				:c(f, "rst~", in2, "rst~")
				:c(f, "falling", in2, "falling")
				:c(stage3r, "q", in2, "rising")
				:c(f, "sram_out", in2, "d")

			local stage4r = f .. "stage4r"
			s
				:new_and(stage4r, { width = 3 })
				:cp(1, stage4, "q", 1, stage4r, "in", 1)
				:cp(1, reading, "q", 1, stage4r, "in", 2)
				:cp(1, f, "rising", 1, stage4r, "in", 3)
			local in3 = f .. ".in3"
			s
				:new_ms_d_flipflop_bank(in3, { width = 8 })
				:c(f, "rst~", in3, "rst~")
				:c(f, "falling", in3, "falling")
				:c(stage4r, "q", in3, "rising")
				:c(f, "sram_out", in3, "d")

			local sext1 = f .. ".sext1"
			s:new_and(sext1):cp(1, a, "signed", 1, sext1, "in", 1):cp(1, in0, "q", 7, sext1, "in", 2)

			local out1 = f .. ".out1"
			s:new_mux_bank(out1, { bits = 8 })
			s:c(in0, "q", out1, "d0")
			s:fanout(sext1, "q", 1, out1, "d1", 1, 8)
			s:c(is_single_byte, "q", out1, "sel")

			local sext23 = f .. ".sext23"
			s:new_and(sext23):cp(1, a, "signed", 1, sext23, "in", 1):cp(1, out1, "out", 7, sext23, "in", 2)
			local out23 = f .. ".out23"
			s:new_mux_bank(out23, { bits = 16 })
			s:cp(8, in2, "q", 1, out23, "d0", 1)
			s:cp(8, in3, "q", 1, out23, "d0", 9)
			s:fanout(sext23, "q", 1, out23, "d1", 1, 16)
			s:cp(1, nf3, "q", 2, out23, "sel", 1)

			s:cp(8, in0, "q", 1, a, "out", 1)
			s:cp(8, out1, "out", 1, a, "out", 9)
			s:cp(16, out23, "out", 1, a, "out", 17)
		end
	)
end
