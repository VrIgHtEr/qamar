input 'a'
input 'b'
output 'q'

Nand 'x'
wire('a', 'x.a')
wire('b', 'x.b')

Nand 'y'
wire('x.q', 'y.a')
wire('x.q', 'y.b')

wire('y.q', 'q')
