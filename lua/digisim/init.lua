local constants = require("digisim.constants")
local simulation = require("digisim.simulation")

io.stderr:write("building circuit...\n")

local sim = simulation.new()

local rst = "RESET"
sim:new_reset(rst, { period = 32 })

local core = "CPU"
sim:new_core(core, { trace = true, file = "./lua/sram.dat" })
sim:c(rst, "q", core, "rst~")

-----------------------------------------------------------------------------------------------------

local coretest = core .. ".TEST"

local lsuprogram = {
	--xu branch
	{ -1, -1 },
	{ 1, 1 },
	--loop
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
	{ -1, -1 },
}
local lsuloopindex = 3
local lsuc = 0

sim:add_component(coretest, {
	trace = true,
	names = {
		inputs = {},
		outputs = {
			"xu_trigin",
			"branch",
		},
	},
}, function()
	lsuc = lsuc + 1
	if lsuc > #lsuprogram then
		lsuc = lsuloopindex
	end
	local ret = { unpack(lsuprogram[lsuc]) }
	ret[#ret + 1] = constants.CLOCK_PERIOD_TICKS
	return unpack(ret)
end)
sim:c(coretest, "xu_trigin", core, "xu_trigin")
sim:c(coretest, "branch", core, "branch")
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
