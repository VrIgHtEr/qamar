---@class simulation
---@field new_instruction_decoder fun(circuit:simulation,name:string,opts:table|nil):simulation

---@param simulation simulation
return function(simulation)
	simulation:register_component(
		"instruction_decoder",
		---@param self simulation
		---@param dec string
		---@param opts boolean
		function(self, dec, opts)
			opts = opts or {}
			opts.names = {
				inputs = { { "in", 32 } },
				outputs = {
					"r",
					"i",
					"s",
					"b",
					"u",
					"j",
					"illegal",
					{ "opcode", 7 },
					{ "rd", 5 },
					{ "funct3", 3 },
					{ "rs1", 5 },
					{ "rs2", 5 },
					{ "funct7", 7 },
					{ "imm", 32 },
				},
			}
			self:add_component(dec, opts)
			self:cp(7, dec, "in", 1, dec, "opcode", 1)
			self:cp(5, dec, "in", 8, dec, "rd", 1)
			self:cp(3, dec, "in", 13, dec, "funct3", 1)
			self:cp(5, dec, "in", 16, dec, "rs1", 1)
			self:cp(5, dec, "in", 21, dec, "rs2", 1)
			self:cp(7, dec, "in", 26, dec, "funct7", 1)

			-- decode I immediate
			local immi = dec .. ".immi"
			self:new_tristate_buffer(immi, { width = 32 })
			self:c(dec, "i", immi, "en")
			self:cp(12, dec, "in", 21, immi, "a", 1)
			for i = 13, 32 do
				self:cp(1, dec, "in", 32, immi, "a", i)
			end
			self:c(immi, "q", dec, "imm")

			-- decode S immediate
			local imms = dec .. ".imms"
			self:new_tristate_buffer(imms, { width = 32 })
			self:c(dec, "s", imms, "en")
			self:cp(5, dec, "in", 8, imms, "a", 1)
			self:cp(7, dec, "in", 26, imms, "a", 6)
			for i = 13, 32 do
				self:cp(1, dec, "in", 32, imms, "a", i)
			end
			self:c(imms, "q", dec, "imm")

			-- decode B immediate
			local immb = dec .. ".immb"
			self:new_tristate_buffer(immb, { width = 32 })
			self:c(dec, "b", immb, "en")
			self:cp(1, "GND", "q", 1, immb, "a", 1)
			self:cp(4, dec, "in", 9, immb, "a", 2)
			self:cp(6, dec, "in", 26, immb, "a", 6)
			self:cp(1, dec, "in", 8, immb, "a", 12)
			self:cp(1, dec, "in", 32, immb, "a", 13)
			for i = 14, 32 do
				self:cp(1, dec, "in", 32, immb, "a", i)
			end
			self:c(immb, "q", dec, "imm")

			-- decode U immediate
			local immu = dec .. ".immu"
			self:new_tristate_buffer(immu, { width = 32 })
			self:c(dec, "u", immu, "en")
			self:cp(20, dec, "in", 13, immu, "a", 13)
			for i = 1, 12 do
				self:cp(1, "GND", "q", 1, immu, "a", i)
			end
			self:c(immu, "q", dec, "imm")

			-- decode J immediate
			local immj = dec .. ".immj"
			self:new_tristate_buffer(immj, { width = 32 })
			self:c(dec, "j", immj, "en")
			self:cp(1, "GND", "q", 1, immj, "a", 1)
			self:cp(10, dec, "in", 22, immj, "a", 2)
			self:cp(1, dec, "in", 21, immj, "a", 12)
			self:cp(8, dec, "in", 13, immj, "a", 13)
			self:cp(1, dec, "in", 32, immj, "a", 21)
			for i = 22, 32 do
				self:cp(1, dec, "in", 32, immj, "a", i)
			end
			self:c(immj, "q", dec, "imm")

			local n = dec .. "."
			local nec = n .. "i"
			self:new_not(nec, { width = 32 }):c(dec, "in", nec, "a")

			local A = n .. "A"
			self:new_and(A):cp(1, dec, "in", 2, A, "in", 1):cp(1, dec, "in", 1, A, "in", 2)
			local J = n .. "J"
			self:new_and(J):cp(1, dec, "in", 4, J, "in", 1):cp(1, dec, "in", 3, J, "in", 2)
			local F = n .. "F"
			self:new_and(F):cp(1, nec, "a", 14, F, "in", 1):cp(1, nec, "a", 15, F, "in", 2)
			local B = n .. "B"
			self
				:new_and(B, { width = 3 })
				:cp(1, nec, "a", 28, B, "in", 1)
				:cp(1, nec, "a", 27, B, "in", 2)
				:cp(1, nec, "a", 26, B, "in", 3)
			local C = n .. "C"
			self
				:new_and(C, { width = 3 })
				:cp(1, nec, "a", 32, C, "in", 1)
				:cp(1, nec, "a", 30, C, "in", 2)
				:cp(1, nec, "a", 29, C, "in", 3)
			local E = n .. "E"
			self:new_and(E):cp(1, B, "q", 1, E, "in", 1):cp(1, C, "q", 1, E, "in", 2)
			local S = n .. "S"
			self:new_and(S):cp(1, E, "q", 1, S, "in", 1):cp(1, F, "q", 1, S, "in", 2)
			local H = n .. "H"
			self
				:new_and(H, { width = 3 })
				:cp(1, S, "q", 1, H, "in", 1)
				:cp(1, dec, "in", 7, H, "in", 2)
				:cp(1, dec, "in", 6, H, "in", 3)
			local T = n .. "T"
			self:new_and(T):cp(1, H, "q", 1, T, "in", 1):cp(1, nec, "q", 5, T, "in", 2)
			local V = n .. "V"
			self:new_and(V):cp(1, T, "q", 1, V, "in", 1):cp(1, J, "q", 1, V, "in", 2)

			local D = n .. "D"
			self
				:new_and(D, { width = 3 })
				:cp(1, S, "q", 1, D, "in", 1)
				:cp(1, nec, "q", 7, D, "in", 2)
				:cp(1, nec, "q", 4, D, "in", 3)

			local G = n .. "G"
			self
				:new_and(G, { width = 3 })
				:cp(1, D, "q", 1, G, "in", 1)
				:cp(1, dec, "in", 3, G, "in", 2)
				:cp(1, dec, "in", 5, G, "in", 3)

			--[[
A = b1b2
J = b4 b3
F = !b15!b14
B = !b28!b27!b26
C = !b32!b30!b29
E = BC
S = E F
H = S b7 b6
T = H !b5
V = T J
D = S!b7!b4
G = b3 D b5

I = !b4 !b3
K = S !b7 !b6 J !b5
L = !b3 D
M = !b6 L
N = b6 L
O = b5 M
P = H I
Q = b5 P
R = !b5 P
U = R S
W = b5 E

========================================
             BBBB
   B   B  BB 1113      B
VKS7NOM6LJ43D5431CBEFGH5WPQRTSU   RISBUJ
========================================
----1--------101--------1------ | 1.....
----1-----------0-------1------ | 1.....
----1----------0-------1-----1- | 1.....
-1--------------0------------1- | 1.....
-1-------------001--1---------- | 1.....
------1------0-0--------------- | .1....
-----1-------1-----1----------- | .1....
-----1----------0--1----------- | .1....
-----1---------0--------------- | .1....
-----1--------1---------------- | .1....
------1-------0--------0------- | .1....
-------------0--0--1------1---- | .1....
---------------1----------1---- | .1....
--------------1-----------1---- | .1....
----------01---0----1-------1-- | .1....
----1---------------1--0------- | ..1...
----1--------0-0-------0------- | ..1...
-------------1----------------1 | ...1..
--------------0---------------1 | ...1..

---------------------1--------- | ....1.
1------------------------------ | .....1

]]
			self:c(G, "q", dec, "u")
			self:c(V, "q", dec, "j")
			return self
		end
	)
end
