output('out', true)

Pulldown('P', { width = 2 })
Xnor 'a1'
wire 'P.q/a1.a'

wire 'a1.q/out'
