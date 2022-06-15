.global  _start
.section .text.prologue
_start:
li sp, 0x800000
jal main
1:
    j 1b
.text
.global memset
memset:
    mv t0, a0
1:
    beqz a2, 2f
    sb a1, 0(t0)
    addi t0, t0, 1
    addi a2, a2, -1
    j 1b
2:
    ret

.global memcpy
memcpy:
    mv t0, a0
1:
    beqz a2, 2f
    lbu t1, 0(a1)
    sb t1, 0(t0)
    addi t0, t0, 1
    addi a1, a1, 1
    addi a2, a2, -1
2:
    ret

.global memcmp 
memcmp:
    mv t0, a0
1:
    beqz a2, 1f
    lbu t1, 0(t0)
    lbu t2, 0(a1)
    beq t1, t2, 2f
    blt t1, t2, 3f
    li a0, 1
    ret
3:
    li a0, -1
    ret
2:
    addi t0, t0, 1
    addi a1, a1, 1
    j 1b
1:
    li a0, 0
    ret

