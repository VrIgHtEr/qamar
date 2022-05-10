---@class simulation
---@field new_edge_detector function

---@param simulation simulation
return function(simulation)
	simulation:register_component("edge_detector", function(circuit, name, opts)
		opts = opts or {}
		opts.names = { inputs = { "clk" }, outputs = { "rising", "falling" } }
		circuit:add_component(name, 1, 2, nil, opts)

		-- ~CLK - inverted clock
		circuit:new_not(name .. ".~clk")
		circuit:c(name, "clk", name .. ".~clk", "q")

		-- CLK_RISING - clock rising edge detector
		circuit:new_not(name .. ".clk1"):c(name, "clk", name .. ".clk1", "a")

		local chain_length = opts.chain_length or 3
		if type(chain_length) ~= "number" then
			error("invalid chain_length type")
		end

		for i = 2, chain_length do
			circuit:new_buffer(name .. ".clk" .. i)
			circuit:c(name .. ".clk" .. (i - 1), "q", name .. ".clk" .. i, "a")
		end
		circuit
			:new_and(name .. ".CLK_RISING")
			:c(name, "clk", name .. ".CLK_RISING", "a")
			:c(name .. ".clk" .. chain_length, "q", name .. ".CLK_RISING", "b")

		-- CLK_FALLING - clock falling edge detector
		circuit:new_not(name .. ".clk1_"):c(name .. ".~clk", "q", name .. ".clk1_", "a")
		for i = 2, chain_length do
			circuit:new_buffer(name .. ".clk" .. i .. "_")
			circuit:c(name .. ".clk" .. (i - 1) .. "_", "q", name .. ".clk" .. i .. "_", "a")
		end
		circuit
			:new_and(name .. ".CLK_FALLING")
			:c(name .. ".clk" .. chain_length .. "_", "q", name .. ".CLK_FALLING", "a")
			:c(name .. ".~clk", "q", name .. ".CLK_FALLING", "b")

		circuit:c(name, "rising", name .. ".CLK_RISING", "q")
		circuit:c(name, "falling", name .. ".CLK_FALLING", "q")
	end)
end
