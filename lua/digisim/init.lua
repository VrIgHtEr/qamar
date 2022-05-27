local constants = require("digisim.constants")
local simulation = require("digisim.simulation")

io.stderr:write("building circuit...\n")

local sim = simulation.new()

local rst = "RESET"
sim:new_reset(rst, { period = 32 })

local core = "CPU"
sim:new_core(core, { trace = true, file = "./lua/sram.dat" })
sim:c(rst, "q", core, "rst~")

local cu = core .. ".cu"

-- program -------------------------------------------------------------------------------------------
local function reg(r)
	local ret = {}
	for i = 1, constants.REGISTER_SELECT_WIDTH do
		ret[i] = math.floor(r / math.pow(2, i - 1)) % 2
	end
	return ret
end

local program = {
	--sela    selb    selw    alu_op   cin na nb
	{ reg(2), reg(0), reg(2), { 0, 0 }, 1, 0, 0 },
	--loop
	{ reg(1), reg(2), reg(3), { 0, 0 }, 0, 0, 0 },
	{ reg(2), reg(0), reg(1), { 0, 0 }, 0, 0, 0 },
	{ reg(3), reg(0), reg(2), { 0, 0 }, 0, 0, 0 },
}
local loopindex = 2
local c = 0

sim:add_component(cu, {
	trace = true,
	names = {
		inputs = {},
		outputs = {
			{ "sela", constants.REGISTER_SELECT_WIDTH },
			{ "selb", constants.REGISTER_SELECT_WIDTH },
			{ "selw", constants.REGISTER_SELECT_WIDTH },
			{ "op", 2 },
			{ "cin", 1 },
			{ "nota", 1 },
			{ "notb", 1 },
		},
	},
}, function()
	c = c + 1
	if c > #program then
		c = loopindex
	end
	local ret = { unpack(program[c]) }
	ret[#ret + 1] = constants.CLOCK_PERIOD_TICKS
	return unpack(ret)
end)
sim
	:c(cu, "op", core, "alu_sel")
	:c(cu, "cin", core, "alu_cin")
	:c(cu, "nota", core, "alu_nota")
	:c(cu, "notb", core, "alu_notb")
	:c(cu, "sela", core, "rs1")
	:c(cu, "selb", core, "rs2")
	:c(cu, "selw", core, "rd")
-----------------------------------------------------------------------------------------------------

local lsutest = core .. ".lsu.TEST"

local lsutestaddr = { 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0 }
local lsuprogram = {
	--ti se 16 32 rs address
	{ 0, 0, 0, 0, 0, lsutestaddr },

	--read 8-bit
	{ 1, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },

	--read consecutive 8-bit
	{ 1, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 1, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },

	--read 16-bit
	{ 1, 0, 1, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },

	--read consecutive 16-bit
	{ 1, 0, 1, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 1, 0, 1, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },

	--read 32-bit
	{ 1, 0, 1, 1, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },

	--read consecutive 32-bit
	{ 1, 0, 1, 1, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 1, 0, 1, 1, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },
	{ 0, 0, 0, 0, 1, lsutestaddr },

	--read 8-bit
	{ 1, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },

	--read consecutive 8-bit
	{ 1, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 1, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },

	--read 16-bit
	{ 1, 1, 1, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },

	--read consecutive 16-bit
	{ 1, 1, 1, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 1, 1, 1, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },

	--read 32-bit
	{ 1, 1, 1, 1, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },

	--read consecutive 32-bit
	{ 1, 1, 1, 1, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 1, 1, 1, 1, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
	{ 0, 1, 0, 0, 1, lsutestaddr },
}
local lsuloopindex = 2
local lsuc = 0

sim
	:add_component(lsutest, {
		trace = true,
		names = {
			inputs = {},
			outputs = {
				"trigin",
				"sext",
				"b16",
				"b32",
				"rst~",
				{ "address", 32 },
			},
		},
	}, function()
		lsuc = lsuc + 1
		if lsuc > #lsuprogram then
			lsuc = lsuloopindex
			for i = 1, #lsutestaddr do
				if lsutestaddr[i] == 0 then
					lsutestaddr[i] = 1
					break
				end
				lsutestaddr[i] = 0
			end
		end
		local ret = { unpack(lsuprogram[lsuc]) }
		ret[#ret + 1] = constants.CLOCK_PERIOD_TICKS
		return unpack(ret)
	end)
	:c(lsutest, "trigin", core, "lsu_trigin")
	:cp(1, lsutest, "b16", 1, core, "lsu_control", 1)
	:cp(1, lsutest, "b32", 1, core, "lsu_control", 2)
	:c(lsutest, "sext", core, "lsu_sext")
-----------------------------------------------------------------------------------------------------

local max = 0
while sim.time < constants.SIM_TIME do
	io.stderr:write("TIME: " .. sim.time .. "\n")
	local x
	_, x = sim:step()
	max = math.max(max, x)
end
io.stderr:write("max delay: " .. max .. "\n")
io.stderr:write("sim time:  " .. sim.time .. "\n")

return simulation
