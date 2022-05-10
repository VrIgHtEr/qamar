---@class simulation
---@field new_sr_latch function

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"sr_latch",
		---@param circuit simulation
		---@param name string
		---@param opts boolean
		function(circuit, name, opts)
			opts = opts or {}
			opts.names = { inputs = { "s", "r" }, outputs = { "q", "~q" } }
			circuit:add_component(name, 2, 2, nil, opts)
			local na = name .. ".a"
			local nb = name .. ".b"
			circuit
				:new_nand(na)
				:new_nand(nb)
				:c(na, "q", nb, "a")
				:c(nb, "q", na, "b")
				:c(name, "r", na, "a")
				:c(name, "s", nb, "b")
				:c(name, "q", na, "q")
				:c(name, "~q", nb, "q")
		end
	)
end
