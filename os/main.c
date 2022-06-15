#include <stdbool.h>
#include <stddef.h>
#include <stdint.h>

#define BSIZE 81

static volatile int8_t TEST[BSIZE];

static void printgrid(const int8_t *grid) {
  for (int8_t i = 0; i < BSIZE; ++i)
    TEST[i] = grid[i];
}

void *memcpy(void *dest, const void *src, size_t size) {
  uint8_t *pdest = (uint8_t *)dest;
  uint8_t *psrc = (uint8_t *)src;
  for (size_t loops = (size / sizeof(uint32_t)); loops;
       --loops, pdest += sizeof(uint32_t), psrc += sizeof(uint32_t))
    *((uint32_t *)pdest) = *((uint32_t *)psrc);
  for (size_t loops = (size % sizeof(uint32_t)); loops; --loops)
    *(pdest++) = *(psrc++);
  return dest;
}

static bool solve(int8_t *grid) {
  // create local copy of grid
  int8_t g[BSIZE];
  memcpy(g, grid, BSIZE);
  int8_t subindex;
  int8_t subcount;
  int8_t submarks[10];

  for (;;) {
    int8_t subs = 0;
    subindex = -1;
    subcount = 10;
    for (int8_t i = 0; i < BSIZE; ++i) {
      if (g[i])
        continue;
      int8_t row = i / 9;
      int8_t col = i % 9;
      int8_t mark[] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};

      int8_t rc = row * 9;
      int8_t cc = col;
      for (int8_t j = 0; j < 9; ++j, ++rc, cc += 9) {
        mark[g[rc]] = 0;
        mark[g[cc]] = 0;
      }

      int8_t c = (row / 3 * 3) * 9 + (col / 3 * 3);
      for (int8_t j = 0; j < 3; ++j, c += 6)
        for (int8_t k = 0; k < 3; ++k, ++c) {
          mark[g[c]] = 0;
        }

      int8_t count = 0;
      int8_t val;
      for (int8_t j = 1; j < 10; ++j)
        if (mark[j] != 0) {
          val = mark[j];
          ++count;
        }

      if (count == 0)
        return false;
      if (count == 1) {
        ++subs;
        g[i] = val;
      } else if (count < subcount) {
        subcount = count;
        subindex = i;
        memcpy(submarks, mark, sizeof(mark));
      }
    }
    if (subs == 0 || subindex < 0)
      break;
  }

  if (subindex < 0) {
    memcpy(grid, g, sizeof(g));
    return true;
  }

  for (int8_t i = 1; i <= 9; ++i) {
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
