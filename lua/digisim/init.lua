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

local max = 0
while sim.time < constants.SIM_TIME do
	--io.stderr:write("TIME: " .. sim.time .. "\n")
	local x
	_, x = sim:step()
	max = math.max(max, x)
end
io.stderr:write("max delay: " .. max .. "\n")
io.stderr:write("sim time:  " .. sim.time .. "\n")

return simulation
