---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"ms_jk_flipflop",
		4,
		2,
		---@param circuit simulation
		---@param name string
		---@param trace boolean
		function(circuit, name, trace)
			local q = name .. "___q"
			local m = name .. "___m"
			local qj = name .. "___qj"
			local qk = name .. "___qk"
			local mj = name .. "___mj"
			local mk = name .. "___mk"
			local lj = name .. "___lj"
			local lk = name .. "___lk"

			circuit
				:new_sr_latch(q, trace)
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
