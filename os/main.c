#include "string.h"
#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define SWIDTH 3
#define BWIDTH ((SWIDTH) * (SWIDTH))
#define BSIZE ((BWIDTH) * (BWIDTH))

static volatile int8_t TEST[BSIZE];

#ifdef printresult
#include <stdio.h>
#endif
static void printgrid(const int8_t *grid) {
  for (int8_t i = 0; i < BSIZE; ++i) {
#ifdef printresult
    printf("%d", grid[i]);
#endif
    TEST[i] = grid[i];
  }
#ifdef printresult
  printf("\n");
#endif
}

static bool solve(int8_t *grid) {
  int8_t g[BSIZE], submarks[BWIDTH + 1], mark[BWIDTH + 1];
  memcpy(g, grid, sizeof(g));
  mark[0] = 0;
  int8_t subindex, subcount;
  for (;;) {
    int8_t subs = 0;
    subindex = -1;
    subcount = BWIDTH + 1;

    for (int8_t cell = 0; cell < BSIZE; ++cell) {
      if (!g[cell]) {
        int8_t r = cell / BWIDTH;
        int8_t c = cell % BWIDTH;
        int8_t s = (r / SWIDTH * (SWIDTH * BWIDTH)) + c / SWIDTH * SWIDTH;
        r *= BWIDTH;
        memset(mark + 1, 1, BWIDTH);
        for (int i = 0; i < SWIDTH; ++i, s += BWIDTH - SWIDTH)
          for (int j = 0; j < SWIDTH; ++j, ++r, c += BWIDTH, ++s) {
            mark[g[r]] = 0;
            mark[g[c]] = 0;
            mark[g[s]] = 0;
#ifdef printresult
            if (i | j)
              printf("     %d,      %d,      %d\n", (int32_t)r, (int32_t)c,
                     (int32_t)s);
            else
              printf("row: %d, col: %d, sqr: %d\n", (int32_t)r, (int32_t)c,
                     (int32_t)s);
#endif
          }
        int8_t count = 0;
        int8_t val = 0;
        for (int8_t i = 1; i <= BWIDTH; ++i)
          if (mark[i]) {
            ++count;
            val = i;
          }
        if (count == 0)
          return false;
        if (count == 1) {
          ++subs;
          g[cell] = val;
        } else {
          subindex = cell;
          subcount = count;
          memcpy(submarks + 1, mark + 1, BWIDTH);
        }
      }
    }
    if (subs == 0 || subindex < 0)
      break;
  }
  if (subindex < 0) {
    memcpy(grid, g, sizeof(g));
    return true;
  }
  for (int8_t i = 1; i <= BWIDTH; ++i) {
    if (submarks[i] != 0) {
      g[subindex] = i;
      if (solve(g)) {
        memcpy(grid, g, sizeof(g));
        return true;
      }
    }
  }
  return false;
}

int main(void) {
  int8_t grid[] = {0, 1, 3, 5, 0, 0, 4, 2, 0, 0, 8, 7, 0, 0, 4, 0, 0,
                   0, 0, 0, 4, 0, 7, 9, 6, 0, 3, 0, 6, 2, 0, 4, 0, 5,
                   0, 8, 0, 0, 0, 0, 5, 0, 1, 0, 2, 0, 3, 8, 0, 9, 1,
                   0, 0, 0, 0, 0, 0, 9, 0, 0, 8, 0, 0, 7, 0, 0, 8, 1,
                   5, 0, 0, 9, 8, 9, 1, 0, 0, 7, 2, 5, 0};

  if (solve(grid))
    printgrid(grid);

  asm(".word 0\n");
  return 0;
}
