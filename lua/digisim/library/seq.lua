---@class simulation
---@field new_seq fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"seq",
		---@param sim simulation
		---@param seq string
		---@param opts boolean
		function(sim, seq, opts)
			opts = opts or { width = 1, loop = false }
			local width = opts.width or 1
			if type(width) ~= "number" then
				error("invalid width type")
			end
			if width < 1 then
				error("invalid width")
			end
			local loop = opts.loop and true or false
			opts.names = {
				inputs = {
					"rising",
					"rst~",
				},
				outputs = {
					{ "out", width },
				},
			}

			sim:add_component(seq, opts)

			local n = seq .. "."
			local nrst = n .. "nrst"
			sim:new_not(nrst):c(seq, "rst~", nrst, "a")

			for i = 1, width do
				local s = n .. "stage" .. (i - 1) .. "."

				-- create latch and connect its q to the corresponding output bit
				local latch = s .. "L"
				sim:new_sr_latch(latch)
				sim:cp(1, latch, "q", 1, seq, "out", i)

				--reset logic
				local rs = s .. "rs"
				local rr = s .. "rl"
				if i == 1 then
					sim:new_and_bank(rs)
					sim:c(seq, "rst~", rs, "a")
					sim:new_or_bank(rr)
					sim:c(nrst, "q", rr, "a")
				else
					sim:new_or_bank(rs)
					sim:c(nrst, "q", rs, "a")
					sim:new_and_bank(rr)
					sim:c(seq, "rst~", rr, "a")
				end
				sim:c(rs, "q", latch, "s")
				sim:c(rr, "q", latch, "r")

				--clock gating logic
				local cs = s .. "cs"
				sim:new_nand_bank(cs)
				sim:c(cs, "q", rs, "b")
				sim:c(seq, "rising", cs, "a")

				local cr = s .. "cr"
				sim:new_nand_bank(cr)
				sim:c(cr, "q", rr, "b")
				sim:c(seq, "rising", cr, "a")

				local dn = s .. "dn"
				sim:new_not(dn)
				sim:c(dn, "a", cs, "b")
				sim:c(dn, "q", cr, "b")
				if i > 1 then
					sim:c(n .. "stage" .. (i - 2) .. ".L", "q", dn, "a")
				end
			end
			if loop then
				sim:c(n .. "stage" .. (width - 1) .. ".L", "q", n .. "stage0.dn", "a")
			else
				sim:c("GND", "q", n .. "stage0.dn", "a")
			end
			return sim
		end
	)
end
