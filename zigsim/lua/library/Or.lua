input('a', 1)
output 'q'

Not 'x'
wire 'a[0]/x.a'

Not 'y'
wire 'a[1]/y.a'

Nand 'z'
wire 'x.q/z.a[0]'
wire 'y.q/z.a[1]'

wire 'z.q/q'
