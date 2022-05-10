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
			opts.names = { inputs = { "j", "k", "clock" }, outputs = { "q", "~q" } }
			circuit:add_component(name, 3, 2, nil, opts)
			local nl = name .. ".l"
			local nj = name .. ".nj"
			local nk = name .. ".nk"
			local aj = name .. ".aj"
			local ak = name .. ".ak"
			circuit
				:new_sr_latch(nl)
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
