---@class simulation
---@field new_core fun(circuit:simulation,name:string,opts:table|nil):simulation

local BUS_WIDTH = 32
local REGISTER_SELECT_WIDTH = 5
local PERIOD = 256

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
				inputs = {
					"rst~",
				},
				outputs = { "q" },
			}
			s:add_component(core, opts)

			local control = core .. ".control"
			s:add_component(control, {
				trace = opts.trace,
				names = {
					outputs = {
						"rst~",
						"alu_notb",
						"alu_cin",
						"lsu_sext",
						"lsu_trigin",
						"alu_oe",
						"xu_trigin",
						"isched",
						"branch",
						"imm_oe",
						"rd_oe",
						"rs1_oe",
						"rs2_oe",
						"pc_oe",
						"legal",
						{ "lsu_control", 2 },
						{ "ireg", BUS_WIDTH },
						{ "pc", BUS_WIDTH },
					},
				},
			})
			s:c(core, "rst~", control, "rst~")
			------------------------------------------------------------------------------
			do
				local rst = control .. ".pullup.rst~"
				s:new_pullup(rst):c(rst, "q", control, "rst~")
				local legal = control .. ".pulldown.legal"
				s:new_pulldown(legal):c(legal, "q", control, "legal")
				local alu_notb = control .. ".pulldown.alu_notb"
				s:new_pulldown(alu_notb):c(alu_notb, "q", control, "alu_notb")
				local alu_cin = control .. ".pulldown.alu_cin"
				s:new_pulldown(alu_cin):c(alu_cin, "q", control, "alu_cin")
				local lsu_sext = control .. ".pulldown.lsu_sext"
				s:new_pulldown(lsu_sext):c(lsu_sext, "q", control, "lsu_sext")
				local alu_oe = control .. ".pulldown.alu_oe"
				s:new_pulldown(alu_oe):c(alu_oe, "q", control, "alu_oe")
				local isched = control .. ".pulldown.isched"
				s:new_pulldown(isched):c(isched, "q", control, "isched")
				local branch = control .. ".pulldown.branch"
				s:new_pulldown(branch):c(branch, "q", control, "branch")
				local lsu_trigin = control .. ".pulldown.lsu_trigin"
				s:new_pulldown(lsu_trigin):c(lsu_trigin, "q", control, "lsu_trigin")
				local imm_oe = control .. ".pulldown.imm_oe"
				s:new_pulldown(imm_oe):c(imm_oe, "q", control, "imm_oe")
				local pc_oe = control .. ".pulldown.pc_oe"
				s:new_pulldown(pc_oe):c(pc_oe, "q", control, "pc_oe")
				local rs1_oe = control .. ".pulldown.rs1_oe"
				s:new_pulldown(rs1_oe):c(rs1_oe, "q", control, "rs1_oe")
				local rs2_oe = control .. ".pulldown.rs2_oe"
				s:new_pulldown(rs2_oe):c(rs2_oe, "q", control, "rs2_oe")
				local rd_oe = control .. ".pulldown.rd_oe"
				s:new_pulldown(rd_oe):c(rd_oe, "q", control, "rd_oe")
				local xu_trigin = control .. ".pulldown.xu_trigin"
				s:new_pulldown(xu_trigin):c(xu_trigin, "q", control, "xu_trigin")
				local lsu_control = control .. ".pulldown.lsu_control"
				s:new_pulldown(lsu_control, { width = 2 }):c(lsu_control, "q", control, "lsu_control")
				local ireg = control .. ".pulldown.ireg"
				s:new_pulldown(ireg, { width = BUS_WIDTH }):c(ireg, "q", control, "ireg")
				local pc = control .. ".pulldown.pc"
				s:new_pulldown(pc, { width = BUS_WIDTH }):c(pc, "q", control, "pc")
			end

			------------------------------------------------------------------------------
			local clk = core .. ".clock"
			s:new_clock_module(clk, { period = PERIOD, chain_length = 2, trace = opts.trace })
			------------------------------------------------------------------------------
			local buses = core .. ".buses"
			s:add_component(buses, {
				names = {
					inputs = {},
					outputs = {
						{ "a", BUS_WIDTH },
						{ "b", BUS_WIDTH },
						{ "d", BUS_WIDTH },
					},
				},
				trace = opts.trace,
			})
			local a = buses .. ".pulldowns.a"
			s:new_pulldown(a, { width = BUS_WIDTH }):c(a, "q", buses, "a")
			local b = buses .. ".pulldowns.b"
			s:new_pulldown(b, { width = BUS_WIDTH }):c(b, "q", buses, "b")
			local d = buses .. ".pulldowns.d"
			s:new_pulldown(d, { width = BUS_WIDTH }):c(d, "q", buses, "d")
			------------------------------------------------------------------------------
			local lsu = core .. ".lsu"
			s
				:new_load_store_unit(lsu, { file = opts.file, trace = opts.trace })
				:c(clk, "rising", lsu, "rising")
				:c(clk, "falling", lsu, "falling")
				:c(buses, "d", lsu, "address")
				:c(control, "lsu_control", lsu, "control")
				:c(control, "lsu_trigin", lsu, "trigin")
				:c(control, "rst~", lsu, "rst~")
				:c(control, "lsu_sext", lsu, "sext")
				:c(lsu, "out", buses, "d")
			------------------------------------------------------------------------------
			local pc = core .. ".pc"
			s:new_program_counter(pc, { trace = opts.trace })
			s:c(control, "rst~", pc, "rst~")
			s:c(clk, "rising", pc, "rising")
			s:c(clk, "falling", pc, "falling")
			s:c(control, "branch", pc, "branch")
			s:c(control, "xu_trigin", pc, "icomplete")
			s:c(control, "pc_oe", pc, "oe_b")
			s:c(buses, "d", pc, "d")
			s:c(buses, "b", pc, "b")
			s:c(pc, "pc", control, "pc")
			------------------------------------------------------------------------------
			local xu = core .. ".xu"
			s:new_execution_unit(xu, { trace = opts.trace })
			s:c(buses, "d", xu, "d")
			s:c(clk, "rising", xu, "rising")
			s:c(clk, "falling", xu, "falling")
			s:c(control, "rst~", xu, "rst~")
			s:c(control, "xu_trigin", xu, "trigin")
			s:c(lsu, "trigout", xu, "lsu_trigout")
			s:c(xu, "ireg", control, "ireg")
			s:c(xu, "isched", control, "isched")
			s:c(xu, "lsu_control", control, "lsu_control")
			s:c(xu, "lsu_trigin", control, "lsu_trigin")
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
			s:c(idecode, "funct3", alu, "sel")
			s:c(control, "alu_oe", alu, "oe")
			s:c(buses, "a", alu, "a")
			s:c(buses, "b", alu, "b")
			s:c(alu, "out", buses, "d")
			------------------------------------------------------------------------------
			local registers = core .. ".registers"
			s
				:new_register_bank(
					registers,
					{ width = BUS_WIDTH, selwidth = REGISTER_SELECT_WIDTH, trace = opts.trace }
				)
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
			s:c(i_op, "alu_oe", control, "alu_oe")
			s:c(i_op, "rd", control, "rd_oe")
			s:c(i_op, "rs1", control, "rs1_oe")
			s:c(i_op, "rs2", control, "rs2_oe")
			s:c(i_op, "imm_oe", control, "imm_oe")
			s:c(i_op, "alu_notb", control, "alu_notb")
			s:c(i_op, "alu_cin", control, "alu_cin")
			s:c(i_op, "legal", control, "legal")
			------------------------------------------------------------------------------
			local kickstarter = core .. ".kickstarter"
			s:new_kickstarter(kickstarter, { trace = opts.trace })
			s:c(control, "rst~", kickstarter, "rst~")
			s:c(clk, "rising", kickstarter, "rising")
			s:c(clk, "falling", kickstarter, "falling")
			s:c(kickstarter, "branch", control, "branch")
			s:c(kickstarter, "icomplete", control, "xu_trigin")
		end
	)
end
