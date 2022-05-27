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
					"alu_nota",
					"alu_notb",
					"alu_cin",
					{ "alu_sel", 2 },
					{ "rd", REGISTER_SELECT_WIDTH },
					{ "rs1", REGISTER_SELECT_WIDTH },
					{ "rs2", REGISTER_SELECT_WIDTH },
					{ "lsu_control", 2 },
					"lsu_sext",
					"lsu_trigin",
					"xu_trigin",
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
						"alu_nota",
						"alu_notb",
						"alu_cin",
						"lsu_sext",
						"lsu_trigin",
						"xu_trigin",
						{ "lsu_control", 2 },
						{ "alu_sel", 2 },
						{ "rd", REGISTER_SELECT_WIDTH },
						{ "rs1", REGISTER_SELECT_WIDTH },
						{ "rs2", REGISTER_SELECT_WIDTH },
					},
				},
			})
			s:c(core, "alu_nota", control, "alu_nota")
			s:c(core, "alu_notb", control, "alu_notb")
			s:c(core, "alu_cin", control, "alu_cin")
			s:c(core, "alu_sel", control, "alu_sel")
			s:c(core, "rd", control, "rd")
			s:c(core, "rs1", control, "rs1")
			s:c(core, "rs2", control, "rs2")
			s:c(core, "lsu_sext", control, "lsu_sext")
			s:c(core, "lsu_trigin", control, "lsu_trigin")
			s:c(core, "xu_trigin", control, "xu_trigin")
			s:c(core, "lsu_control", control, "lsu_control")
			s:c(core, "rst~", control, "rst~")
			------------------------------------------------------------------------------
			do
				local rst = control .. ".pullup.rst~"
				s:new_pullup(rst):c(rst, "q", control, "rst~")
				local alu_nota = control .. ".pulldown.alu_nota"
				s:new_pulldown(alu_nota):c(alu_nota, "q", control, "alu_nota")
				local alu_notb = control .. ".pulldown.alu_notb"
				s:new_pulldown(alu_notb):c(alu_notb, "q", control, "alu_notb")
				local alu_cin = control .. ".pulldown.alu_cin"
				s:new_pulldown(alu_cin):c(alu_cin, "q", control, "alu_cin")
				local lsu_sext = control .. ".pulldown.lsu_sext"
				s:new_pulldown(lsu_sext):c(lsu_sext, "q", control, "lsu_sext")
				local lsu_trigin = control .. ".pulldown.lsu_trigin"
				s:new_pulldown(lsu_trigin):c(lsu_trigin, "q", control, "lsu_trigin")
				local xu_trigin = control .. ".pulldown.xu_trigin"
				s:new_pulldown(xu_trigin):c(xu_trigin, "q", control, "xu_trigin")
				for i = 1, 2 do
					local lsu_control = control .. ".pullup.lsu_control" .. (i - 1)
					s:new_pullup(lsu_control):cp(1, lsu_control, "q", 1, control, "lsu_control", i)
					local alu_sel = control .. ".pulldown.alu_sel" .. (i - 1)
					s:new_pulldown(alu_sel):cp(1, alu_sel, "q", 1, control, "alu_sel", i)
				end
				for i = 1, REGISTER_SELECT_WIDTH do
					local rd = control .. ".pulldown.rd" .. (i - 1)
					s:new_pulldown(rd):cp(1, rd, "q", 1, control, "rd", i)
					local rs1 = control .. ".pulldown.rs1" .. (i - 1)
					s:new_pulldown(rs1):cp(1, rs1, "q", 1, control, "rs1", i)
					local rs2 = control .. ".pulldown.rs2" .. (i - 1)
					s:new_pulldown(rs2):cp(1, rs2, "q", 1, control, "rs2", i)
				end
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
			for i = 1, BUS_WIDTH do
				local a = buses .. ".pulldowns.a" .. (i - 1)
				s:new_pulldown(a):cp(1, a, "q", 1, buses, "a", i)
				local b = buses .. ".pulldowns.b" .. (i - 1)
				s:new_pulldown(b):cp(1, b, "q", 1, buses, "b", i)
				local d = buses .. ".pulldowns.d" .. (i - 1)
				s:new_pulldown(d):cp(1, d, "q", 1, buses, "d", i)
			end
			------------------------------------------------------------------------------
			local alu = core .. ".alu"
			s:new_alu(alu, { width = BUS_WIDTH, trace = opts.trace })
			s:c(control, "alu_nota", alu, "nota")
			s:c(control, "alu_notb", alu, "notb")
			s:c(control, "alu_cin", alu, "cin")
			s:c(control, "alu_sel", alu, "sel")
			s:c(control, "rst~", alu, "oe")
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
				:c(control, "rs1", registers, "sela")
				:c(control, "rs2", registers, "selb")
				:c(control, "rd", registers, "selw")
				:c(registers, "outa", buses, "a")
				:c(registers, "outb", buses, "b")
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
			------------------------------------------------------------------------------
			local idecode = core .. ".idecode"
			s:new_instruction_decoder(idecode, { trace = opts.trace })
			s:c(buses, "d", idecode, "in")
			------------------------------------------------------------------------------
			local xu = core .. ".xu"
			s:new_execution_unit(xu, { trace = opts.trace })
			s:c(clk, "rising", xu, "rising")
			s:c(clk, "falling", xu, "falling")
			s:c(control, "rst~", xu, "rst~")
			s:c(control, "xu_trigin", xu, "trigin")
			s:c(lsu, "trigout", xu, "lsu_trigout")
		end
	)
end
