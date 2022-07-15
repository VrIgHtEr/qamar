.global  _start
.section .text.prologue
_start:
la sp, __stack_base
mv fp, sp
la gp, __bss_start
jal _start
.word 0
1:
    j 1b
