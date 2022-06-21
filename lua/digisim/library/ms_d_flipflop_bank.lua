---@class simulation
---@field new_ms_d_flipflop_bank fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"ms_d_flipflop_bank",
		---@param s simulation
		---@param f string
		---@param opts boolean
		function(s, f, opts)
			opts = opts or { width = 1, logname = nil }
			local width = opts.width or 1
			if type(width) ~= "number" or width < 1 then
				error("invalid width")
			end
			width = math.floor(width)

			opts.names = {
				inputs = { { "d", width }, "rising", "falling", "rst~" },
				outputs = { { "q", width }, { "q~", width } },
			}

			s:add_component(f, opts)

			if opts.logname ~= nil then
				if type(opts.logname) ~= "string" then
					error("invalid logname")
				end
				local logger = f .. ".logger"
				s
					:add_component(logger, { names = { inputs = { { "value", width } } } }, function(_, input)
						s.log[opts.logname] = input
					end)
					:c(f, "q", logger, "value")
			end

			for i = 1, width do
				local d = f .. ".d" .. (i - 1)
				s:new_ms_d_flipflop(d, { logname = opts.logname })
				s:c(f, "rising", d, "rising")
				s:c(f, "falling", d, "falling")
				s:c(f, "rst~", d, "rst~")
				s:cp(1, f, "d", i, d, "d", 1)
				s:cp(1, d, "q", 1, f, "q", i)
				s:cp(1, d, "q~", 1, f, "q~", i)
			end
		end
	)
end
