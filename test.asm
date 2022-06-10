.equ val, 10
ecall
ebreak
fence.i

sb zero, 0(t0)
sh zero, 0(t0)
sw zero, 0(t0)

start:
li x1, val

li x2, val - 1
slt x3, x1, x2
sltu x3, x1, x2
slti x3, x1, val-1
sltiu x3, x1, val-1

li x2, val
slt x3, x1, x2
sltu x3, x1, x2
slti x3, x1, val
sltiu x3, x1, val

li x2, val + 1
slt x3, x1, x2
sltu x3, x1, x2
slti x3, x1, val + 1
sltiu x3, x1, val + 1

slt x3, x1, zero
sltu x3, x1, zero
slti x3, x1, 0
sltiu x3, x1, 0

li x2, -val
slt x3, x1, x2
sltu x3, x1, x2
slti x3, x1, -val
sltiu x3, x1, -val

li x1, 1000000000
addi a0,zero, 9
addi a1,zero, 42
jal ra, mul


lb x1, 0(x0)
lbu x1, 0(x0)
lh x1, 0(x0)
lhu x1, 0(x0)
lw x1, 0(x0)

sb x1, 0(x0)
sh x1, 0(x0)
sw x1, 0(x0)

j start

mul:
mv t0, a0
li a0,0
li t1,0
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
jalr x0, 0(ra)

