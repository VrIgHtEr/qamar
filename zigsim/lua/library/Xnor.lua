input('a', 1)
output 'q'

Or 'x'
wire 'a/x.a'

Nand 'y'
wire 'a/y.a'

Nand 'z'
wire 'x.q/z.a[0]'
wire 'y.q/z.a[1]'

wire 'z.q/q'
