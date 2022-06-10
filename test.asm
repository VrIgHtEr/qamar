.equ LED, 32768
.equ DELAY_COUNT, 10
.equ LED_STATE_INITIAL, 0b00
.equ LED_STATE_TOGGLE_MASK, 0b01

.section .text
.global _start
_start:
        li x1, LED
        li x2, LED_STATE_TOGGLE_MASK
        li x3, LED_STATE_INITIAL
        j begin_loop
loop:
        li x4, DELAY_COUNT      # reset counter
delay_loop:
        addi x4, x4, -1         # count down
        bnez x4, delay_loop
toggle_led:
        lw x3, 0x0(x1)          # read in old led state
        xor x3, x3, x2          # toggle led state word
begin_loop:
        sw x3, 0x0(x1)          # write new state
        j loop
