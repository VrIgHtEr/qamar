local constants = require("digisim.constants")
local simulation = require("digisim.simulation")
local signal = require("digisim.signal")

do
	local circuit = simulation.new()

	circuit:new_clock("CLK", { period = constants.CLOCK_PERIOD_TICKS, trace = true })
	circuit:new_reset("RST_", { period = constants.STARTUP_TICKS, trace = true })
	circuit:new_edge_detector("ECLK", { chain_length = 4, trace = true }):c("CLK", "q", "ECLK", "clk")
	local alu_width = 32
	circuit:new_alu("ALU", { width = alu_width, trace = true })
	circuit
		:new_random("ARND", { trace = true, width = alu_width, period = constants.CLOCK_PERIOD_TICKS })
		:cp(alu_width, "ARND", "q", 1, "ALU", "a", 1)
	circuit
		:new_random("BRND", { trace = true, width = alu_width, period = constants.CLOCK_PERIOD_TICKS })
		:cp(alu_width, "BRND", "q", 1, "ALU", "b", 1)
	circuit:new_clock("C", { period = constants.CLOCK_PERIOD_TICKS, trace = true }):c("C", "q", "ALU", "cin")
	circuit:add_component("ZERO", function()
		return signal.low
	end, { names = { inputs = {}, outputs = { "q" } } })

	circuit:c("ZERO", "q", "ALU", "nota"):c("C", "q", "ALU", "notb")

	circuit
		:new_clock("LOGIC", { period = constants.CLOCK_PERIOD_TICKS * 2, trace = true })
		:c("LOGIC", "q", "ALU", "logic")

	--circuit:new_mux("mux", { width = 8, trace = true })
	local max = 0
	for _ = 1, constants.CLOCK_PERIOD_TICKS * 1024 do
		local x
		_, x = circuit:step()
		max = math.max(max, x)
	end
	io.stderr:write("max delay: " .. max .. "\n")
end

return simulation
