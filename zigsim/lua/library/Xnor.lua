input 'a'
input 'b'
output 'q'

Or 'x'
wire('a', 'x.a')
wire('b', 'x.b')

Nand 'y'
wire('a', 'y.a')
wire('b', 'y.b')

Nand 'z'
wire('x.q', 'z.a')
wire('y.q', 'z.b')

wire('z.q', 'q')
