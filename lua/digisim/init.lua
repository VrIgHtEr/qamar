local constants = require("digisim.constants")
local signal = require("digisim.signal")
local simulation = require("digisim.simulation")

function print(circuit)
	do
		io.stdout:write(tostring(circuit.trace))
		io.stdout:write("\n")
		return
	end
	local max = 0
	local maxtime = 0
	for k, t in pairs(circuit.trace) do
		if k:sub(1, 1) ~= "[" then
			max = math.max(max, k:len())
			maxtime = math.max(maxtime, t[#t].time)
		end
	end
	maxtime = maxtime + constants.CLOCK_PERIOD_TICKS / 4
	max = max + 2
	local traces = {}
	for k in pairs(circuit.trace) do
		if k:sub(1, 1) ~= "[" then
			table.insert(
				traces,
				table.concat({ k, ": ", string.rep(" ", max - (k:len() + 2)), circuit:get_trace(k, maxtime) })
			)
		end
	end
	max = 0
	for _, x in ipairs(traces) do
		max = math.max(max, x:len())
	end
	max = max + 5

	table.sort(traces)
	local first = true
	local lines = {}
	for _, x in ipairs(traces) do
		if first then
			first = false
		else
			table.insert(lines, "--")
			--			print("--")
		end
		table.insert(lines, "--" .. x)
		--		print(x)
	end

	table.insert(lines, "")
	io.stdout:write(table.concat(lines, "\n"))
	--	vim.api.nvim_buf_set_text(vim.api.nvim_get_current_buf(), -1, 0, -1, 0, lines)
end

do
	--vim.api.nvim_exec("mes clear", true)

	local circuit = simulation.new()

	-- data pin
	circuit:add_component("DATA", 0, 1, function(time)
		return time * 0.5 % constants.CLOCK_PERIOD_TICKS < constants.CLOCK_PERIOD_TICKS / 2 and signal.low
			or signal.high
	end, { names = { inputs = {}, outputs = { "q" } }, trace = true })

	circuit:new_reset("RST_", { period = constants.STARTUP_TICKS, trace = true })
	circuit:new_clock("CLK", { period = constants.CLOCK_PERIOD_TICKS, trace = true })
	circuit:new_edge_detector("ECLK", { chain_length = 4, trace = true }):c("CLK", "q", "ECLK", "clk")
	circuit
		:new_ms_jk_flipflop("FF", { trace = true })
		:c("ECLK", "rising", "FF", "clock_rising")
		:c("ECLK", "falling", "FF", "clock_falling")

	circuit:new_not("ND", { trace = true }):c("DATA", "q", "ND", "a")
	circuit:c("DATA", "q", "FF", "j")
	circuit:c("ND", "q", "FF", "k")

	circuit:new_n_bit_adder("ADDER", { width = 8, trace = true })
	circuit:new_clock("A0", { period = 256 + math.random(0, 128), trace = true }):c("A0", "q", "ADDER", "a0")
	circuit:new_clock("A1", { period = 256 + math.random(0, 128), trace = true }):c("A1", "q", "ADDER", "a1")
	circuit:new_clock("A2", { period = 256 + math.random(0, 128), trace = true }):c("A2", "q", "ADDER", "a2")
	circuit:new_clock("A3", { period = 256 + math.random(0, 128), trace = true }):c("A3", "q", "ADDER", "a3")
	circuit:new_clock("A4", { period = 256 + math.random(0, 128), trace = true }):c("A4", "q", "ADDER", "a4")
	circuit:new_clock("A5", { period = 256 + math.random(0, 128), trace = true }):c("A5", "q", "ADDER", "a5")
	circuit:new_clock("A6", { period = 256 + math.random(0, 128), trace = true }):c("A6", "q", "ADDER", "a6")
	circuit:new_clock("A7", { period = 256 + math.random(0, 128), trace = true }):c("A7", "q", "ADDER", "a7")
	circuit:new_clock("B0", { period = 256 + math.random(0, 128), trace = true }):c("B0", "q", "ADDER", "b0")
	circuit:new_clock("B1", { period = 256 + math.random(0, 128), trace = true }):c("B1", "q", "ADDER", "b1")
	circuit:new_clock("B2", { period = 256 + math.random(0, 128), trace = true }):c("B2", "q", "ADDER", "b2")
	circuit:new_clock("B3", { period = 256 + math.random(0, 128), trace = true }):c("B3", "q", "ADDER", "b3")
	circuit:new_clock("B4", { period = 256 + math.random(0, 128), trace = true }):c("B4", "q", "ADDER", "b4")
	circuit:new_clock("B5", { period = 256 + math.random(0, 128), trace = true }):c("B5", "q", "ADDER", "b5")
	circuit:new_clock("B6", { period = 256 + math.random(0, 128), trace = true }):c("B6", "q", "ADDER", "b6")
	circuit:new_clock("B7", { period = 256 + math.random(0, 128), trace = true }):c("B7", "q", "ADDER", "b7")
	circuit:new_clock("C", { period = 1024, trace = true }):c("C", "q", "ADDER", "cin")

	circuit:new_sr_latch("TEST", { trace = true }):c("ND", "q", "TEST", "s"):c("DATA", "q", "TEST", "r")

	local max = 0
	for _ = 1, constants.CLOCK_PERIOD_TICKS * 512 do
		local x
		_, x = circuit:step()
		max = math.max(max, x)
	end
	io.stderr:write("max delay: " .. max .. "\n")
end

return simulation
