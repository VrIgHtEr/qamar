output('out', true)

Reset { 'rst', period = 100 }
Clock { 'clk', period = 1000 }

Pullup 'p'
TristateBuffer { 'tb', width = 2 }
wire 'p.q/tb.a[0]'
wire 'clk.q/tb.a[1]'
wire 'rst.q/tb.en'
And 'a1'
wire 'tb.q/a1.a'

wire 'a1.q/out'
