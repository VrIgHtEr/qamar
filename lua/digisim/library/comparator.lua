---@class simulation
---@field new_comparator fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"comparator",
		---@param s simulation
		---@param f string
		---@param opts boolean
		function(s, f, opts)
			opts = opts or { width = 1 }
			local width = opts.width or 1
			if type(width) ~= "number" or width < 1 then
				error("invalid width")
			end
			width = math.floor(width)
			opts.names = { inputs = { { "a", width }, { "b", width } }, outputs = { "q" } }
			s:add_component(f, opts)
			local d = f .. ".d"
			s:new_and_bank(d, { width = width }):c(f, "a", d, "a"):c(f, "b", d, "b")
			local out = f .. ".out"
			s:new_or(out, { width = width }):c(d, "q", out, "in"):c(out, "q", f, "q")
		end
	)
end
