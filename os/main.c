#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>
#include <string.h>

#define SWIDTH 3
#define BWIDTH ((SWIDTH) * (SWIDTH))
#define BSIZE ((BWIDTH) * (BWIDTH))

static volatile int8_t TEST[BSIZE];

static void printgrid(const int8_t *grid) {
  for (int8_t i = 0; i < BSIZE; ++i)
    TEST[i] = grid[i];
}

static bool solve(int8_t *grid) {
  int8_t g[BSIZE], submarks[BWIDTH + 1];
  memcpy(g, grid, sizeof(g));
  int8_t subindex, subcount;
  for (;;) {
    int8_t subs = 0;
    subindex = -1;
    subcount = BWIDTH + 1;
    for (int8_t row = 0, i = 0, src = 0; row < BWIDTH; ++row, src += BWIDTH) {
      int8_t topleft = row / SWIDTH * SWIDTH * BWIDTH;
      int8_t rowmark[BWIDTH + 1], mark[BWIDTH + 1];
      rowmark[0] = 0;
      memset(rowmark + 1, 1, BWIDTH);
      for (int8_t j = 0, rc = src; j < BWIDTH; ++j, ++rc)
        rowmark[g[rc]] = 0;
      for (int8_t col = 0; col < BWIDTH; ++col, ++i) {
        if (g[i])
          continue;
        memcpy(mark, rowmark, sizeof(rowmark));
        int8_t cc = col, c = topleft + (col / SWIDTH * SWIDTH), count = 0, val;
        for (int8_t j = 0; j < BWIDTH; ++j, cc += BWIDTH)
          mark[g[cc]] = 0;
        for (int8_t j = 0; j < SWIDTH; ++j, c += (BWIDTH - SWIDTH))
          for (int8_t k = 0; k < SWIDTH; ++k, ++c)
            mark[g[c]] = 0;
        for (int8_t j = 1; j <= BWIDTH; ++j)
          if (mark[j] != 0) {
            val = j;
            ++count;
          }
        if (count == 0)
          return false;
        if (count == 1) {
          ++subs;
          g[i] = val;
          rowmark[val] = 0;
        } else if (count < subcount) {
          subcount = count;
          subindex = i;
          memcpy(submarks, mark, sizeof(mark));
        }
      }
      if (subs == 0 || subindex < 0)
        break;
    }
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

  asm("UNIMP\n");
  return 0;
}
