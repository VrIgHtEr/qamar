.global  _start
.section .text.prologue
_start:
la sp, __stack_base
mv fp, sp
la gp, __data_start
jal main
.word 0
1:
    j 1b
