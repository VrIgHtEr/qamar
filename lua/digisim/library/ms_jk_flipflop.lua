---@class simulation
---@field new_ms_jk_flipflop function

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"ms_jk_flipflop",
		---@param circuit simulation
		---@param name string
		---@param opts boolean
		function(circuit, name, opts)
			circuit:add_component(name, 4, 2)
			local q = name .. ".q"
			local m = name .. ".m"
			local qj = name .. ".qj"
			local qk = name .. ".qk"
			local mj = name .. ".mj"
			local mk = name .. ".mk"
			local lj = name .. ".lj"
			local lk = name .. ".lk"

			circuit
				:new_sr_latch(q, opts)
				:new_sr_latch(m)
				:alias_output(q, 1, name, 1)
				:alias_output(q, 2, name, 2)
				:new_nand(qj)
				:new_nand(qk)
				:_(qj, q, 1)
				:_(qk, q, 2)
				:alias_input(name, 4, qj, 1)
				:alias_input(name, 4, qk, 1)
				:_(m, 1, qj, 2)
				:_(m, 2, qk, 2)
				:new_nand(mj)
				:new_nand(mk)
				:_(mj, m, 1)
				:_(mk, m, 2)
				:alias_input(name, 3, mj, 1)
				:alias_input(name, 3, mk, 1)
				:new_and(lj)
				:new_and(lk)
				:_(lj, mj, 2)
				:_(lk, mk, 2)
				:alias_input(name, 1, lj, 1)
				:alias_input(name, 2, lk, 1)
				:_(q, 1, lk, 2)
				:_(q, 2, lj, 2)
		end
	)
end
