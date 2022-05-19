---@class simulation
---@field new_mux_bank fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"mux_bank",
		---@param circuit simulation
		---@param mux string
		---@param opts boolean
		function(circuit, mux, opts)
			opts = opts or { bits = 1, width = 1 }
			local width = opts.width or 1
			local bits = opts.bits or 1
			if type(width) ~= "number" then
				error("invalid width type")
			end
			width = math.floor(width)
			if width < 1 or width > 10 then
				error("invalid width")
			end
			if type(bits) ~= "number" then
				error("invalid bits type")
			end
			bits = math.floor(bits)
			if bits < 1 then
				error("invalid bits")
			end

			local inputs = {}
			opts.names = {
				inputs = inputs,
				outputs = { { "out", bits } },
			}

			local n = mux .. "."
			local numinputs = math.pow(2, width)
			for i = 1, numinputs do
				inputs[i] = { "d" .. (i - 1), bits }
			end
			inputs[numinputs + 1] = { "sel", width }

			circuit:add_component(mux, opts)

			local dn = n .. "n"
			local a = n .. "a"
			local b = n .. "b"
			local o = n .. "o"

			circuit:new_not(dn):cp(1, mux, "sel", width, dn, "a", 1)
			circuit:new_and_bank(a, { width = bits })
			circuit:new_and_bank(b, { width = bits })
			circuit:new_or_bank(o, { width = bits }):c(a, "q", o, "a"):c(b, "q", o, "b")
			circuit:c(o, "q", mux, "out")
			for i = 1, bits do
				circuit:cp(1, dn, "q", 1, a, "b", i)
				circuit:cp(1, mux, "sel", width, b, "b", i)
			end

			if width == 1 then
				circuit:c(mux, "d0", a, "a")
				circuit:c(mux, "d1", b, "a")
			else
				local ma = n .. "ma"
				local mb = n .. "mb"

				circuit:new_mux_bank(ma, { width = width - 1, bits = bits })
				circuit:cp(width - 1, mux, "sel", 1, ma, "sel", 1)

				circuit:new_mux_bank(mb, { width = width - 1, bits = bits })
				circuit:cp(width - 1, mux, "sel", 1, mb, "sel", 1)

				local halfinputs = numinputs / 2
				for i = 1, halfinputs do
					circuit:c(mux, "d" .. (i - 1), ma, "d" .. (i - 1))
					circuit:c(mux, "d" .. (i + halfinputs - 1), mb, "d" .. (i - 1))
				end
				circuit:c(ma, "out", a, "a")
				circuit:c(mb, "out", b, "a")
			end
		end
	)
end
