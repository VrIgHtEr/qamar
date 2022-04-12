#include "char_stream.h"
#include "../util/queue_ts.h"
#include <lauxlib.h>
#include <lua.h>
#include <stdio.h>
#include <string.h>

const char *QAMAR_TYPE_CHAR_STREAM = "__QAMAR_CHAR_STREAM";

typedef struct {
  size_t index;
} transaction;

typedef struct {
  size_t skip_ws_ctr;
  size_t index;
  size_t len;
  queue_ts t;
  const char input[];
} char_stream_t;

static int char_stream_new(lua_State *L) {
  if (!lua_isstring(L, 1))
    return 0;
  size_t len;
  const char *str = lua_tolstring(L, 1, &len);
  char_stream_t *char_stream = lua_newuserdata(L, sizeof(char_stream_t) + len);
  if (char_stream == NULL)
    return 0;
  memcpy((void *)char_stream->input, str, len);
  char_stream->skip_ws_ctr = 0;
  char_stream->len = len;
  char_stream->index = 0;
  if (queue_ts_new(sizeof(transaction), &char_stream->t))
    return 0;
  luaL_getmetatable(L, QAMAR_TYPE_CHAR_STREAM);
  lua_setmetatable(L, -2);
  return 1;
}

static int char_stream_destroy(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, -1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
  queue_ts_destroy(s->t);
  return 0;
}

static int char_stream_len(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, -1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
  lua_pushnumber(L, s->len);
  return 1;
}

static int char_stream_tostring(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, -1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
  int amt = snprintf(0, 0, "<char_stream>:%ld:%ld", s->len, s->index);
  if (amt < 0)
    return 0;
  char t[amt + 1];
  snprintf(t, amt + 1, "<char_stream>:%ld:%ld", s->len, s->index);
  lua_pushlstring(L, t, amt);
  return 1;
}

static int char_stream_peek(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, -1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
  if (s->index >= s->len)
    return 0;
  lua_pushlstring(L, &s->input[s->index], 1);
  return 1;
}

static int char_stream_take(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, -1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
  if (s->index >= s->len)
    return 0;
  lua_pushlstring(L, &s->input[s->index], 1);
  ++s->index;
  return 1;
}

const luaL_Reg library[] = {{"new", char_stream_new},
                            {"len", char_stream_len},
                            {"peek", char_stream_peek},
                            {"take", char_stream_take},
                            {NULL, NULL}};

int qamar_char_stream_init(lua_State *L) {
  luaL_newmetatable(L, QAMAR_TYPE_CHAR_STREAM);

  lua_pushstring(L, "__index");
  lua_newtable(L);

  for (const luaL_Reg *ptr = &library[1];; ++ptr)
    if (ptr->name != 0) {
      lua_pushstring(L, ptr->name);
      lua_pushcfunction(L, ptr->func);
      lua_rawset(L, -3);
    } else
      break;

  lua_rawset(L, -3);

  lua_pushstring(L, "__tostring");
  lua_pushcfunction(L, char_stream_tostring);
  lua_rawset(L, -3);
  lua_pushstring(L, "__gc");
  lua_pushcfunction(L, char_stream_destroy);
  lua_rawset(L, -3);
  lua_pop(L, 1);

  luaL_register(L, "char_stream", library);
  lua_pop(L, 1);
  return 0;
}
