.global  _start
.section .text.prologue
_start:
li sp, 0xFFFFF
mv fp, sp
la gp, __data_start
jal main
1:
    j 1b
