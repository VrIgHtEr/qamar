---@param simulation simulation
return function(simulation)
	simulation:register_component("edge_detector", 1, 2, function(circuit, name, trace)
		-- ~CLK - inverted clock
		circuit:new_not(name .. "___CLK_", trace)
		circuit:alias_input(name, 1, name .. "___CLK_", 1)

		-- CLK_RISING - clock rising edge detector
		circuit:new_not(name .. "___clk1", trace):alias_input(name, 1, name .. "___clk1", 1)

		local chain_length = 3

		for i = 2, chain_length do
			circuit:new_buffer(name .. "___clk" .. i, trace)
			circuit:_(name .. "___clk" .. (i - 1), name .. "___clk" .. i)
		end
		circuit
			:new_and(name .. "___CLK_RISING", trace)
			:alias_input(name, 1, name .. "___CLK_RISING", 1)
			:_(name .. "___clk" .. chain_length, name .. "___CLK_RISING", 2)

		-- CLK_FALLING - clock falling edge detector
		circuit:new_not(name .. "___clk1_", trace):_(name .. "___CLK_", name .. "___clk1_")
		for i = 2, chain_length do
			circuit:new_buffer(name .. "___clk" .. i .. "_", trace)
			circuit:_(name .. "___clk" .. (i - 1) .. "_", name .. "___clk" .. i .. "_")
		end
		circuit
			:new_and(name .. "___CLK_FALLING", true, trace)
			:_(name .. "___clk" .. chain_length .. "_", name .. "___CLK_FALLING")
			:_(name .. "___CLK_", name .. "___CLK_FALLING")

		circuit:alias_output(name, 1, name .. "___CLK_RISING", 1)
		circuit:alias_output(name, 2, name .. "___CLK_FALLING", 1)
	end)
end
