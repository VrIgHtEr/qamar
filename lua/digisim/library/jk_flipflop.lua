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
				:c(name, "clock", nj, "a")
				:c(name, "clock", nk, "a")
				:c(nj, "q", nl, "s")
				:c(nk, "q", nl, "r")
				:new_and(aj)
				:new_and(ak)
				:c(aj, "q", nj, "b")
				:c(ak, "q", nk, "b")
				:c(name, "j", aj, "a")
				:c(name, "k", ak, "a")
				:c(nl, "q", ak, "b")
				:c(nl, "~q", aj, "b")
				:c(nl, "q", name, "q")
				:c(nl, "~q", name, "~q")
		end
	)
end
