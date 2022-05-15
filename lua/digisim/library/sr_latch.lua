---@class simulation
---@field new_sr_latch fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"sr_latch",
		---@param circuit simulation
		---@param name string
		---@param opts boolean
		function(circuit, name, opts)
			opts = opts or {}
			opts.names = { inputs = { "s", "r" }, outputs = { "q", "~q" } }
			circuit:add_component(name, nil, opts)
			local na = name .. ".a"
			local nb = name .. ".b"
			circuit
				:new_nand(na)
				:new_nand(nb)
				:cp(1, na, "q", 1, nb, "in", 1)
				:cp(1, nb, "q", 1, na, "in", 2)
				:cp(1, name, "r", 1, na, "in", 1)
				:cp(1, name, "s", 1, nb, "in", 2)
				:c(name, "q", na, "q")
				:c(name, "~q", nb, "q")
		end
	)
end
