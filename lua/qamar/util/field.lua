local M = {}

local primitive = 0x1d
local size = 256
local expTable = {}
local logTable = {}

local tmp = 1
for i = 0, size - 1 do
    expTable[i] = tmp
    tmp = tmp * 2
    if tmp >= size then
        tmp = bit.band(size - 1, bit.bxor(tmp, primitive))
    end
end
for i = 0, size - 1 do
    logTable[expTable[i]] = i
end

for _, x in ipairs(logTable) do
    print(x)
end
io.write '\n'
for _, x in ipairs(expTable) do
    print(x)
end

return M
