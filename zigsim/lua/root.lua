output('out', 0, true)

Xnor 'a1'
wire('a1.a', 'a1.b')
wire('a1.q', 'a1.a')

wire('a1.q', 'out')
