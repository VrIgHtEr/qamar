#include <stdio.h>
#include <stdlib.h>
#include <string.h>

typedef struct grid_t_ {
  unsigned int grid[81];
} grid_t;

typedef struct sub_t_ {
  int row;
  int col;
  int v[10];
} sub_t;

static volatile grid_t outgrid;

void print_grid(grid_t *grid) {
  for (int x = 0; x < 81; ++x)
    outgrid.grid[x] = grid->grid[x];
}

int solve_grid(grid_t *grid, int level) {
  grid_t g;       // local copy
  int i, j, k, m; // counters
  sub_t currentsub;
  int solved = 0;
  int unsolved = 0; // number of unsolved slots
  int lastpass = 0, subs = 0;

  // copy the passed grid to avoid propagating incorrect
  // solutions upwards
  memcpy(&g, grid, sizeof(grid_t));

  // make all simple substitutions
  for (;;) {
    subs = 0;
    unsolved = 0;

    // iterate over all rows
    for (i = 0; i < 9; i++) {
      // iterate over all columns
      for (j = 0; j < 9; j++) {
        int box, sol, solcount;
        int v[10] = {0, 1, 2, 3, 4, 5, 6, 7, 8, 9};

        // skip slots that already have an assigned value
        if (g.grid[9 * i + j] != 0) {
          continue;
        }

        // increment number of unsolved slots
        unsolved++;

        // eliminate all values occupied by other slots on this row
        for (k = 0; k < 9; k++) {
          v[g.grid[9 * i + k]] = 0;
        }

        // eliminate values occupied by other slots in the same column
        for (k = 0; k < 9; k++) {
          v[g.grid[9 * k + j]] = 0;
        }

        // finally, eliminate all slots occupied by values in the same 3x3 box
        box = 3 * (i / 3) + j / 3;
        for (k = 3 * (box / 3); k < 3 * (box / 3) + 3; k++) {
          for (m = 3 * (box % 3); m < 3 * (box % 3) + 3; m++) {
            v[g.grid[9 * k + m]] = 0;
          }
        }

        // count the number of possible values for this slot
        solcount = 0;
        sol = 0;
        for (k = 0; k < 10; k++) {
          if (v[k] != 0) {
            sol = v[k];
            solcount++;
          }
        }

        // if no possible values are found, there are no solutions
        if (solcount == 0) {
          return 0;
        }
        // if there is only one possible value, we substitute this value
        // into the grid
        else if (solcount == 1) {
          g.grid[i * 9 + j] = sol;
          subs++;
        }
        // otherwise just store a list of possible values until later
        // and try them until we find a solution.
        else {
          currentsub.row = i;
          currentsub.col = j;
          memcpy(&currentsub.v, v, sizeof(v));
        }
      }
    }

    // no possible substitutions remain, end loop
    if (subs == 0) {
      break;
    }
  }

  // permute solutions
  if (unsolved > 0) {
    for (i = 0; i < 10; i++) {
      if (currentsub.v[i] == 0) {
        continue;
      }

      g.grid[9 * currentsub.row + currentsub.col] = currentsub.v[i];
#ifdef DEBUG
      printf("%d: setting %d, %d to %d\n", level, currentsub.row,
             currentsub.col, currentsub.v[i]);
#endif
      if (solve_grid(&g, level + 1)) {
        solved = 1;
        break;
      }
    }
  } else {
    solved = 1;
  }

  if (!solved) {
    return 0;
  }

  // copy the final solution upwards the stack
  memcpy(grid, &g, sizeof(grid_t));

  return 1;
}

void main(void) {
  grid_t grid

      = {{0, 1, 3, 5, 0, 0, 4, 2, 0, 0, 8, 7, 0, 0, 4, 0, 0, 0, 0, 0, 4,
          0, 7, 9, 6, 0, 3, 0, 6, 2, 0, 4, 0, 5, 0, 8, 0, 0, 0, 0, 5, 0,
          1, 0, 2, 0, 3, 8, 0, 9, 1, 0, 0, 0, 0, 0, 0, 9, 0, 0, 8, 0, 0,
          7, 0, 0, 8, 1, 5, 0, 0, 9, 8, 9, 1, 0, 0, 7, 2, 5, 0}};
  print_grid(&grid);

  if (solve_grid(&grid, 0)) {
    print_grid(&grid);
  }
  asm("UNIMP\n");
}
