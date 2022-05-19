---@class simulation
---@field new_ripple_adder fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"ripple_adder",
		---@param circuit simulation
		---@param name string
		---@param opts boolean
		function(circuit, name, opts)
			opts = opts or { width = 1 }
			local width = opts.width or 1
			if type(width) ~= "number" then
				error("invalid width type")
			end
			if width < 1 then
				error("invalid width")
			end
			opts.names = { inputs = { { "a", width }, { "b", width }, "cin" }, outputs = { { "sum", width }, "carry" } }

			circuit:add_component(name, opts)
			local n = name .. "."

			circuit:new_full_adder(n .. 0)
			circuit:cp(1, name, opts.names.inputs[1][1], 1, n .. 0, "a", 1)
			circuit:cp(1, name, opts.names.inputs[2][1], 1, n .. 0, "b", 1)
			circuit:c(name, opts.names.inputs[3], n .. 0, "c")
			circuit:cp(1, name, opts.names.outputs[1][1], 1, n .. 0, "sum", 1)

			for i = 1, width - 1 do
				circuit:new_full_adder(n .. i)
				circuit:cp(1, name, opts.names.inputs[1][1], i + 1, n .. i, "a", 1)
				circuit:cp(1, name, opts.names.inputs[2][1], i + 1, n .. i, "b", 1)
				circuit:c(n .. (i - 1), "carry", n .. i, "c")
				circuit:cp(1, name, opts.names.outputs[1][1], i + 1, n .. i, "sum", 1)
			end

			circuit:c(name, opts.names.outputs[2], n .. (width - 1), "carry")
		end
	)
end
