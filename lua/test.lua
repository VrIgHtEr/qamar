local mapping = {
	ethernet0 = 1184,
	ethernet1 = 1216,
	ethernet2 = 1248,
	ethernet3 = 1280,
	ethernet4 = 2208,
	pciBridge0 = 17,
	pciBridge4 = 21,
	pciBridge5 = 22,
	pciBridge6 = 23,
	pciBridge7 = 24,
}

local bit = require("bit")

local ordered = {}

for k, v in pairs(mapping) do
	if k:match("^ethernet[0-9]$") then
		local b = bit.tobit(v)
		local f1 = bit.band(bit.rshift(b, 10), 7)
		local b1 = bit.band(bit.rshift(b, 5), 31)
		local d1 = bit.band(b, 31)

		if b1 == 0 then
			error("b1 == 0")
		end
		local pci = mapping["pciBridge" .. tostring(b1 - 1)]
		if not pci then
			error("pciBridge" .. tostring(b1 - 1) .. " not found")
		end
		pci = bit.tobit(pci)
		local f2 = bit.band(bit.rshift(pci, 10), 7)
		local b2 = bit.band(bit.rshift(pci, 5), 31)
		local d2 = bit.band(pci, 31)

		if b2 ~= 0 then
			error("b2 ~= 0")
		end
		table.insert(ordered, {
			name = k,
			bus = 0,
			dev = d2,
			func = f1,
		})
	end
end

table.sort(ordered, function(a, b)
	if a.bus < b.bus then
		return true
	elseif a.bus > b.bus then
		return false
	end
	if a.dev < b.dev then
		return true
	elseif a.dev > b.dev then
		return false
	end
	if a.func < b.func then
		return true
	elseif a.func > b.func then
		return false
	end
	return false
end)

for _, x in ipairs(ordered) do
	print(x.name .. " - " .. bit.tohex(x.bus, 2) .. ":" .. bit.tohex(x.dev, 2) .. ":" .. bit.tohex(x.func, 2))
end
