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
				},
				outputs = {
					"icomplete",
					"legal",
					"rs1",
					"rs2",
					"imm",
					"sram_oe",
					"sram_write",
					{ "sram_address", WIDTH },
					{ "sram_in", 8 },
				},
			}
			s:add_component(f, opts)

			local nopcode = f .. ".nopcode"
			s:new_not(nopcode, { width = 5 }):cp(5, f, "opcode", 3, nopcode, "a", 1)
			local nf3 = f .. ".nf3"
			s:new_not(nf3, { width = 3 }):c(f, "funct3", nf3, "a")
			local vnf3 = f .. ".vnf3"
			s:new_nand(vnf3):cp(2, f, "funct3", 1, vnf3, "in", 1)
			local legal = f .. ".legal"
			s:new_and(legal, { width = 9 })
			s:cp(2, f, "opcode", 1, legal, "in", 1)
			s:cp(3, nopcode, "q", 1, legal, "in", 3)
			s:cp(1, f, "opcode", 6, legal, "in", 6)
			s:cp(1, nopcode, "q", 5, legal, "in", 7)
			s:cp(1, nf3, "q", 3, legal, "in", 8)
			s:cp(1, vnf3, "q", 1, legal, "in", 9)

			local legalbuf = f .. ".legalbuf"
			s
				:new_tristate_buffer(legalbuf)
				:c(legal, "q", legalbuf, "en")
				:high(legalbuf, "a")
				:c(legalbuf, "q", f, "legal")

			local visched = f .. ".visched"
			s:new_and(visched):cp(1, f, "isched", 1, visched, "in", 1):cp(1, legal, "q", 1, visched, "in", 2)
			local nvisched = f .. ".visched~"
			s:new_not(nvisched):c(visched, "q", nvisched, "a")

			local activate_clk = f .. "activate_clk"
			s:new_and_bank(activate_clk):c(f, "rising", activate_clk, "a"):c(visched, "q", activate_clk, "b")
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

			local addr_d_buf = f .. ".addrdbuf"
			s
				:new_tristate_buffer(addr_d_buf, { width = WIDTH })
				:c(f, "d", addr_d_buf, "a")
				:c(visched, "q", addr_d_buf, "en")
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
				:c(nvisched, "q", addr_inc_buf, "en")
				:c(addr_inc_buf, "q", address, "d")

			-- STAGE 0
			local stage0 = f .. ".stage0"
			s:new_ms_d_flipflop(stage0)
			s:c(f, "rst~", stage0, "rst~")
			s:c(f, "rising", stage0, "rising")
			s:c(f, "falling", stage0, "falling")
			s:c(visched, "q", stage0, "d")

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

			local icomplete = f .. ".icomplete"
			s:new_tristate_buffer(icomplete):c(comp, "q", icomplete, "en"):high(icomplete, "a")
			s:c(icomplete, "q", f, "icomplete")
		end
	)
end
