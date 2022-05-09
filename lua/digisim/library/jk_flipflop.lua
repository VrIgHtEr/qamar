---@class simulation
---@field new_jk_flipflop function

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"jk_flipflop",
		---@param circuit simulation
		---@param name string
		---@param opts boolean
		function(circuit, name, opts)
			circuit:add_component(name, 3, 2)
			local nl = name .. "___l"
			local nj = name .. "___nj"
			local nk = name .. "___nk"
			local aj = name .. "___aj"
			local ak = name .. "___ak"
			circuit
				:new_sr_latch(nl, opts)
				:new_nand(nj)
				:new_nand(nk)
				:alias_input(name, 3, nj, 1)
				:alias_input(name, 3, nk, 1)
				:_(nj, nl, 1)
				:_(nk, nl, 2)
				:new_and(aj)
				:new_and(ak)
				:_(aj, nj, 2)
				:_(ak, nk, 2)
				:alias_input(name, 1, aj, 1)
				:alias_input(name, 2, ak, 1)
				:_(nl, 1, ak, 2)
				:_(nl, 2, aj, 2)
				:alias_output(nl, 1, name, 1)
				:alias_output(nl, 2, name, 2)
		end
	)
end
