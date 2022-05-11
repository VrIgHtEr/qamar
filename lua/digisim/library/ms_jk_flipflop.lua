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
			opts = opts or {}
			opts.names = { inputs = { "j", "k", "clock_rising", "clock_falling" }, outputs = { "q", "~q" } }
			circuit:add_component(name, nil, opts)
			local q = name .. ".q"
			local m = name .. ".m"
			local qj = name .. ".qj"
			local qk = name .. ".qk"
			local mj = name .. ".mj"
			local mk = name .. ".mk"
			local lj = name .. ".lj"
			local lk = name .. ".lk"

			circuit
				:new_sr_latch(q)
				:new_sr_latch(m)
				:c(q, "q", name, "q")
				:c(q, "~q", name, "~q")
				:new_nand(qj)
				:new_nand(qk)
				:c(qj, "q", q, "s")
				:c(qk, "q", q, "r")
				:c(name, "clock_falling", qj, "a")
				:c(name, "clock_falling", qk, "a")
				:c(m, "q", qj, "b")
				:c(m, "~q", qk, "b")
				:new_nand(mj)
				:new_nand(mk)
				:c(mj, "q", m, "s")
				:c(mk, "q", m, "r")
				:c(name, "clock_rising", mj, "a")
				:c(name, "clock_rising", mk, "a")
				:new_and(lj)
				:new_and(lk)
				:c(lj, "q", mj, "b")
				:c(lk, "q", mk, "b")
				:c(name, "j", lj, "a")
				:c(name, "k", lk, "a")
				:c(q, "q", lk, "b")
				:c(q, "~q", lj, "b")
		end
	)
end
