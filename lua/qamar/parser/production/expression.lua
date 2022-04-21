local parselet = require("qamar.parser.parselet")

local p = require("qamar.parser")
local peek = p.peek
local take = p.take
local begin = p.begin
local undo = p.undo
local commit = p.commit
local next_id = p.next_id
local take_until = p.take_until

---gets the precedence of the next available token
---@param self parser
---@return number
local function get_precedence(self)
	local next = peek(self)
	if next then
		local infix = parselet.infix[next.type]
		if infix then
			return infix.precedence
		end
	end
	return 0
end

local M = {}

local ind = 0
local function stderr(x)
	io.stderr:write(string.rep("  ", ind) .. x)
	io.stderr:flush()
end
local function indent()
	ind = ind + 1
end
local function dedent()
	if ind > 0 then
		ind = ind - 1
	end
end

local types = require("qamar.lexer.types")

---try to consume a lua expression
---@param self parser
---@param precedence number|nil
---@return node_expression|nil
function M:parser(precedence)
	precedence = precedence or 0
	stderr("EXP: " .. precedence .. "\n")
	local id = next_id(self)
	if precedence == 0 then
		local item = self.cache[id]
		if item then
			take_until(self, item.last)
			return item.value
		elseif item ~= nil then
			return
		end
	end
	local tok = peek(self)
	if tok then
		stderr("PREFIX TOKEN: " .. tostring(tok) .. " : " .. tostring(types[tok.type]))
		local prefix = parselet.prefix[tok.type]
		if prefix then
			stderr(": MATCH\n")
			begin(self)
			take(self)
			indent()
			local left = prefix:parse(self, tok)
			dedent()
			if not left then
				if precedence == 0 then
					self.cache[id] = { last = next_id(self), value = false }
				end
				undo(self)
				return
			end
			while precedence < get_precedence(self) do
				tok = peek(self)
				if not tok then
					commit(self)
					if precedence == 0 then
						self.cache[id] = { last = next_id(), value = left }
					end
					stderr("RETURNING: " .. tostring(left) .. ":" .. next_id(self) .. "\n")
					return left
				end
				stderr("INFIX TOKEN: " .. tostring(tok) .. " : " .. tostring(types[tok.type]))
				local infix = parselet.infix[tok.type]
				if not infix then
					stderr(" : MISMATCH\n")
					commit(self)
					if precedence == 0 then
						self.cache[id] = { last = next_id(), value = left }
					end
					stderr("RETURNING: " .. tostring(left) .. ":" .. next_id(self) .. "\n")
					return left
				else
					stderr(" : MATCH\n")
				end
				begin(self)
				take(self)
				indent()
				local right = infix:parse(self, left, tok)
				dedent()
				if not right then
					undo(self)
					undo(self)
					if precedence == 0 then
						self.cache[id] = { last = next_id(self), value = left }
					end
					stderr("RETURNING: " .. tostring(left) .. ":" .. next_id(self) .. "\n")
					return left
				else
					commit(self)
					left = right
				end
			end
			commit(self)
			if precedence == 0 then
				self.cache[id] = { last = next_id(self), value = left }
			end
			stderr("RETURNING: " .. tostring(left) .. ":" .. next_id(self) .. "\n")
			return left
		elseif precedence == 0 then
			stderr(": PREFIX NOT MATCHED\n")
			self.cache[id] = { last = next_id(self), value = false }
		end
	elseif precedence == 0 then
		self.cache[id] = { last = next_id(self), value = false }
	end
end

return M
