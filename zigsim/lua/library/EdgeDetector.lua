input 'a'
output 'q'

local width = opts.len == nil and 1 or opts.len
if type(width) ~= 'number' or width < 1 then
    error 'invalid width'
end

Not 'not'
wire 'a/not.a'

And 'and'
wire 'a/and.a[0]'
wire 'and.q/q'

local prev = 'not'
for i = 1, width - 1 do
    local n = 'buf' .. i
    Buffer(n)
    wire(prev .. '.q/' .. n .. '.a')
    prev = n
end
wire(prev .. '.q/and.a[1]')
