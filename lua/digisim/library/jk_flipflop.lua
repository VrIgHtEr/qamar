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
			opts = opts or {}
			opts.names = { inputs = { "j", "k", "clock" }, outputs = { "q", "~q" } }
			circuit:add_component(name, nil, opts)
			local nl = name .. ".l"
			local nj = name .. ".nj"
			local nk = name .. ".nk"
			local aj = name .. ".aj"
			local ak = name .. ".ak"
			circuit
				:new_sr_latch(nl)
				:new_nand(nj)
				:new_nand(nk)
				:c(nj, "q", nl, "s")
				:c(nk, "q", nl, "r")
				:new_and(aj)
				:new_and(ak)
				:cp(1, name, "clock", 1, nj, "in", 1)
				:cp(1, name, "clock", 1, nk, "in", 1)
				:cp(1, aj, "q", 1, nj, "in", 2)
				:cp(1, ak, "q", 1, nk, "in", 2)
				:cp(1, name, "j", 1, aj, "in", 1)
				:cp(1, name, "k", 1, ak, "in", 1)
				:cp(1, nl, "q", 1, ak, "in", 2)
				:cp(1, nl, "~q", 1, aj, "in", 2)
				:c(nl, "q", name, "q")
				:c(nl, "~q", name, "~q")
		end
	)
end
