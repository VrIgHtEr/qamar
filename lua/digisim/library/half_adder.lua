---@class simulation
---@field new_half_adder function

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"half_adder",
		---@param circuit simulation
		---@param name string
		---@param opts boolean
		function(circuit, name, opts)
			opts = opts or {}
			opts.names = { inputs = { "a", "b" }, outputs = { "sum", "carry" } }
			circuit:add_component(name, 2, 2, nil, opts)
			local s = name .. ".s"
			local c = name .. ".c"
			circuit
				:new_xor(s)
				:new_and(c)
				:alias_output(s, 1, name, 1)
				:alias_output(c, 1, name, 2)
				:alias_input(name, 1, s, 1)
				:alias_input(name, 2, s, 2)
				:alias_input(name, 1, c, 1)
				:alias_input(name, 2, c, 2)
		end
	)
end
