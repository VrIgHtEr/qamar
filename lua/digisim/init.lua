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

	circuit:new_clock("DATA", { period = constants.CLOCK_PERIOD_TICKS * 2, trace = true })
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

	circuit:new_n_bit_adder("adder", { width = 8, trace = true })
	local function create_random_input(name)
		local value = signal.low
		local last = 0
		circuit
			:add_component(name, function(time)
				time = math.floor(time / constants.CLOCK_PERIOD_TICKS)
				if time ~= last then
					last = time
					value = math.random(0, 1)
				end
				return value
			end, { trace = true, names = { outputs = { "q" } } })
			:c(name, "q", "adder", name)
	end
	create_random_input("a0")
	create_random_input("a1")
	create_random_input("a2")
	create_random_input("a3")
	create_random_input("a4")
	create_random_input("a5")
	create_random_input("a6")
	create_random_input("a7")
	create_random_input("b0")
	create_random_input("b1")
	create_random_input("b2")
	create_random_input("b3")
	create_random_input("b4")
	create_random_input("b5")
	create_random_input("b6")
	create_random_input("b7")

	circuit:new_clock("C", { period = constants.CLOCK_PERIOD_TICKS, trace = true }):c("C", "q", "adder", "cin")

	local max = 0
	for _ = 1, constants.CLOCK_PERIOD_TICKS * 512 do
		local x
		_, x = circuit:step()
		max = math.max(max, x)
	end
	io.stderr:write("max delay: " .. max .. "\n")
end

return simulation
