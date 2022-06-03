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

			local na = f .. ".na"
			s:new_not(na, { width = width }):c(f, "a", na, "a")
			local altb = f .. "a_lt_b"
			s:new_and_bank(altb, { width = width }):c(f, "b", altb, "a"):c(na, "q", altb, "b")
			local nb = f .. ".nb"
			local agtb = f .. "a_gt_b"
			if width > 1 then
				s:new_not(nb, { width = width }):c(f, "b", nb, "a")
				s:new_and_bank(agtb, { width = width }):c(f, "a", agtb, "a"):c(nb, "q", agtb, "b")
			end

			local pname, pport, ppin = altb, "q", 1
			for i = 2, width do
				local n = f .. ".n" .. (i - 1)
				s:new_not(n):cp(1, agtb, "q", i, n, "a", 1)
				local a = f .. ".a" .. (i - 1)
				s:new_and_bank(a):c(n, "q", a, "a"):cp(1, pname, pport, ppin, a, "b", 1)
				local b = f .. ".b" .. (i - 1)
				s:new_or_bank(b):cp(1, altb, "q", i, b, "a", 1):c(a, "q", b, "b")
				pname, pport, ppin = b, "q", 1
			end
			s:cp(1, pname, pport, ppin, f, "q", 1)
		end
	)
end
