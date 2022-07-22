input 's'
input 'r'
output 'q'
output '!q'

Nand 'a'
Nand 'b'

wire 's/a.a[0]'
wire 'r/b.a[0]'
wire 'a.q/b.a[1]'
wire 'b.q/a.a[1]'

wire 'a.q/q'
wire 'b.q/!q'
