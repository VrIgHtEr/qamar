---@class simulation
---@field new_full_adder function

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
			circuit:add_component(adder, 3, 2, nil, opts)

			local xa = adder .. ".xa"
			local xb = adder .. ".xb"
			local aa = adder .. ".aa"
			local ab = adder .. ".ab"
			local o = adder .. ".o"

			circuit
				:new_xor(xa)
				:c(adder, "a", xa, "a")
				:c(adder, "b", xa, "b")
				:new_xor(xb)
				:c(xa, "q", xb, "a")
				:c(adder, "c", xb, "b")
				:c(xb, "q", adder, "sum")

			circuit
				:new_and(aa)
				:c(xa, "q", aa, "a")
				:c(adder, "c", aa, "b")
				:new_and(ab)
				:c(adder, "a", ab, "a")
				:c(adder, "b", ab, "b")
				:new_or(o)
				:c(aa, "q", o, "a")
				:c(ab, "q", o, "b")
				:c(o, "q", adder, "carry")
		end
	)
end
