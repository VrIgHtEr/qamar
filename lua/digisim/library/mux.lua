---@class simulation
---@field new_mux function

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"mux",
		---@param circuit simulation
		---@param name string
		---@param opts boolean
		function(circuit, name, opts)
			opts = opts or { width = 1 }
			local width = opts.width or 1
			if type(width) ~= "number" or width < 1 or width > 16 then
				error("invalid width type")
			end
			width = math.floor(width)
			opts.names = { inputs = {}, outputs = { "q" } }
			for i = 1, width do
				opts.names.inputs[i] = "a" .. (i - 1)
			end
			local datapins = math.pow(2, width)
			for i = 1, datapins do
				opts.names.inputs[width + i] = "i" .. (i - 1)
			end
			circuit:add_component(name, nil, opts)

			local zero = name .. ".lo"
			local one = name .. ".hi"
			local inv = name .. ".n"
			local o = name .. ".o"

			if width == 1 then
				circuit
					:new_and(zero)
					:new_and(one)
					:new_or(o)
					:cp(1, zero, "q", 1, o, "in", 1)
					:cp(1, one, "q", 1, o, "in", 2)
					:c(o, "q", name, "q")
					:new_not(inv)
					:c(name, "a0", inv, "a")
					:cp(1, inv, "q", 1, zero, "in", 1)
					:cp(1, name, "a0", 1, one, "in", 1)
					:cp(1, name, "i0", 1, zero, "in", 2)
					:cp(1, name, "i1", 1, one, "in", 2)
			else
				circuit:new_mux(zero, { width = width - 1 })
				circuit:new_mux(one, { width = width - 1 })
				for i = 1, width - 1 do
					circuit:c(name, "a" .. (i - 1), zero, "a" .. (i - 1))
					circuit:c(name, "a" .. (i - 1), one, "a" .. (i - 1))
				end
				for i = 1, datapins * 0.5 do
					circuit:c(name, "i" .. (i - 1), zero, "i" .. (i - 1))
					circuit:c(name, "i" .. (i + (datapins * 0.5) - 1), one, "i" .. (i - 1))
				end
				local az = name .. ".az"
				local ao = name .. ".ao"
				circuit
					:new_and(az)
					:new_and(ao)
					:new_not(inv)
					:c(name, "a" .. (width - 1), inv, "a")
					:cp(1, zero, "q", 1, az, "in", 1)
					:cp(1, one, "q", 1, ao, "in", 1)
					:cp(1, inv, "q", 1, az, "in", 2)
					:cp(1, name, "a" .. (width - 1), 1, ao, "in", 2)
					:new_or(o)
					:cp(1, az, "q", 1, o, "in", 1)
					:cp(1, ao, "q", 1, o, "in", 2)
					:c(o, "q", name, "q")
			end
		end
	)
end
