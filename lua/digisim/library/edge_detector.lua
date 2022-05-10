---@class simulation
---@field new_edge_detector function

---@param simulation simulation
return function(simulation)
	simulation:register_component("edge_detector", function(circuit, name, opts)
		opts = opts or {}
		opts.names = { inputs = { "clk" }, outputs = { "rising", "falling" } }
		circuit:add_component(name, 1, 2, nil, opts)

		-- ~CLK - inverted clock
		circuit:new_not(name .. ".CLK_", opts)
		circuit:alias_input(name, 1, name .. ".CLK_", 1)

		-- CLK_RISING - clock rising edge detector
		circuit:new_not(name .. ".clk1"):alias_input(name, 1, name .. ".clk1", 1)

		local chain_length = opts.chain_length or 3
		if type(chain_length) ~= "number" then
			error("invalid chain_length type")
		end

		for i = 2, chain_length do
			circuit:new_buffer(name .. ".clk" .. i)
			circuit:_(name .. ".clk" .. (i - 1), name .. ".clk" .. i)
		end
		circuit
			:new_and(name .. ".CLK_RISING")
			:alias_input(name, 1, name .. ".CLK_RISING", 1)
			:_(name .. ".clk" .. chain_length, name .. ".CLK_RISING", 2)

		-- CLK_FALLING - clock falling edge detector
		circuit:new_not(name .. ".clk1_"):_(name .. ".CLK_", name .. ".clk1_")
		for i = 2, chain_length do
			circuit:new_buffer(name .. ".clk" .. i .. "_")
			circuit:_(name .. ".clk" .. (i - 1) .. "_", name .. ".clk" .. i .. "_")
		end
		circuit
			:new_and(name .. ".CLK_FALLING")
			:_(name .. ".clk" .. chain_length .. "_", name .. ".CLK_FALLING")
			:_(name .. ".CLK_", name .. ".CLK_FALLING")

		circuit:alias_output(name, 1, name .. ".CLK_RISING", 1)
		circuit:alias_output(name, 2, name .. ".CLK_FALLING", 1)
	end)
end
