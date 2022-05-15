local constants = require("digisim.constants")
local simulation = require("digisim.simulation")
local signal = require("digisim.signal")

do
	local circuit = simulation.new()

	local alu_width = 2

	local clk = "CLK"
	local rst = "~RST"
	local alu = "ALU"
	local subtract = "SUBTRACT"
	local sel1 = "SEL1"
	local sel2 = "SEL2"
	local zero = "ZERO"
	local arnd = "ARND"
	local brnd = "BRND"
	local vcc = "VCC"
	local gnd = "GND"

	circuit:new_vcc(vcc):new_gnd(gnd)

	circuit:new_clock_module(clk, { period = constants.CLOCK_PERIOD_TICKS, chain_length = 3, trace = true })
	circuit:new_reset(rst, { period = constants.STARTUP_TICKS, trace = true })
	circuit:new_alu(alu, { width = alu_width, trace = true })
	circuit:c(rst, "q", alu, "oe")
	circuit
		:new_random(arnd, { trace = true, width = alu_width, period = constants.CLOCK_PERIOD_TICKS })
		:cp(alu_width, arnd, "q", 1, alu, "a", 1)
	circuit
		:new_random(brnd, { trace = true, width = alu_width, period = constants.CLOCK_PERIOD_TICKS })
		:cp(alu_width, brnd, "q", 1, alu, "b", 1)
	circuit:new_clock(subtract, { period = constants.CLOCK_PERIOD_TICKS, trace = true }):c(subtract, "q", alu, "cin")
	circuit:add_component(zero, function()
		return signal.low
	end, { names = { inputs = {}, outputs = { "q" } } })

	circuit:c(zero, "q", alu, "nota"):c(subtract, "q", alu, "notb")

	circuit
		:new_clock(sel1, { period = constants.CLOCK_PERIOD_TICKS * 2, trace = true })
		:cp(1, sel1, "q", 1, alu, "sel", 1)
	circuit
		:new_clock(sel2, { period = constants.CLOCK_PERIOD_TICKS * 4, trace = true })
		:cp(1, sel2, "q", 1, alu, "sel", 2)

	local r0 = "R0"
	local write = "WRITE"
	circuit:new_register(r0, { width = alu_width })
	circuit:c(alu, "out", r0, "in")
	circuit:c(vcc, "q", r0, "oea")
	circuit:c(vcc, "q", r0, "oeb")
	circuit:new_clock(write, { trace = true, period = constants.CLOCK_PERIOD_TICKS * 2 })
	circuit:c(write, "q", r0, "write")
	circuit:c(clk, "rising", r0, "rising")

	---------------------------------------------------------------------------------------------------------

	local max = 0
	for _ = 1, constants.CLOCK_PERIOD_TICKS * 1024 do
		local x
		_, x = circuit:step()
		max = math.max(max, x)
	end
	io.stderr:write("max delay: " .. max .. "\n")
end

return simulation
