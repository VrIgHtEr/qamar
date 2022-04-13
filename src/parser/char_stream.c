#include "char_stream.h"
#include "../util/queue_ts.h"
#include <lauxlib.h>
#include <lua.h>
#include <stdio.h>
#include <string.h>

const char *QAMAR_TYPE_CHAR_STREAM = "__QAMAR_CHAR_STREAM";

typedef struct {
  size_t index;
  size_t file_char;
  size_t row;
  size_t col;
  size_t byte;
  size_t file_byte;
} transaction;

typedef struct {
  size_t skip_ws_ctr;
  size_t len;
  queue_ts ts;
  size_t tc;
  transaction t;
  const char data[];
} char_stream_t;

static int char_stream_new(lua_State *L) {
  if (!lua_isstring(L, 1))
    return 0;
  size_t len;
  const char *str = lua_tolstring(L, 1, &len);
  char_stream_t *char_stream = lua_newuserdata(L, sizeof(char_stream_t) + len);
  if (char_stream == NULL)
    return 0;
  memcpy((void *)char_stream->data, str, len);
  char_stream->skip_ws_ctr = 0;
  char_stream->len = len;
  char_stream->tc = 0;
  char_stream->t.file_byte = 0;
  char_stream->t.byte = 0;
  char_stream->t.file_char = 0;
  char_stream->t.col = 1;
  char_stream->t.index = 0;
  char_stream->t.row = 1;
  if (queue_ts_new(sizeof(transaction), &char_stream->ts))
    return 0;
  luaL_getmetatable(L, QAMAR_TYPE_CHAR_STREAM);
  lua_setmetatable(L, -2);
  return 1;
}

static int char_stream_destroy(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
  // queue_ts_destroy(s->ts);
  s->ts = 0;
  return 0;
}

static int char_stream_tostring(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
  int amt = snprintf(0, 0, "<char_stream>:%ld:%ld", s->len, s->t.index);
  if (amt < 0)
    return 0;
  char t[amt + 1];
  snprintf(t, amt + 1, "<char_stream>:%ld:%ld", s->len, s->t.index);
  lua_pushlstring(L, t, amt);
  return 1;
}

static int char_stream_peek(lua_State *L) {
  char_stream_t *s;
  int top = lua_gettop(L);
  if (top < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0 ||
      s->t.index >= s->len)
    return 0;
  size_t skip = 0;
  if (top >= 2) {
    if (lua_isnumber(L, 2)) {
      int val = (int)lua_tonumber(L, 2);
      if (val >= 0) {
        if (s->t.index + val >= s->len)
          return 0;
        skip = val;
      } else
        return 0;
    } else
      return 0;
  }
  lua_pushlstring(L, &s->data[s->t.index + skip], 1);
  return 1;
}

static int char_stream_take(lua_State *L) {
  char_stream_t *s;
  int top = lua_gettop(L);
  if (top < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0 ||
      s->t.index >= s->len)
    return 0;
  size_t amt = 1;
  if (top >= 2) {
    if (lua_isnumber(L, 2)) {
      int val = (int)lua_tonumber(L, 2);
      if (val > 0) {
        if (s->t.index + val > s->len)
          amt = s->len - s->t.index;
        else
          amt = val;
      } else
        return 0;
    } else
      return 0;
  }
  const char *const max = &s->data[s->len];
  for (const char *c = &s->data[s->t.index]; c < max; ++c) {
    ++s->t.file_char;
    ++s->t.file_byte;
    if (*c == '\n') {
      s->t.byte = 0;
      ++s->t.row;
      s->t.col = 1;
    } else {
      ++s->t.byte;
      ++s->t.col;
    }
  }
  lua_pushlstring(L, &s->data[s->t.index], amt);
  s->t.index += amt;
  return 1;
}
static int char_stream_begin(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
  ++s->tc;
  queue_ts_push_back(s->ts, &s->t);
  return 0;
}

static int char_stream_undo(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
  if (s->tc == 0)
    return 0;
  --s->tc;
  queue_ts_pop_back(s->ts, &s->t);
  return 0;
}

static int char_stream_commit(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
  if (s->tc == 0)
    return 0;
  --s->tc;
  transaction _;
  queue_ts_pop_back(s->ts, &_);
  return 0;
}

static int char_stream_pos(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
  lua_newtable(L);

  lua_pushstring(L, "col");
  lua_pushnumber(L, s->t.col);
  lua_rawset(L, -3);

  lua_pushstring(L, "row");
  lua_pushnumber(L, s->t.row);
  lua_rawset(L, -3);

  lua_pushstring(L, "byte");
  lua_pushnumber(L, s->t.byte);
  lua_rawset(L, -3);

  lua_pushstring(L, "file_char");
  lua_pushnumber(L, s->t.file_char);
  lua_rawset(L, -3);

  lua_pushstring(L, "file_byte");
  lua_pushnumber(L, s->t.file_byte);
  lua_rawset(L, -3);

  return 1;
}

static int char_stream_try_consume_string(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 2 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0 ||
      !lua_isstring(L, 2))
    return 0;
  size_t len;
  const char *str = lua_tolstring(L, 2, &len);
  if (s->t.index + len > s->len)
    return 0;
  for (size_t i = 0; i < len; ++i)
    if (s->data[s->t.index + i] != str[i])
      return 0;
  lua_pushlstring(L, &s->data[s->t.index], len);
  s->t.index += len;
  return 1;
}

static int char_stream_skipws(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
  if (s->skip_ws_ctr == 0) {
    for (; s->t.index < s->len; ++s->t.index) {
      char x = s->data[s->t.index];
      if (x != ' ' && x != '\f' && x != '\n' && x != '\r' && x != '\t' &&
          x != '\v')
        break;
    }
  }
  return 0;
}

static int char_stream_suspend_skip_ws(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
  ++s->skip_ws_ctr;
  return 0;
}

static int char_stream_resume_skip_ws(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0 ||
      s->skip_ws_ctr == 0)
    return 0;
  --s->skip_ws_ctr;
  return 0;
}

static int char_stream_alpha(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0 ||
      s->t.index >= s->len)
    return 0;
  char x = s->data[s->t.index];
  if ((x >= 97 && x <= 122) || (x >= 65 && x <= 90) || x == 95) {
    lua_pushlstring(L, &s->data[s->t.index], 1);
    ++s->t.index;
    return 1;
  }
  return 0;
}

static int char_stream_numeric(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0 ||
      s->t.index >= s->len)
    return 0;
  char x = s->data[s->t.index];
  if (x >= 48 && x <= 57) {
    lua_pushlstring(L, &s->data[s->t.index], 1);
    ++s->t.index;
    return 1;
  }
  return 0;
}

static int char_stream_alphanumeric(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0 ||
      s->t.index >= s->len)
    return 0;
  char x = s->data[s->t.index];
  if ((x >= 97 && x <= 122) || (x >= 65 && x <= 90) || (x >= 48 && x <= 57) ||
      x == 95) {
    lua_pushlstring(L, &s->data[s->t.index], 1);
    ++s->t.index;
    return 1;
  }
  return 0;
}

const luaL_Reg library[] = {
    {"new", char_stream_new},
    {"peek", char_stream_peek},
    {"take", char_stream_take},
    {"begin", char_stream_begin},
    {"undo", char_stream_undo},
    {"commit", char_stream_commit},
    {"pos", char_stream_pos},
    {"try_consume_string", char_stream_try_consume_string},
    {"skipws", char_stream_skipws},
    {"suspend_skip_ws", char_stream_suspend_skip_ws},
    {"resume_skip_ws", char_stream_resume_skip_ws},
    {"alpha", char_stream_alpha},
    {"numeric", char_stream_numeric},
    {"alphanumeric", char_stream_alphanumeric},
    {NULL, NULL}};

int qamar_char_stream_init(lua_State *L) {
  luaL_newmetatable(L, QAMAR_TYPE_CHAR_STREAM);

  lua_pushstring(L, "__index");
  lua_newtable(L);

  for (const luaL_Reg *ptr = &library[1];; ++ptr)
    if (ptr->name == 0)
      break;
    else {
      lua_pushstring(L, ptr->name);
      lua_pushcfunction(L, ptr->func);
      lua_rawset(L, -3);
    }

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
