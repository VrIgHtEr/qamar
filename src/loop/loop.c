#include "loop.h"
#include "lauxlib.h"
#include <lua.h>
#include <stdio.h>

void qamar_loop(uv_idle_t *idler) {
  uv_idle_stop(idler);
  return;
  lua_State *L = idler->data;
  if (luaL_loadstring(L, "return function() io.write 'hello world\\n' end")) {
    fprintf(stdout, "could not load idle script/n");
    lua_pop(L, 1);
    uv_idle_stop(idler);
    return;
  }
  if (lua_isfunction(L, -1)) {
    if (lua_pcall(L, 0, 0, 0)) {
      fprintf(stdout, "idle script threw an error\n");
      lua_pop(L, 1);
      uv_idle_stop(idler);
      return;
    }
    lua_pop(L, 1);
  } else {
    fprintf(stdout, "idle script did not return a function/n");
    lua_pop(L, 1);
    uv_idle_stop(idler);
  }
}
