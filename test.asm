addi x1,x0, 9
addi x2,x0, 42

mul:
xor x3, x3, x3
add x4, x2, x0
xor x5, x5, x5
mul_loop:
beq x4, x0, mul_end
andi x6,x4,1
beq x6, x0, mul_continue
sll x6, x1, x5
add x3, x3, x6
mul_continue:
srli x4, x4, 1
addi x5, x5, 1
beq x0,x0,mul_loop
mul_end:
xor x5,x5,x5
xor x6,x6,x6

xor x1, x1, x1
addi x2, x0, 1
addi x4, x0, 24

loop:
add x3, x1, x2
add x1, x2, x0
add x2, x3, x0
andi x2, x2, 255
sll x2, x2, x4
sra x2, x2, x4

add x3, x2, x1
add x1, x2, x0
add x2, x3, x0
andi x2, x2, 255
slli x2, x2, 24
srai x2, x2, 24

beq s0, s0, loop
