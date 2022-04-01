#ifndef NULL
#define NULL ((void *)0)
#endif

#include "qamar_config.h"
#include "util/queue_ts.h"

#include <lauxlib.h>
#include <luajit.h>
#include <lualib.h>

#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void prepend_lua_path(lua_State *L, const char *prefix) {
  lua_getglobal(L, "package");
  lua_pushstring(L, "path");
  lua_gettable(L, -2);
  if (lua_isstring(L, -1)) {
    size_t len;
    const char *path = lua_tolstring(L, -1, &len);
    size_t len2 = strlen(prefix);
    size_t len3 = len + len2 + 1;
    char buf[len3];
    buf[len3 - 1] = 0;
    memcpy(buf, prefix, len2 + 1);
    strcat(buf, path);
    lua_pop(L, 1);
    lua_pushstring(L, "path");
    lua_pushstring(L, buf);
    lua_rawset(L, -3);
    lua_pop(L, 1);
  } else
    lua_pop(L, 2);
}

void initialize_environment(lua_State *L) {
  prepend_lua_path(L, "./lua/?.lua;./lua/?/init.lua;");
  lua_pushnil(L);
  lua_setglobal(L, "package");
}

int main(void) {
  queue_ts q = queue_ts_new();
  queue_ts_destroy(q);

  lua_State *L = luaL_newstate();
  luaL_openlibs(L);

  int status = luaL_loadfile(L, "lua/main.lua");
  if (status) {
    fprintf(stderr, "Couldn't load file: %s\n", lua_tostring(L, -1));
    lua_pop(L, -1);
    exit(1);
  }

  initialize_environment(L);

  int result = lua_pcall(L, 0, LUA_MULTRET, 0);
  if (result) {
    fprintf(stderr, "Failed to run script: %s\n", lua_tostring(L, -1));
    exit(1);
  }

  if (lua_istable(L, -1)) {
    lua_pushstring(L, "main");
    lua_gettable(L, -2);
    if (lua_isfunction(L, -1)) {
      if (lua_pcall(L, 0, 0, 0)) {
        fprintf(stderr, "Failed to execute main function: %s\n",
                lua_tostring(L, -1));
        lua_pop(L, -1);
      }
    }
    lua_pop(L, -1);
  }
  lua_pop(L, -1);

  lua_close(L);
  return 0;
}
