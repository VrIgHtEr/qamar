---@class simulation
---@field new_full_adder function

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"full_adder",
		---@param circuit simulation
		---@param name string
		---@param opts boolean
		function(circuit, name, opts)
			opts = opts or {}
			opts.names = { inputs = { "a", "b", "c" }, outputs = { "sum", "carry" } }
			circuit:add_component(name, 3, 2, nil, opts)

			local h = name .. ".h"
			local s = name .. ".s"
			local ca = name .. ".ca"
			local c = name .. ".c"
			circuit
				:new_half_adder(h)
				:c(name, "a", h, "a")
				:c(name, "b", h, "b")
				:new_xor(s)
				:new_and(ca)
				:c(h, "sum", s, "a")
				:c(h, "carry", ca, "a")
				:c(name, "c", s, "b")
				:c(name, "c", ca, "b")
				:new_or(c)
				:c(ca, "q", c, "a")
				:c(h, "carry", c, "b")
				:c(name, "sum", s, "q")
				:c(name, "carry", c, "q")
		end
	)
end
