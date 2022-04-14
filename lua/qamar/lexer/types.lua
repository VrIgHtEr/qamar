local types = _G["lexer"].types
for i, v in ipairs(types) do
	types[v] = i
end
return types
