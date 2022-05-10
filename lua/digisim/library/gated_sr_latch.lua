---@class simulation
---@field new_gated_sr_latch function

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"gated_sr_latch",
		---@param circuit simulation
		---@param name string
		---@param opts boolean
		function(circuit, name, opts)
			opts = opts or {}
			opts.names = { inputs = { "a", "b", "e" }, outputs = { "q", "~q" } }
			circuit:add_component(name, 3, 2, nil, opts)
			local nl = name .. ".l"
			local na = name .. ".a"
			local nb = name .. ".b"
			circuit
				:new_sr_latch(nl)
				:new_and(na)
				:new_and(nb)
				:_(na, nl, 1)
				:_(nb, nl, 2)
				:alias_input(name, 1, na, 1)
				:alias_input(name, 3, na, 2)
				:alias_input(name, 2, nb, 1)
				:alias_input(name, 3, nb, 2)
				:alias_output(nl, 1, name, 1)
				:alias_output(nl, 2, name, 2)
		end
	)
end
