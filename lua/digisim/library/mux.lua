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
					:c(zero, "q", o, "a")
					:c(one, "q", o, "b")
					:c(o, "q", name, "q")
					:new_not(inv)
					:c(inv, "q", zero, "a")
					:c(name, "a0", inv, "a")
					:c(name, "a0", one, "a")
					:c(name, "i0", zero, "b")
					:c(name, "i1", one, "b")
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
					:c(zero, "q", az, "a")
					:new_and(ao)
					:c(one, "q", ao, "a")
					:new_not(inv)
					:c(name, "a" .. (width - 1), inv, "a")
					:c(inv, "q", az, "b")
					:c(name, "a" .. (width - 1), ao, "b")
					:new_or(o)
					:c(az, "q", o, "a")
					:c(ao, "q", o, "b")
					:c(o, "q", name, "q")
			end
		end
	)
end
