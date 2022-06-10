---@class simulation
---@field new_core fun(circuit:simulation,name:string,opts:table|nil):simulation

local BUS_WIDTH = 32
local BYTE_BITS = 8
local REGISTER_SELECT_WIDTH = 5
local PERIOD = 512

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"core",
		---@param s simulation
		---@param core string
		---@param opts boolean
		function(s, core, opts)
			opts = opts or { trace = nil, file = nil }
			opts.names = {
				inputs = { "rst~" },
			}
			s:add_component(core, opts)
			------------------------------------------------------------------------------
			local clk = core .. ".clock"
			s:new_clock_module(clk, { period = PERIOD, chain_length = 2, trace = opts.trace })
			------------------------------------------------------------------------------
			local control = core .. ".control"
			s:add_component(control, {
				trace = opts.trace,
				names = {
					outputs = {
						"rst~",
						"alu_notb",
						"alu_cin",
						"alu_u",
						"lu_sext",
						"lu_trigin",
						"alu_oe",
						"alu_lt",
						"xu_trigin",
						"isched",
						"sram_write",
						"sram_oe",
						"branch",
						"imm_oe",
						"rd_oe",
						"rs1_oe",
						"rs2_oe",
						"pc_oe",
						"legal",
						"zero",
						{ "alu_sel", 3 },
						{ "lu_control", 2 },
						{ "ireg", BUS_WIDTH },
						{ "pc", BUS_WIDTH },
					},
				},
			})
			s:c(core, "rst~", control, "rst~")
			s:pullup(control, "sram_oe")
			s:pulldown(control, "alu_u")
			s:pulldown(control, "legal")
			s:pulldown(control, "alu_lt")
			s:pulldown(control, "alu_notb")
			s:pulldown(control, "alu_cin")
			s:pulldown(control, "alu_oe")
			s:pulldown(control, "lu_sext")
			s:pulldown(control, "isched")
			s:pulldown(control, "branch")
			s:pulldown(control, "lu_trigin")
			s:pulldown(control, "imm_oe")
			s:pulldown(control, "pc_oe")
			s:pulldown(control, "rs1_oe")
			s:pulldown(control, "rs2_oe")
			s:pulldown(control, "rd_oe")
			s:pulldown(control, "xu_trigin")
			s:pulldown(control, "zero")
			s:pulldown(control, "sram_write")
			s:pulldown(control, "lu_control", 1, 2)
			s:pulldown(control, "ireg", 1, BUS_WIDTH)
			s:pulldown(control, "pc", 1, BUS_WIDTH)
			s:pulldown(control, "alu_sel", 1, 3)
			------------------------------------------------------------------------------
			local kickstarter = core .. ".kickstarter"
			s:new_kickstarter(kickstarter, { trace = opts.trace })
			s:c(control, "rst~", kickstarter, "rst~")
			s:c(clk, "rising", kickstarter, "rising")
			s:c(clk, "falling", kickstarter, "falling")
			s:c(kickstarter, "branch", control, "branch")
			s:c(kickstarter, "icomplete", control, "xu_trigin")
			------------------------------------------------------------------------------
			local buses = core .. ".buses"
			s:add_component(buses, {
				names = {
					inputs = {},
					outputs = {
						{ "a", BUS_WIDTH },
						{ "b", BUS_WIDTH },
						{ "d", BUS_WIDTH },
						{ "sram_address", BUS_WIDTH },
						{ "sram_in", BYTE_BITS },
						{ "sram_out", BYTE_BITS },
					},
				},
				trace = opts.trace,
			})
			s:pulldown(buses, "a", 1, BUS_WIDTH)
			s:pulldown(buses, "b", 1, BUS_WIDTH)
			s:pulldown(buses, "d", 1, BUS_WIDTH)
			s:pulldown(buses, "sram_address", 1, BUS_WIDTH)
			s:pulldown(buses, "sram_in", 1, BYTE_BITS)
			s:pulldown(buses, "sram_out", 1, BYTE_BITS)
			------------------------------------------------------------------------------
			local sram = core .. ".sram"
			s:new_sram(sram, { file = opts.file, width = BUS_WIDTH, data_width = BYTE_BITS })
			s:c(control, "sram_oe", sram, "oe")
			s:c(control, "sram_write", sram, "write")
			s:c(buses, "sram_address", sram, "address")
			s:c(buses, "sram_in", sram, "in")
			s:c(sram, "out", buses, "sram_out")
			------------------------------------------------------------------------------
			local lu = core .. ".lu"
			s:new_load_unit(lu, { trace = opts.trace })
			s
				:c(clk, "rising", lu, "rising")
				:c(clk, "falling", lu, "falling")
				:c(buses, "d", lu, "address")
				:c(control, "lu_control", lu, "control")
				:c(control, "lu_trigin", lu, "trigin")
				:c(control, "rst~", lu, "rst~")
				:c(control, "lu_sext", lu, "sext")
				:c(buses, "sram_out", lu, "sram_out")
				:c(buses, "sram_address", lu, "sram_address")
				:c(lu, "out", buses, "d")
			------------------------------------------------------------------------------
			local pc = core .. ".pc"
			s:new_program_counter(pc, { trace = opts.trace })
			s:c(control, "rst~", pc, "rst~")
			s:c(clk, "rising", pc, "rising")
			s:c(clk, "falling", pc, "falling")
			s:c(control, "branch", pc, "branch")
			s:c(control, "xu_trigin", pc, "icomplete")
			s:c(control, "pc_oe", pc, "oe_a")
			s:c(buses, "d", pc, "d")
			s:c(buses, "a", pc, "a")
			s:c(pc, "pc", control, "pc")
			------------------------------------------------------------------------------
			local xu = core .. ".xu"
			s:new_execution_unit(xu, { trace = opts.trace })
			s:c(buses, "d", xu, "d")
			s:c(clk, "rising", xu, "rising")
			s:c(clk, "falling", xu, "falling")
			s:c(control, "rst~", xu, "rst~")
			s:c(control, "xu_trigin", xu, "trigin")
			s:c(lu, "trigout", xu, "lu_trigout")
			s:c(xu, "ireg", control, "ireg")
			s:c(xu, "isched", control, "isched")
			s:c(xu, "lu_control", control, "lu_control")
			s:c(xu, "lu_trigin", control, "lu_trigin")
			------------------------------------------------------------------------------
			local idecode = core .. ".idecode"
			s:new_instruction_decoder(idecode, { trace = opts.trace })
			s:c(control, "rs1_oe", idecode, "rs1_oe")
			s:c(control, "rs2_oe", idecode, "rs2_oe")
			s:c(control, "rd_oe", idecode, "rd_oe")
			s:c(control, "imm_oe", idecode, "oe")
			s:c(control, "ireg", idecode, "in")
			s:c(idecode, "imm", buses, "b")
			------------------------------------------------------------------------------
			local alu = core .. ".alu"
			s:new_alu(alu, { width = BUS_WIDTH, trace = opts.trace })
			s:c(control, "alu_notb", alu, "notb")
			s:c(control, "alu_cin", alu, "cin")
			s:c(control, "alu_u", alu, "u")
			s:c(control, "alu_oe", alu, "oe")
			s:c(control, "alu_sel", alu, "sel")
			s:c(buses, "a", alu, "a")
			s:c(buses, "b", alu, "b")
			s:c(alu, "out", buses, "d")
			s:c(alu, "zero", control, "zero")
			s:c(alu, "lt", control, "alu_lt")
			------------------------------------------------------------------------------
			local registers = core .. ".registers"
			s:new_register_bank(registers, { width = BUS_WIDTH, selwidth = REGISTER_SELECT_WIDTH, trace = opts.trace })
			s
				:c(control, "rst~", registers, "~rst")
				:c(clk, "rising", registers, "rising")
				:c(buses, "d", registers, "in")
				:c(idecode, "rs1", registers, "sela")
				:c(idecode, "rs2", registers, "selb")
				:c(idecode, "rd", registers, "selw")
				:c(registers, "outa", buses, "a")
				:c(registers, "outb", buses, "b")
			------------------------------------------------------------------------------
			local i_op = core .. ".instructions.op"
			s:new_instruction_op(i_op, { trace = opts.trace })
			s:c(control, "rst~", i_op, "rst~")
			s:c(clk, "rising", i_op, "rising")
			s:c(clk, "falling", i_op, "falling")
			s:c(control, "isched", i_op, "isched")
			s:c(idecode, "funct7", i_op, "funct7")
			s:c(idecode, "funct3", i_op, "funct3")
			s:c(idecode, "opcode", i_op, "opcode")
			s:c(i_op, "icomplete", control, "xu_trigin")
			s:c(i_op, "alu_sel", control, "alu_sel")
			s:c(i_op, "alu_oe", control, "alu_oe")
			s:c(i_op, "rd", control, "rd_oe")
			s:c(i_op, "rs1", control, "rs1_oe")
			s:c(i_op, "rs2", control, "rs2_oe")
			s:c(i_op, "imm_oe", control, "imm_oe")
			s:c(i_op, "alu_notb", control, "alu_notb")
			s:c(i_op, "alu_cin", control, "alu_cin")
			s:c(i_op, "legal", control, "legal")
			------------------------------------------------------------------------------
			local i_branch = core .. ".instructions.branch"
			s:new_instruction_branch(i_branch, { trace = opts.trace })
			s:c(control, "rst~", i_branch, "rst~")
			s:c(clk, "rising", i_branch, "rising")
			s:c(clk, "falling", i_branch, "falling")
			s:c(control, "isched", i_branch, "isched")
			s:c(control, "zero", i_branch, "zero")
			s:c(control, "alu_lt", i_branch, "lt")
			s:c(idecode, "opcode", i_branch, "opcode")
			s:c(idecode, "funct3", i_branch, "funct3")
			s:c(i_branch, "icomplete", control, "xu_trigin")
			s:c(i_branch, "legal", control, "legal")
			s:c(i_branch, "alu_oe", control, "alu_oe")
			s:c(i_branch, "rs1", control, "rs1_oe")
			s:c(i_branch, "rs2", control, "rs2_oe")
			s:c(i_branch, "imm_oe", control, "imm_oe")
			s:c(i_branch, "alu_notb", control, "alu_notb")
			s:c(i_branch, "alu_cin", control, "alu_cin")
			s:c(i_branch, "alu_u", control, "alu_u")
			s:c(i_branch, "branch", control, "branch")
			s:c(i_branch, "pc_oe", control, "pc_oe")
			------------------------------------------------------------------------------
			local i_ui = core .. ".instructions.ui"
			s:new_instruction_ui(i_ui, { trace = opts.trace })
			s:c(control, "rst~", i_ui, "rst~")
			s:c(clk, "rising", i_ui, "rising")
			s:c(clk, "falling", i_ui, "falling")
			s:c(control, "isched", i_ui, "isched")
			s:c(idecode, "opcode", i_ui, "opcode")
			s:c(i_ui, "icomplete", control, "xu_trigin")
			s:c(i_ui, "legal", control, "legal")
			s:c(i_ui, "alu_oe", control, "alu_oe")
			s:c(i_ui, "rd", control, "rd_oe")
			s:c(i_ui, "imm_oe", control, "imm_oe")
			s:c(i_ui, "pc_oe", control, "pc_oe")
			------------------------------------------------------------------------------
			local i_load = core .. ".instructions.load"
			s:new_instruction_load(i_load, { trace = opts.trace })
			s:c(control, "rst~", i_load, "rst~")
			s:c(clk, "rising", i_load, "rising")
			s:c(clk, "falling", i_load, "falling")
			s:c(control, "isched", i_load, "isched")
			s:c(lu, "trigout", i_load, "lu_trigout")
			s:c(idecode, "opcode", i_load, "opcode")
			s:c(idecode, "funct3", i_load, "funct3")
			s:c(i_load, "icomplete", control, "xu_trigin")
			s:c(i_load, "legal", control, "legal")
			s:c(i_load, "imm_oe", control, "imm_oe")
			s:c(i_load, "rs1", control, "rs1_oe")
			s:c(i_load, "rs2", control, "rs2_oe")
			s:c(i_load, "rd", control, "rd_oe")
			s:c(i_load, "alu_oe", control, "alu_oe")
			s:c(i_load, "lu_trigin", control, "lu_trigin")
			s:c(i_load, "lu_sext", control, "lu_sext")
			s:c(i_load, "lu_control", control, "lu_control")
			------------------------------------------------------------------------------
			local i_store = core .. ".instructions.store"
			s:new_instruction_store(i_store, { trace = opts.trace })
			s:c(control, "rst~", i_store, "rst~")
			s:c(clk, "rising", i_store, "rising")
			s:c(clk, "falling", i_store, "falling")
			s:c(control, "isched", i_store, "isched")
			s:c(idecode, "opcode", i_store, "opcode")
			s:c(idecode, "funct3", i_store, "funct3")
			s:c(i_store, "icomplete", control, "xu_trigin")
			s:c(i_store, "legal", control, "legal")
			------------------------------------------------------------------------------
			local i_jal = core .. ".instructions.jal"
			s:new_instruction_jal(i_jal, { trace = opts.trace })
			s:c(control, "rst~", i_jal, "rst~")
			s:c(clk, "rising", i_jal, "rising")
			s:c(clk, "falling", i_jal, "falling")
			s:c(control, "isched", i_jal, "isched")
			s:c(idecode, "opcode", i_jal, "opcode")
			s:c(i_jal, "icomplete", control, "xu_trigin")
			s:c(i_jal, "legal", control, "legal")
			s:c(i_jal, "pc_oe", control, "pc_oe")
			s:cp(1, i_jal, "b4", 1, buses, "b", 3)
			s:c(i_jal, "alu_oe", control, "alu_oe")
			s:c(i_jal, "rd", control, "rd_oe")
			s:c(i_jal, "imm_oe", control, "imm_oe")
			s:c(i_jal, "branch", control, "branch")
			------------------------------------------------------------------------------
			local i_jalr = core .. ".instructions.jalr"
			s:new_instruction_jalr(i_jalr, { trace = opts.trace })
			s:c(control, "rst~", i_jalr, "rst~")
			s:c(clk, "rising", i_jalr, "rising")
			s:c(clk, "falling", i_jalr, "falling")
			s:c(control, "isched", i_jalr, "isched")
			s:c(idecode, "opcode", i_jalr, "opcode")
			s:c(idecode, "funct3", i_jalr, "funct3")
			s:c(buses, "d", i_jalr, "d")
			s:c(i_jalr, "icomplete", control, "xu_trigin")
			s:c(i_jalr, "legal", control, "legal")
			s:c(i_jalr, "pc_oe", control, "pc_oe")
			s:cp(1, i_jalr, "b4", 1, buses, "b", 3)
			s:c(i_jalr, "alu_oe", control, "alu_oe")
			s:c(i_jalr, "rd", control, "rd_oe")
			s:c(i_jalr, "rs1", control, "rs1_oe")
			s:c(i_jalr, "imm_oe", control, "imm_oe")
			s:c(i_jalr, "branch", control, "branch")
			------------------------------------------------------------------------------
			local i_fence = core .. ".instructions.fence"
			s:new_instruction_fence(i_fence, { trace = opts.trace })
			s:c(control, "rst~", i_fence, "rst~")
			s:c(clk, "rising", i_fence, "rising")
			s:c(clk, "falling", i_fence, "falling")
			s:c(control, "isched", i_fence, "isched")
			s:c(idecode, "opcode", i_fence, "opcode")
			s:c(i_fence, "icomplete", control, "xu_trigin")
			s:c(i_fence, "legal", control, "legal")
			------------------------------------------------------------------------------
			local i_system = core .. ".instructions.system"
			s:new_instruction_system(i_system, { trace = opts.trace })
			s:c(control, "rst~", i_system, "rst~")
			s:c(clk, "rising", i_system, "rising")
			s:c(clk, "falling", i_system, "falling")
			s:c(control, "isched", i_system, "isched")
			s:c(idecode, "opcode", i_system, "opcode")
			s:c(i_system, "icomplete", control, "xu_trigin")
			s:c(i_system, "legal", control, "legal")
		end
	)
end
