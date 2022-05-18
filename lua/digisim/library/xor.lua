---@class simulation
---@field new_xor fun(circuit:simulation,name:string,opts:table|nil):simulation

local signal = require("digisim.signal")
local constants = require("digisim.constants")

local function build(self, root, parent, left, right)
	if left == right then
		return root, "in", left
	end
	local n = parent .. "."
	if right - left == 1 then
		local ac, ap, ao = build(self, root, n, left, left)
		local bc, bp, bo = build(self, root, n, right, right)
		local na = n .. "na"
		self:new_not(na):cp(1, ac, ap, ao, na, "a", 1)
		local nb = n .. "nb"
		self:new_not(nb):cp(1, bc, bp, bo, nb, "a", 1)
		local aa = n .. "aa"
		self:new_and(aa)
		self:cp(1, ac, ap, ao, aa, "in", 1)
		self:cp(1, nb, "q", 1, aa, "in", 2)
		local ba = n .. "ba"
		self:new_and(ba)
		self:cp(1, bc, bp, bo, ba, "in", 1)
		self:cp(1, na, "q", 1, ba, "in", 2)
		local o = n .. "o"
		self:new_or(o)
		self:cp(1, aa, "q", 1, o, "in", 1)
		self:cp(1, ba, "q", 1, o, "in", 2)
		return o, "q", 1
	end
	local mid = math.floor(left + (right - left) / 2)
	local lc, lp, lo = build(self, root, n .. "l", left, mid)
	local rc, rp, ro = build(self, root, n .. "r", mid + 1, right)
	local s = n .. "s"
	self:new_xor(s)
	self:cp(1, lc, lp, lo, s, "in", 1)
	self:cp(1, rc, rp, ro, s, "in", 2)
	return s, "q", 1
end

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"xor",
		---@param self simulation
		---@param name string
		---@param opts boolean
		function(self, name, opts)
			opts = opts or { width = 2 }
			local width = opts.width or 2
			if type(width) ~= "number" then
				error("invalid width type")
			end
			width = math.floor(width)
			if width < 2 then
				error("invalid width")
			end
			opts.names = { inputs = { { "in", width } }, outputs = { "q" } }
			if constants.NAND_ONLY then
				self:add_component(name, nil, opts)
				local component, port, offset = build(self, name, name, 1, width)
				self:cp(1, component, port, offset, name, "q", 1)
				return self
			else
				return self:add_component(name, function(_, a)
					local ret = false
					for _, x in ipairs(a) do
						if x == signal.high then
							ret = not ret
						end
					end
					return ret and signal.high or signal.low
				end, opts)
			end
		end
	)
end
