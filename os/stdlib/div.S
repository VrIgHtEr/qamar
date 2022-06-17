#define FUNC_TYPE(X)	.type X,@function
#define FUNC_SIZE(X)	.size X,.-X

#define FUNC_BEGIN(X)		\
	.globl X;		\
	FUNC_TYPE (X);		\
X:

#define FUNC_END(X)		\
	FUNC_SIZE(X)

#define FUNC_ALIAS(X,Y)		\
	.globl X;		\
	X = Y

#define CONCAT1(a, b)		CONCAT2(a, b)
#define CONCAT2(a, b)		a ## b
#define HIDDEN_JUMPTARGET(X)	CONCAT1(__hidden_, X)
#define HIDDEN_DEF(X)		FUNC_ALIAS(HIDDEN_JUMPTARGET(X), X);     \
				.hidden HIDDEN_JUMPTARGET(X)

  .text
  .align 2

/* Our RV64 64-bit routines are equivalent to our RV32 32-bit routines.  */
# define __udivdi3 __udivsi3
# define __umoddi3 __umodsi3
# define __divdi3 __divsi3
# define __moddi3 __modsi3

FUNC_BEGIN (__divdi3)
  bltz  a0, .L10
  bltz  a1, .L11
  /* Since the quotient is positive, fall into __udivdi3.  */

FUNC_BEGIN (__udivdi3)
  mv    a2, a1
  mv    a1, a0
  li    a0, -1
  beqz  a2, .L5
  li    a3, 1
  bgeu  a2, a1, .L2
.L1:
  blez  a2, .L2
  slli  a2, a2, 1
  slli  a3, a3, 1
  bgtu  a1, a2, .L1
.L2:
  li    a0, 0
.L3:
  bltu  a1, a2, .L4
  sub   a1, a1, a2
  or    a0, a0, a3
.L4:
  srli  a3, a3, 1
  srli  a2, a2, 1
  bnez  a3, .L3
.L5:
  ret
FUNC_END (__udivdi3)
HIDDEN_DEF (__udivdi3)

FUNC_BEGIN (__umoddi3)
  /* Call __udivdi3(a0, a1), then return the remainder, which is in a1.  */
  move  t0, ra
  jal   HIDDEN_JUMPTARGET(__udivdi3)
  move  a0, a1
  jr    t0
FUNC_END (__umoddi3)

  /* Handle negative arguments to __divdi3.  */
.L10:
  neg   a0, a0
  /* Zero is handled as a negative so that the result will not be inverted.  */
  bgtz  a1, .L12     /* Compute __udivdi3(-a0, a1), then negate the result.  */

  neg   a1, a1
  j     HIDDEN_JUMPTARGET(__udivdi3)     /* Compute __udivdi3(-a0, -a1).  */
.L11:                /* Compute __udivdi3(a0, -a1), then negate the result.  */
  neg   a1, a1
.L12:
  move  t0, ra
  jal   HIDDEN_JUMPTARGET(__udivdi3)
  neg   a0, a0
  jr    t0
FUNC_END (__divdi3)

FUNC_BEGIN (__moddi3)
  move   t0, ra
  bltz   a1, .L31
  bltz   a0, .L32
.L30:
  jal    HIDDEN_JUMPTARGET(__udivdi3)    /* The dividend is not negative.  */
  move   a0, a1
  jr     t0
.L31:
  neg    a1, a1
  bgez   a0, .L30
.L32:
  neg    a0, a0
  jal    HIDDEN_JUMPTARGET(__udivdi3)    /* The dividend is hella negative.  */
  neg    a0, a1
  jr     t0
FUNC_END (__moddi3)
