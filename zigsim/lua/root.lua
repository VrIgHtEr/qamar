output('out', true)

Reset { 'rst', period = 100 }

Pullup { 'p', width = 2 }
TristateBuffer { 'tb', width = 2 }
wire 'p.q/tb.a'
wire 'rst.q/tb.en'
And 'a1'
wire 'tb.q/a1.a'

wire 'a1.q/out'
