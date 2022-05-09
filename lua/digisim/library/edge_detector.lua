---@param simulation simulation
return function(simulation)
	simulation:register_component("edge_detector", 1, 2, function(circuit, name, trace)
		-- ~CLK - inverted clock
		circuit:new_not(name .. "___CLK_", trace)
		circuit:alias_input(name, 1, name .. "___CLK_", 1)

		-- CLK_RISING - clock rising edge detector
		circuit
			:new_buffer(name .. "___clk1", trace)
			:alias_input(name, 1, name .. "___clk1", 1)
			:new_buffer(name .. "___clk2", trace)
			:_(name .. "___clk1", name .. "___clk2")
			:new_buffer(name .. "___clk3", trace)
			:_(name .. "___clk2", name .. "___clk3")
			:new_buffer(name .. "___clk4", trace)
			:_(name .. "___clk3", name .. "___clk4")
			:new_buffer(name .. "___clk5", trace)
			:_(name .. "___clk4", name .. "___clk5")
			:new_buffer(name .. "___clk6", trace)
			:_(name .. "___clk5", name .. "___clk6")
			:new_not(name .. "___nclk", trace)
			:_(name .. "___clk6", name .. "___nclk")
			:new_and(name .. "___CLK_RISING", true, trace)
			:alias_input(name, 1, name .. "___CLK_RISING", 1)
			:_(name .. "___nclk", name .. "___CLK_RISING", 2)

		-- CLK_FALLING - clock falling edge detector
		circuit
			:new_buffer(name .. "___clk1_", trace)
			:_(name .. "___CLK_", name .. "___clk1_")
			:new_buffer(name .. "___clk2_", trace)
			:_(name .. "___clk1_", name .. "___clk2_")
			:new_buffer(name .. "___clk3_", trace)
			:_(name .. "___clk2_", name .. "___clk3_")
			:new_buffer(name .. "___clk4_", trace)
			:_(name .. "___clk3_", name .. "___clk4_")
			:new_buffer(name .. "___clk5_", trace)
			:_(name .. "___clk4_", name .. "___clk5_")
			:new_buffer(name .. "___clk6_", trace)
			:_(name .. "___clk5_", name .. "___clk6_")
			:new_not(name .. "___nclk_", trace)
			:_(name .. "___clk6_", name .. "___nclk_")
			:new_and(name .. "___CLK_FALLING", true, trace)
			:_(name .. "___nclk_", name .. "___CLK_FALLING")
			:_(name .. "___CLK_", name .. "___CLK_FALLING")

		circuit:alias_output(name, 1, name .. "___CLK_RISING", 1)
		circuit:alias_output(name, 2, name .. "___CLK_FALLING", 1)
	end)
end
