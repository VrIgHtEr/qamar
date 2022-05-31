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
			local na = f .. ".na"
			s:new_not(na, { width = width }):c(f, "a", na, "a")
			s:add_component(f, opts)
			local pd = f .. ".d0"
			s:new_and_bank(pd):cp(1, na, "q", 1, pd, "a", 1):cp(1, f, "b", 1, pd, "b", 1)
			for i = 2, width do
				local a = f .. ".a" .. (i - 1)
				s:new_and_bank(a):cp(1, na, "q", i, a, "a", 1):cp(1, f, "b", i, a, "b", 1)
				local d = f .. ".d" .. (i - 1)
				s:new_or_bank(d):c(pd, "q", d, "a"):c(a, "q", d, "b")
				pd = d
			end
			s:c(pd, "q", f, "q")
		end
	)
end
