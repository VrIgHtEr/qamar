---@class simulation
---@field new_random fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"random",
		---@param circuit simulation
		---@param name string
		---@param opts boolean
		function(circuit, name, opts)
			opts = opts or { width = 1, period = 1 }
			local width = opts.width or 1
			local period = opts.period or 1
			if type(width) ~= "number" then
				error("invalid width type")
			end
			if width < 1 then
				error("invalid width")
			end
			if type(period) ~= "number" then
				error("invalid period type")
			end
			period = math.floor(period)
			if period < 1 then
				error("invalid period")
			end

			opts.names = { inputs = {}, outputs = {} }
			opts.names.outputs[1] = { "q", width }

			local vals = {}
			for i = 1, width do
				vals[i] = math.random(0, 1)
			end
			circuit:add_component(name, function(time)
				local t = time % period
				if t == 0 then
					for i = 1, width do
						vals[i] = math.random(0, 1)
					end
				end
				return vals
			end, opts)
		end
	)
end
