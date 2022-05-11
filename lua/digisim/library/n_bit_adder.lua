---@class simulation
---@field new_n_bit_adder function

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"n_bit_adder",
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
			opts.names = { inputs = {}, outputs = {} }
			for i = 1, width do
				opts.names.inputs[i] = "a" .. (i - 1)
				opts.names.outputs[i] = "c" .. (i - 1)
			end
			for i = 1, width do
				opts.names.inputs[i + width] = "b" .. (i - 1)
			end
			opts.names.inputs[width * 2 + 1] = "cin"
			opts.names.outputs[width + 1] = "cout"

			circuit:add_component(name, nil, opts)
			local n = name .. "."

			circuit:new_full_adder(n .. 0)
			circuit:c(name, opts.names.inputs[1], n .. 0, "a")
			circuit:c(name, opts.names.inputs[width + 1], n .. 0, "b")
			circuit:c(name, opts.names.inputs[width * 2 + 1], n .. 0, "c")
			circuit:c(name, opts.names.outputs[1], n .. 0, "sum")

			for i = 1, width - 1 do
				circuit:new_full_adder(n .. i)
				circuit:c(name, opts.names.inputs[i + 1], n .. i, "a")
				circuit:c(name, opts.names.inputs[width + i + 1], n .. i, "b")
				circuit:c(name, opts.names.outputs[i + 1], n .. i, "sum")
				circuit:c(n .. (i - 1), "carry", n .. i, "c")
			end

			circuit:c(name, opts.names.outputs[width + 1], n .. (width - 1), "carry")
		end
	)
end
