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

			circuit:add_component(name, width * 2 + 1, width + 1)
			local n = name .. "."

			circuit:new_full_adder(n .. 0)
			circuit:alias_input(name, 1, n .. 0, 1)
			circuit:alias_input(name, width + 1, n .. 0, 2)
			circuit:alias_input(name, width * 2 + 1, n .. 0, 3)
			circuit:alias_output(name, 1, n .. 0, 1)

			for i = 1, width - 1 do
				circuit:new_full_adder(n .. i)
				circuit:alias_input(name, i + 1, n .. i, 1)
				circuit:alias_input(name, width + i + 1, n .. i, 2)
				circuit:alias_output(name, i + 1, n .. i, 1)
				circuit:_(n .. (i - 1), 2, n .. i, 3)
			end

			circuit:alias_output(name, width + 1, n .. (width - 1), 2)
		end
	)
end
