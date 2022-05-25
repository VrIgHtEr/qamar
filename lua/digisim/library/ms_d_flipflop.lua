---@class simulation
---@field new_ms_d_flipflop fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"ms_d_flipflop",
		---@param s simulation
		---@param f string
		---@param opts boolean
		function(s, f, opts)
			opts = opts or {}
			opts.names = { inputs = { "d", "clk", "rst~" }, outputs = { "q", "q~" } }
			s:add_component(f, opts)

			local qb = f .. ".qb"
			local qn = f .. ".qn"
			local mb = f .. ".mb"
			local mn = f .. ".mn"
			local qrb = f .. ".qrb"
			local qrn = f .. ".qrn"
			local mrb = f .. ".mrb"
			local mrn = f .. ".mrn"
			local qsb = f .. ".qsb"
			local qsn = f .. ".qsn"
			local dmb = f .. ".dmb"
			local dmn = f .. ".dmn"
			local r = f .. ".rn"
			local d = f .. ".dn"
			local c = f .. ".cn"

			s:new_not(r)
			s:c(f, "rst~", r, "a")
			s:new_not(c)
			s:c(f, "clk", c, "a")
			s:new_nand_bank(qb):new_nand_bank(qn)
			s:c(qb, "q", f, "q")
			s:c(qn, "q", f, "q~")
			s:c(qb, "q", qn, "a")
			s:c(qn, "q", qb, "a")
			s:new_or_bank(qrb):new_and_bank(qrn)
			s:c(qrb, "q", qb, "b")
			s:c(qrn, "q", qn, "b")
			s:c(r, "q", qrb, "a")
			s:c(f, "rst~", qrn, "a")
			s:new_nand_bank(qsb):new_nand_bank(qsn)
			s:c(qsb, "q", qrb, "b")
			s:c(qsn, "q", qrn, "b")
			s:c(c, "q", qsb, "a")
			s:c(c, "q", qsn, "a")
			s:new_nand_bank(mb):new_nand_bank(mn)
			s:c(mb, "q", qsb, "b")
			s:c(mn, "q", qsn, "b")
			s:c(mb, "q", mn, "a")
			s:c(mn, "q", mb, "a")
			s:new_or_bank(mrb):new_and_bank(mrn)
			s:c(mrb, "q", mb, "b")
			s:c(mrn, "q", mn, "b")
			s:c(r, "q", mrb, "a")
			s:c(f, "rst~", mrn, "a")
			s:new_nand_bank(dmb):new_nand_bank(dmn)
			s:c(dmb, "q", mrb, "b")
			s:c(dmn, "q", mrn, "b")
			s:c(f, "clk", dmb, "a")
			s:c(f, "clk", dmn, "a")
			s:new_not(d)
			s:c(f, "d", dmb, "b")
			s:c(d, "q", dmn, "b")
			s:c(f, "d", d, "a")
		end
	)
end
