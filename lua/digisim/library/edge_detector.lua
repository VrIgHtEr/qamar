---@class simulation
---@field new_edge_detector function

---@param simulation simulation
return function(simulation)
	simulation:register_component("edge_detector", function(circuit, name, opts)
		circuit:add_component(name, 1, 2)

		-- ~CLK - inverted clock
		circuit:new_not(name .. "___CLK_", opts)
		circuit:alias_input(name, 1, name .. "___CLK_", 1)

		-- CLK_RISING - clock rising edge detector
		circuit:new_not(name .. "___clk1", opts):alias_input(name, 1, name .. "___clk1", 1)

		local chain_length = opts.chain_length or 3
		if type(chain_length) ~= "number" then
			error("invalid chain_length type")
		end

		for i = 2, chain_length do
			circuit:new_buffer(name .. "___clk" .. i, opts)
			circuit:_(name .. "___clk" .. (i - 1), name .. "___clk" .. i)
		end
		circuit
			:new_and(name .. "___CLK_RISING", opts)
			:alias_input(name, 1, name .. "___CLK_RISING", 1)
			:_(name .. "___clk" .. chain_length, name .. "___CLK_RISING", 2)

		-- CLK_FALLING - clock falling edge detector
		circuit:new_not(name .. "___clk1_", opts):_(name .. "___CLK_", name .. "___clk1_")
		for i = 2, chain_length do
			circuit:new_buffer(name .. "___clk" .. i .. "_", opts)
			circuit:_(name .. "___clk" .. (i - 1) .. "_", name .. "___clk" .. i .. "_")
		end
		circuit
			:new_and(name .. "___CLK_FALLING", opts)
			:_(name .. "___clk" .. chain_length .. "_", name .. "___CLK_FALLING")
			:_(name .. "___CLK_", name .. "___CLK_FALLING")

		circuit:alias_output(name, 1, name .. "___CLK_RISING", 1)
		circuit:alias_output(name, 2, name .. "___CLK_FALLING", 1)
	end)
end
