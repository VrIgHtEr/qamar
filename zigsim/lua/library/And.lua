input('a', 1)
output 'q'

Nand 'x'
wire 'a/x.a'

Nand 'y'
wire 'x.q/y.a[0]'
wire 'x.q/y.a[1]'

wire 'y.q/q'
