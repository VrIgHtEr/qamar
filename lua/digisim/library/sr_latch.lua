---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"sr_latch",
		2,
		2,
		---@param circuit simulation
		---@param name string
		---@param trace boolean
		function(circuit, name, trace)
			local na = name .. "___a"
			local nb = name .. "___b"
			circuit
				:new_nand(na, trace)
				:new_nand(nb, trace)
				:_(na, nb, 1)
				:_(nb, na, 2)
				:alias_input(name, 2, na, 1)
				:alias_input(name, 1, nb, 2)
				:alias_output(na, 1, name, 1)
				:alias_output(nb, 1, name, 2)
		end
	)
end
