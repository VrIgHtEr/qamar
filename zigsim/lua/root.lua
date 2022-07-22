output('out', true)
output('edge', true)

Reset { 'rst', period = 100 }
Clock { 'clk', period = 1000 }

DLatch 'latch'
wire 'clk.q/latch.d'
wire 'latch.q/out'

EdgeDetector { 'e', len = 3 }
wire 'clk.q/e.a'
wire 'e.q/edge'
