li x1, 1000000000
addi a0,zero, 9
addi a1,zero, 42
mul:
mv t0, a0
xor a0, a0, a0
xor t1, t1, t1
mul_loop:
beqz a1, mul_end
andi t2, a1, 1
beqz t2, mul_continue
sll t2, t0, t1
add a0, a0, t2
mul_continue:
srli a1, a1, 1
addi t1, t1, 1
beqz zero, mul_loop
mul_end:

