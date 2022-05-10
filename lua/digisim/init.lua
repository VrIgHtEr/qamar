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
	end, { trace = true })

	circuit:new_reset("RST_", { trace = true, period = constants.STARTUP_TICKS })
	circuit:new_clock("CLK", { period = constants.CLOCK_PERIOD_TICKS })
	circuit:new_edge_detector("ECLK", { trace = true, chain_length = 4 }):_("CLK", "ECLK")
	circuit:new_ms_jk_flipflop("FF"):_("ECLK", 1, "FF", 3):_("ECLK", 2, "FF", 4)

	circuit:new_not("ND"):_("DATA", "ND")
	circuit:_("DATA", "FF", 1)
	circuit:_("ND", "FF", 2)

	circuit:new_n_bit_adder("ADDER", { width = 8 })
	circuit:new_clock("A0", { period = 256 + math.random(0, 128) }):_("A0", "ADDER", 1)
	circuit:new_clock("A1", { period = 256 + math.random(0, 128) }):_("A1", "ADDER", 2)
	circuit:new_clock("A2", { period = 256 + math.random(0, 128) }):_("A2", "ADDER", 3)
	circuit:new_clock("A3", { period = 256 + math.random(0, 128) }):_("A3", "ADDER", 4)
	circuit:new_clock("A4", { period = 256 + math.random(0, 128) }):_("A4", "ADDER", 5)
	circuit:new_clock("A5", { period = 256 + math.random(0, 128) }):_("A5", "ADDER", 6)
	circuit:new_clock("A6", { period = 256 + math.random(0, 128) }):_("A6", "ADDER", 7)
	circuit:new_clock("A7", { period = 256 + math.random(0, 128) }):_("A7", "ADDER", 8)
	circuit:new_clock("B0", { period = 256 + math.random(0, 128) }):_("B0", "ADDER", 9)
	circuit:new_clock("B1", { period = 256 + math.random(0, 128) }):_("B1", "ADDER", 10)
	circuit:new_clock("B2", { period = 256 + math.random(0, 128) }):_("B2", "ADDER", 11)
	circuit:new_clock("B3", { period = 256 + math.random(0, 128) }):_("B3", "ADDER", 12)
	circuit:new_clock("B4", { period = 256 + math.random(0, 128) }):_("B4", "ADDER", 13)
	circuit:new_clock("B5", { period = 256 + math.random(0, 128) }):_("B5", "ADDER", 14)
	circuit:new_clock("B6", { period = 256 + math.random(0, 128) }):_("B6", "ADDER", 15)
	circuit:new_clock("B7", { period = 256 + math.random(0, 128) }):_("B7", "ADDER", 16)
	circuit:new_clock("C", { period = 1024 }):_("C", "ADDER", 17)

	local max = 0
	for _ = 1, constants.CLOCK_PERIOD_TICKS * 512 do
		local x
		_, x = circuit:step()
		max = math.max(max, x)
	end
	io.stderr:write("max delay: " .. max .. "\n")
end

return simulation
