---@class simulation
---@field new_gated_d_latch function

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"gated_d_latch",
		---@param circuit simulation
		---@param latch string
		---@param opts boolean
		function(circuit, latch, opts)
			opts = opts or { width = 1 }
			local width = opts.width or 1
			if type(width) ~= "number" then
				error("invalid width type")
			end
			width = math.floor(width)
			if width < 1 then
				error("invalid width")
			end
			opts.names = {
				inputs = {
					{ "d", width },
					"clk",
				},
				outputs = {
					{ "q", width },
					{ "~q", width },
				},
			}
			circuit:add_component(latch, nil, opts)

			for i = 1, width do
				local nl = latch .. ".l" .. (i - 1)
				local nd = latch .. ".d" .. (i - 1)
				circuit:new_gated_sr_latch(nl)
				circuit:c(latch, "clk", nl, "e")
				circuit:new_not(nd):cp(1, latch, "d", i, nd, "a", 1)
				circuit:c(nd, "q", nl, "s"):cp(1, latch, "d", i, nl, "r", 1)
				circuit:cp(1, latch, "q", i, nl, "q", 1)
				circuit:cp(1, latch, "~q", i, nl, "~q", 1)
			end
		end
	)
end
