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
			circuit:add_component(name, 2, 2)
			local na = name .. "___a"
			local nb = name .. "___b"
			circuit
				:new_nand(na, opts)
				:new_nand(nb, opts)
				:_(na, nb, 1)
				:_(nb, na, 2)
				:alias_input(name, 2, na, 1)
				:alias_input(name, 1, nb, 2)
				:alias_output(na, 1, name, 1)
				:alias_output(nb, 1, name, 2)
		end
	)
end
