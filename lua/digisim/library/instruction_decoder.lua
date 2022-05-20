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
			self:new_and(F):cp(1, nec, "q", 14, F, "in", 1):cp(1, nec, "q", 15, F, "in", 2)
			local B = n .. "B"
			self
				:new_and(B, { width = 3 })
				:cp(1, nec, "q", 28, B, "in", 1)
				:cp(1, nec, "q", 27, B, "in", 2)
				:cp(1, nec, "q", 26, B, "in", 3)
			local C = n .. "C"
			self
				:new_and(C, { width = 3 })
				:cp(1, nec, "q", 32, C, "in", 1)
				:cp(1, nec, "q", 30, C, "in", 2)
				:cp(1, nec, "q", 29, C, "in", 3)
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
			self:c(V, "q", dec, "j")
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
			self:c(G, "q", dec, "u")

			local I = n .. "I"
			self:new_and(I):cp(1, nec, "q", 3, I, "in", 1):cp(1, nec, "q", 4, I, "in", 2)
			local P = n .. "P"
			self:new_and(P):cp(1, H, "q", 1, P, "in", 1):cp(1, I, "q", 1, P, "in", 2)
			local R = n .. "R"
			self:new_and(R):cp(1, P, "q", 1, R, "in", 1):cp(1, nec, "q", 5, R, "in", 2)
			local U = n .. "U"
			self:new_and(U):cp(1, R, "q", 1, U, "in", 1):cp(1, S, "q", 1, U, "in", 2)
			local B1 = n .. "B1"
			self:new_and(B1):cp(1, U, "q", 1, B1, "in", 1):cp(1, dec, "in", 15, B1, "in", 2)
			local B2 = n .. "B2"
			self:new_and(B2):cp(1, U, "q", 1, B2, "in", 1):cp(1, nec, "q", 14, B2, "in", 2)
			local B3 = n .. "B3"
			self:new_or(B3):cp(1, B1, "q", 1, B3, "in", 1):cp(1, B2, "q", 1, B3, "in", 2)
			self:c(B3, "q", dec, "b")
			local W = n .. "W"
			self:new_and(W):cp(1, E, "q", 1, W, "in", 1):cp(1, dec, "in", 5, W, "in", 2)
			local Q = n .. "Q"
			self:new_and(Q):cp(1, P, "q", 1, Q, "in", 1):cp(1, dec, "in", 5, Q, "in", 2)
			local L = n .. "L"
			self:new_and(L):cp(1, D, "q", 1, L, "in", 1):cp(1, nec, "q", 3, L, "in", 2)
			local M = n .. "M"
			self:new_and(M):cp(1, L, "q", 1, M, "in", 1):cp(1, nec, "q", 6, M, "in", 2)
			local N = n .. "N"
			self:new_and(N):cp(1, L, "q", 1, N, "in", 1):cp(1, dec, "in", 6, N, "in", 2)
			local O = n .. "O"
			self:new_and(O):cp(1, N, "q", 1, O, "in", 1):cp(1, dec, "in", 5, O, "in", 2)
			local K = n .. "K"
			self
				:new_and(K, { width = 5 })
				:cp(1, S, "q", 1, K, "in", 1)
				:cp(1, J, "q", 1, K, "in", 2)
				:cp(1, nec, "q", 5, K, "in", 3)
				:cp(1, nec, "q", 6, K, "in", 4)
				:cp(1, nec, "q", 7, K, "in", 5)
			local S1 = n .. "S1"
			self
				:new_and(S1, { width = 3 })
				:cp(1, N, "q", 1, S1, "in", 1)
				:cp(1, F, "q", 1, S1, "in", 2)
				:cp(1, nec, "q", 5, S1, "in", 3)
			local S2 = n .. "S2"
			self
				:new_and(S2, { width = 4 })
				:cp(1, N, "q", 1, S2, "in", 1)
				:cp(1, nec, "q", 13, S2, "in", 3)
				:cp(1, nec, "q", 15, S2, "in", 3)
				:cp(1, nec, "q", 5, S2, "in", 3)
			local S3 = n .. "S3"
			self:new_or(S3):cp(1, S1, "q", 1, S3, "in", 1):cp(1, S2, "q", 1, S3, "in", 2)
			self:c(S3, "q", dec, "s")
			local R1 = n .. "R1"
			self
				:new_and(R1, { width = 5 })
				:cp(1, N, "q", 1, R1, "in", 1)
				:cp(1, W, "q", 1, R1, "in", 2)
				:cp(1, dec, "in", 13, R1, "in", 3)
				:cp(1, nec, "q", 14, R1, "in", 4)
				:cp(1, dec, "in", 15, R1, "in", 5)
			local R2 = n .. "R2"
			self
				:new_and(R2, { width = 3 })
				:cp(1, N, "q", 1, R2, "in", 1)
				:cp(1, W, "q", 1, R2, "in", 2)
				:cp(1, nec, "q", 31, R2, "in", 3)
			local R3 = n .. "R3"
			self
				:new_and(R3, { width = 4 })
				:cp(1, N, "q", 1, R3, "in", 1)
				:cp(1, nec, "q", 13, R3, "in", 2)
				:cp(1, dec, "in", 5, R3, "in", 3)
				:cp(1, S, "q", 1, R3, "in", 4)
			local R4 = n .. "R4"
			self
				:new_and(R4, { width = 3 })
				:cp(1, K, "q", 1, R4, "in", 1)
				:cp(1, S, "q", 1, R4, "in", 2)
				:cp(1, nec, "q", 31, R4, "in", 3)
			local R5 = n .. "R5"
			self
				:new_and(R5, { width = 5 })
				:cp(1, K, "q", 1, R5, "in", 1)
				:cp(1, F, "q", 1, R5, "in", 2)
				:cp(1, C, "q", 1, R5, "in", 3)
				:cp(1, nec, "q", 31, R5, "in", 4)
				:cp(1, nec, "q", 13, R5, "in", 5)

			local R6 = n .. "R6"
			self
				:new_or(R6, { width = 6 })
				:cp(1, R1, "q", 1, R6, "in", 1)
				:cp(1, R2, "q", 1, R6, "in", 2)
				:cp(1, R3, "q", 1, R6, "in", 3)
				:cp(1, R4, "q", 1, R6, "in", 4)
				:cp(1, R5, "q", 1, R6, "in", 5)
				:c(R6, "q", dec, "r")

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
P = H I
R = !b5 P
U = R S
W = b5 E
Q = b5 P
L = !b3 D
M = !b6 L
N = b6 L
O = b5 M
K = S !b7 !b6 J !b5

========================================
             BBBB
   B   B  BB 1113      B
VKS7NOM6LJ43D5431CBEFGH5WPQRTSU   RISBUJ
========================================
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

]]
			local illegal = n .. "illegal"
			self
				:new_nor(illegal, { width = 6 })
				:cp(1, illegal, "in", 1, dec, "r", 1)
				:cp(1, illegal, "in", 2, dec, "i", 1)
				:cp(1, illegal, "in", 3, dec, "s", 1)
				:cp(1, illegal, "in", 4, dec, "b", 1)
				:cp(1, illegal, "in", 5, dec, "u", 1)
				:c(illegal, "q", dec, "illegal")
				:cp(1, illegal, "in", 6, dec, "j", 1)
			self:new_pulldown(n .. "PI"):c(n .. "PI", "q", dec, "i")
			return self
		end
	)
end
