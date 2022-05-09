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
			circuit:add_component(name, 3, 2)

			local h = name .. ".h"
			local s = name .. ".s"
			local ca = name .. ".ca"
			local c = name .. ".c"
			circuit
				:new_half_adder(h)
				:alias_input(name, 1, h, 1)
				:alias_input(name, 2, h, 2)
				:new_xor(s, opts)
				:new_and(ca)
				:_(h, 1, s, 1)
				:_(h, 1, ca, 1)
				:alias_input(name, 3, s, 2)
				:alias_input(name, 3, ca, 2)
				:new_or(c, opts)
				:_(ca, c)
				:_(h, 2, c)
				:alias_output(s, 1, name, 1)
				:alias_output(c, 1, name, 2)
		end
	)
end
