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
			opts.names = { inputs = { "s", "r" }, outputs = { "q", "~q" } }
			circuit:add_component(name, 2, 2, nil, opts)
			local na = name .. ".a"
			local nb = name .. ".b"
			circuit
				:new_nand(na)
				:new_nand(nb)
				:_(na, nb, 1)
				:_(nb, na, 2)
				:alias_input(name, 2, na, 1)
				:alias_input(name, 1, nb, 2)
				:alias_output(na, 1, name, 1)
				:alias_output(nb, 1, name, 2)
		end
	)
end
