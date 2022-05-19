---@class simulation
---@field new_ms_jk_flipflop fun(circuit:simulation,name:string,opts:table|nil):simulation

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
			circuit:add_component(name, opts)
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
				:cp(1, name, "clock_falling", 1, qj, "in", 1)
				:cp(1, name, "clock_falling", 1, qk, "in", 1)
				:cp(1, m, "q", 1, qj, "in", 2)
				:cp(1, m, "~q", 1, qk, "in", 2)
				:new_nand(mj)
				:new_nand(mk)
				:c(mj, "q", m, "s")
				:c(mk, "q", m, "r")
				:new_and(lj)
				:new_and(lk)
				:cp(1, name, "clock_rising", 1, mj, "in", 1)
				:cp(1, name, "clock_rising", 1, mk, "in", 1)
				:cp(1, lj, "q", 1, mj, "in", 2)
				:cp(1, lk, "q", 1, mk, "in", 2)
				:cp(1, name, "j", 1, lj, "in", 1)
				:cp(1, name, "k", 1, lk, "in", 1)
				:cp(1, q, "q", 1, lk, "in", 2)
				:cp(1, q, "~q", 1, lj, "in", 2)
		end
	)
end
