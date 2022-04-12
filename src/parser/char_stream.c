#include "char_stream.h"
#include <lauxlib.h>
#include <lua.h>
#include <string.h>

const char *QAMAR_TYPE_CHAR_STREAM = "__QAMAR_CHAR_STREAM";

typedef struct {
  size_t skip_ws_ctr;
  size_t len;
  const char input[];
} char_stream_t;

static int get_len(lua_State *L) {
  size_t top = lua_gettop(L);
  if (top < 1)
    return 0;
  char_stream_t *cs = luaL_checkudata(L, -1, QAMAR_TYPE_CHAR_STREAM);
  if (cs == 0)
    return 0;
  lua_pushnumber(L, cs->len);
  return 1;
}

static int new_char_stream(lua_State *L) {
  if (!lua_isstring(L, 1))
    return 0;
  size_t len;
  const char *str = lua_tolstring(L, 1, &len);
  printf("char_stream.new was called: %s\n", str);
  printf("string length: %ld\n", len);
  printf("struct length: %ld\n", sizeof(char_stream_t));
  char_stream_t *char_stream = lua_newuserdata(L, sizeof(char_stream_t) + len);
  memcpy((void *)char_stream->input, str, len);
  char_stream->skip_ws_ctr = 0;
  char_stream->len = len;

  luaL_getmetatable(L, QAMAR_TYPE_CHAR_STREAM);
  lua_setmetatable(L, -2);
  return 1;
}

const luaL_Reg library[] = {{"len", get_len}, {"new", new_char_stream}, {0, 0}};

int qamar_char_stream_init(lua_State *L) {
  luaL_newmetatable(L, QAMAR_TYPE_CHAR_STREAM);
  luaL_register(L, "char_stream", library);
  lua_pop(L, 2);
  return 0;
}
