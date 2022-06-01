li x1, 1000000000
addi a0,zero, 9
addi a1,zero, 42
mul:
add t0, a0, zero
xor a0, a0, a0
xor t1, t1, t1
mul_loop:
beq a1, zero, mul_end
andi t2, a1, 1
beq t2, zero, mul_continue
sll t2, t0, t1
add a0, a0, t2
mul_continue:
srli a1, a1, 1
addi t1, t1, 1
beq zero, zero, mul_loop
mul_end:

