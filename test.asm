.section .text
.global _start
_start:

jal initialize

.global IdleLoop

li s0, 1
li s1, -267
IdleLoop:

mv a0, s1
mv a1, s0
jal mul3264

#mv s1, s0
mv s0, a0

sw a0, 1024(zero)
sw a1, 1028(zero)
lw a0, 1024(zero)

fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i


J IdleLoop

.equ SIZE, 32
.equ ADDR, 1000000

li t0, SIZE
li t1, 0
li t2, ADDR
init_loop:
slli t3, t1, 2
add t3, t3, t2
sw t1, 0(t3)
addi t1, t1, 1
addi t0, t0, -1
bnez t0, init_loop

li s0, SIZE-1
search_loop:

fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i

li a0, ADDR
mv a1, s0
li a2, SIZE
jal binsearch

fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i
fence.i

addi s0, s0, -1
bge s0, zero, search_loop
li s0, SIZE-1
j search_loop

#------------------------------------------------------------------------------------
.global binsearch
binsearch:
    # a0 = int arr[]
    # a1 = int needle
    # a2 = int size
    # t0 = mid
    # t1 = left
    # t2 = right

    addi    t1, zero, 0  # left = 0
    addi    t2, a2, -1   # right = size - 1
1: # while loop
    bgt     t1, t2, 1f   # left > right, break
    add     t0, t1, t2   # mid = left + right
    srai    t0, t0, 1    # mid = (left + right) / 2

    # Get the element at the midpoint
    slli    t3, t0, 2    # Scale the midpoint by 4
    add     t3, a0, t3   # Get the memory address of arr[mid]
    lw      t3, 0(t3)    # Dereference arr[mid]

    # See if the needle (a1) > arr[mid] (t3)
    ble     a1, t3, 2f   # if needle <= t3, we need to check the next condition
    # If we get here, then the needle is > arr[mid]
    addi    t1, t0, 1    # left = mid + 1
    j 1b
2:
    bge     a1, t3, 2f   # skip if needle >= arr[mid]
    # If we get here, then needle < arr[mid]
    addi    t2, t0, -1   # right = mid - 1
    j 1b
2:
    # If we get here, then needle == arr[mid]
    addi    a0, t0, 0
1:
    ret
#-------------------------------------------------------------------------------------

.global mul
mul:
    #a0 = a
    #a1 = b
    bleu a1, a0, mul_start
    xor a0, a0, a1
    xor a1, a0, a1
    xor a0, a0, a1
mul_start:
    mv t0, a0 #t0 = a0
    li a0, 0  #a0 = retval = 0
mul_loop:
    beqz a1, mul_finish
    andi t1, a1, 1
    beqz t1, mul_continue
    add a0, a0, t0
mul_continue:
    slli t0, t0, 1
    srli a1, a1, 1
    j mul_loop
mul_finish:
    ret
#-------------------------------------------------------------------------------------

.global mul3264
mul3264:
    bleu a1, a0, 1f
    xor a0, a0, a1
    xor a1, a1, a0
    xor a0, a0, a1
1:
    mv t0, a0
    li t1, 0
    mv t2, a1
    li a0, 0
    li a1, 0
1:
    bnez t2, 2f
    ret
2:
    andi t3, t2, 1
    beqz t3, 2f

    add a0, a0, t0
    add a1, a1, t1
    bgeu a0, t0, 2f
    addi a1, a1, 1
2:
    srli t2, t2, 1
    srli t3, t0, 31
    slli t1, t1, 1
    or t1, t1, t3
    slli t0, t0, 1
    j 1b

#-------------------------------------------------------------------------------------
initialize:
li sp, 0x800000
ret

