---@class simulation
---@field new_edge_detector function

---@param simulation simulation
return function(simulation)
	---@param circuit simulation
	---@param eclk string
	---@param opts table
	simulation:register_component("edge_detector", function(circuit, eclk, opts)
		opts = opts or {}
		opts.names = { inputs = { "clk" }, outputs = { "rising", "falling" } }
		circuit:add_component(eclk, nil, opts)

		local iclk = eclk .. ".~clk"
		local c = eclk .. ".clk"
		local ic = eclk .. ".~clk"
		local rising = eclk .. ".rising"
		local falling = eclk .. ".falling"

		-- ~CLK - inverted clock
		circuit:new_not(iclk)
		circuit:c(eclk, "clk", iclk, "a")

		-- CLK_RISING - clock rising edge detector
		circuit:new_not(c .. 1):c(eclk, "clk", c .. 1, "a")
		local chain_length = opts.chain_length or 3
		if type(chain_length) ~= "number" then
			error("invalid chain_length type")
		end

		for i = 2, chain_length do
			circuit:new_buffer(c .. i)
			circuit:c(c .. (i - 1), "q", c .. i, "a")
		end
		circuit:new_and(rising):c(eclk, "clk", rising, "a"):c(c .. chain_length, "q", rising, "b")

		-- CLK_FALLING - clock falling edge detector
		circuit:new_not(ic .. 1):c(iclk, "q", ic .. 1, "a")
		for i = 2, chain_length do
			circuit:new_buffer(ic .. i)
			circuit:c(ic .. (i - 1), "q", ic .. i, "a")
		end
		circuit:new_and(falling):c(ic .. chain_length, "q", falling, "a"):c(iclk, "q", falling, "b")

		circuit:c(eclk, "rising", rising, "q")
		circuit:c(eclk, "falling", falling, "q")
	end)
end
