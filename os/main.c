#include <stdbool.h>
#include <stdint.h>

struct xorshift32_state {
  uint32_t a;
};

/* The state word must be initialized to non-zero */
uint32_t xorshift32(struct xorshift32_state *state) {
  /* Algorithm "xor" from p. 4 of Marsaglia, "Xorshift RNGs" */
  uint32_t x = state->a;
  x ^= x << 13;
  x ^= x >> 17;
  x ^= x << 5;
  return state->a = x;
}

int main() {
  struct xorshift32_state s = {1};
  static volatile uint32_t i = 0;
  while (true) {
    i += xorshift32(&s);
  }
  __builtin_unreachable(); // tell the compiler to make sure side effects are
}
