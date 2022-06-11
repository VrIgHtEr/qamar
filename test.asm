.section .text
.global _start
_start:

.equ SIZE, 16
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

li a0, ADDR
mv a1, s0
li a2, SIZE
jal binsearch

fence.i
fence.i
fence.i
fence.i
fence.i

addi s0, s0, -1
bge s0, zero, search_loop
li s0, SIZE-1
j search_loop

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
    lbu      t3, 0(t3)   # Dereference arr[mid]

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
