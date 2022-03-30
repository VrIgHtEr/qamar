#ifndef NULL
#define NULL ((void *)0)
#endif

#include "qamar_config.h"
#include <lauxlib.h>
#include <luajit.h>
#include <lualib.h>
#include <stdio.h>
#include <string.h>

int main(void) {
  printf("VERSION: %d.%d\n", qamar_VERSION_MAJOR, qamar_VERSION_MINOR);
  lua_State *L = lua_open();
  luaopen_base(L);
  luaopen_table(L);
  luaopen_io(L);
  luaopen_string(L);
  luaopen_math(L);

  char buff[4096];
  int error;
  while (fgets(buff, sizeof(buff), stdin) != 0) {
    error =
        luaL_loadbuffer(L, buff, strlen(buff), "line") || lua_pcall(L, 0, 0, 0);
    if (error) {
      fprintf(stderr, "%s", lua_tostring(L, -1));
      lua_pop(L, 1);
    }
  }

  lua_close(L);
  return 0;
}
