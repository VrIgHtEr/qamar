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
			circuit:add_component(name, nil, opts)
			local s = name .. ".s"
			local c = name .. ".c"
			circuit
				:new_xor(s)
				:new_and(c)
				:c(s, "q", name, "sum")
				:c(c, "q", name, "carry")
				:c(name, "a", s, "a")
				:c(name, "b", s, "b")
				:cp(1, name, "a", 1, c, "in", 1)
				:cp(1, name, "b", 1, c, "in", 2)
		end
	)
end
