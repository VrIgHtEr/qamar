---@class simulation
---@field new_full_adder fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"full_adder",
		---@param circuit simulation
		---@param adder string
		---@param opts boolean
		function(circuit, adder, opts)
			opts = opts or {}
			opts.names = { inputs = { "a", "b", "c" }, outputs = { "sum", "carry" } }
			circuit:add_component(adder, opts)

			local ha = adder .. ".ha"
			local hb = adder .. ".hb"
			local o = adder .. ".o"

			circuit
				:new_half_adder(ha)
				:c(adder, "a", ha, "a")
				:c(adder, "b", ha, "b")
				:new_half_adder(hb)
				:c(adder, "c", hb, "a")
				:c(ha, "sum", hb, "b")
				:c(hb, "sum", adder, "sum")
				:new_or(o)
				:cp(1, ha, "carry", 1, o, "in", 1)
				:cp(1, hb, "carry", 1, o, "in", 2)
				:c(o, "q", adder, "carry")
		end
	)
end
