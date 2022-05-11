---@class simulation
---@field new_gated_sr_latch function

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"gated_sr_latch",
		---@param circuit simulation
		---@param name string
		---@param opts boolean
		function(circuit, name, opts)
			opts = opts or {}
			opts.names = { inputs = { "a", "b", "e" }, outputs = { "q", "~q" } }
			circuit:add_component(name, nil, opts)
			local nl = name .. ".l"
			local na = name .. ".a"
			local nb = name .. ".b"
			circuit
				:new_sr_latch(nl)
				:new_and(na)
				:new_and(nb)
				:c(na, "q", nl, "q")
				:c(nb, "q", nl, "~q")
				:c(name, "a", na, "a")
				:c(name, "e", na, "b")
				:c(name, "b", nb, "a")
				:c(name, "e", nb, "b")
				:c(nl, "q", name, "q")
				:c(nl, "~q", name, "~q")
		end
	)
end
