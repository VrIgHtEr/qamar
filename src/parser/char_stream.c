#include "char_stream.h"
#include <lauxlib.h>
#include <lua.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

//#define QAMAR_TRACE

const char *QAMAR_TYPE_CHAR_STREAM = "__QAMAR_CHAR_STREAM";

int char_stream_new(char_stream_t *c, const char *str, const size_t len) {
  memcpy((void *)c->data, str, len);
  c->skip_ws_ctr = 0;
  c->len = len;
  c->t.file_byte = 0;
  c->t.byte = 0;
  c->t.file_char = 0;
  c->t.col = 1;
  c->t.index = 0;
  c->t.row = 1;
  c->transactions_capacity = 1;
  c->transactions_index = 0;
  c->transactions =
      malloc(sizeof(char_stream_transaction_t) * c->transactions_capacity);
  if (c->transactions == NULL)
    return 1;
  return 0;
}

static int lua_char_stream_new(lua_State *L) {
#ifdef QAMAR_TRACE
  printf("NEW\n");
  fflush(stdout);
#endif
  if (!lua_isstring(L, 1))
    return 0;
  size_t len;
  const char *str = lua_tolstring(L, 1, &len);
  char_stream_t *c = lua_newuserdata(L, sizeof(char_stream_t) + len);
  if (char_stream_new(c, str, len))
    return 0;
  luaL_getmetatable(L, QAMAR_TYPE_CHAR_STREAM);
  lua_setmetatable(L, -2);
  return 1;
}

static int lua_char_stream_destroy(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("DESTROY\n");
  fflush(stdout);
#endif
  if (s->transactions != NULL)
    free(s->transactions);
  s->transactions = NULL;
  return 0;
}

static int lua_char_stream_tostring(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  //  printf("TOSTRING\n");
  fflush(stdout);
#endif
  int amt = snprintf(0, 0, "<char_stream>:%ld:%ld:%ld", s->len, s->t.index,
                     s->transactions_index);
  if (amt < 0)
    return 0;
  char t[amt + 1];
  snprintf(t, amt + 1, "<char_stream>:%ld:%ld:%ld", s->len, s->t.index,
           s->transactions_index);
  lua_pushlstring(L, t, amt);
  return 1;
}

const char *char_stream_peek(char_stream_t *s, size_t skip) {
  return s->t.index + skip < s->len ? &s->data[s->t.index + skip] : NULL;
}

static int lua_char_stream_peek(lua_State *L) {
  char_stream_t *s;
  int top = lua_gettop(L);
  if (top < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("PEEK\n");
  fflush(stdout);
#endif
  size_t skip = 0;
  if (top >= 2) {
    if (lua_isnumber(L, 2)) {
      int val = (int)lua_tonumber(L, 2);
      if (val >= 0) {
        skip = val;
      } else
        return 0;
    } else
      return 0;
  }
  const char *p = char_stream_peek(s, skip);
  if (p == NULL)
    return 0;
  lua_pushlstring(L, p, 1);
  return 1;
}

const char *char_stream_take(char_stream_t *s, size_t *a) {
  size_t amt = *a;
  if (s->t.index + amt > s->len) {
    amt = s->len - s->t.index;
  }
  if (amt == 0)
    return NULL;
  const char *start = &s->data[s->t.index];
  const char *const max = &s->data[s->t.index + amt];
  for (const char *c = start; c < max; ++c) {
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
  s->t.index += amt;
  *a = amt;
  return start;
}

static int lua_char_stream_take(lua_State *L) {
  char_stream_t *s;
  int top = lua_gettop(L);
  if (top < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("TAKE\n");
  fflush(stdout);
#endif
  size_t amt = 1;
  if (top >= 2) {
    if (lua_isnumber(L, 2)) {
      int val = (int)lua_tonumber(L, 2);
      if (val > 0)
        amt = val;
      else
        return 0;
    } else
      return 0;
  }
  const char *str = char_stream_take(s, &amt);
  if (str == NULL)
    return 0;
  lua_pushlstring(L, str, amt);
  return 1;
}

void char_stream_begin(char_stream_t *s) {
  if (s->transactions_index == s->transactions_capacity) {
    size_t newcapacity = s->transactions_capacity * 2;
    char_stream_transaction_t *newbuf = realloc(
        s->transactions, sizeof(char_stream_transaction_t) * newcapacity);
    if (newbuf == 0)
      exit(-1);
    s->transactions_capacity = newcapacity;
    s->transactions = newbuf;
  }
  s->transactions[s->transactions_index++] = s->t;
}

static int lua_char_stream_begin(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("BEGIN\n");
  fflush(stdout);
#endif
  char_stream_begin(s);
  return 0;
}

void char_stream_undo(char_stream_t *s) {
  if (s->transactions_index > 0)
    s->t = s->transactions[--s->transactions_index];
}

static int lua_char_stream_undo(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("UNDO\n");
  fflush(stdout);
#endif
  char_stream_undo(s);
  return 0;
}

void char_stream_commit(char_stream_t *s) {
  if (s->transactions_index > 0)
    --s->transactions_index;
}

static int lua_char_stream_commit(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("COMMIT\n");
  fflush(stdout);
#endif
  char_stream_commit(s);
  return 0;
}

qamar_position_t char_stream_pos(char_stream_t *s) {
  qamar_position_t p;
  p.col = s->t.col;
  p.row = s->t.row;
  p.byte = s->t.byte;
  p.file_char = s->t.file_char;
  p.file_byte = s->t.file_byte;
  return p;
}

static int lua_char_stream_pos(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("POS\n");
  fflush(stdout);
#endif
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

const char *char_stream_try_consume_string(char_stream_t *s, const char *str,
                                           const size_t len) {
  if (s->t.index + len > s->len)
    return NULL;
  for (size_t i = 0; i < len; ++i)
    if (s->data[s->t.index + i] != str[i])
      return NULL;
  s->t.index += len;
  return &s->data[s->t.index];
}

static int lua_char_stream_try_consume_string(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 2 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0 ||
      !lua_isstring(L, 2))
    return 0;
#ifdef QAMAR_TRACE
  printf("TRY_CONSUME_STRING\n");
  fflush(stdout);
#endif
  size_t len;
  const char *str = lua_tolstring(L, 2, &len);
  const char *x = char_stream_try_consume_string(s, str, len);
  if (x == NULL)
    return 0;
  lua_pushlstring(L, x, len);
  return 1;
}

void char_stream_skipws(char_stream_t *s) {
  if (s->skip_ws_ctr == 0) {
    for (; s->t.index < s->len; ++s->t.index) {
      char x = s->data[s->t.index];
      if (x != ' ' && x != '\f' && x != '\n' && x != '\r' && x != '\t' &&
          x != '\v')
        break;
    }
  }
}

static int lua_char_stream_skipws(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("SKIPWS\n");
  fflush(stdout);
#endif
  char_stream_skipws(s);
  return 0;
}

void char_stream_suspend_skip_ws(char_stream_t *s) { ++s->skip_ws_ctr; }

static int lua_char_stream_suspend_skip_ws(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("SUSPEND_SKIP_WS\n");
  fflush(stdout);
#endif
  char_stream_suspend_skip_ws(s);
  return 0;
}

void char_stream_resume_skip_ws(char_stream_t *s) {
  if (s->skip_ws_ctr > 0)
    --s->skip_ws_ctr;
}

static int lua_char_stream_resume_skip_ws(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("RESUME_SKIP_WS\n");
  fflush(stdout);
#endif
  char_stream_resume_skip_ws(s);
  return 0;
}

const char *char_stream_alpha(char_stream_t *s) {
  if (s->t.index >= s->len)
    return NULL;
  const char *ret = &s->data[s->t.index];
  const char x = *ret;
  if ((x >= 97 && x <= 122) || (x >= 65 && x <= 90) || x == 95) {
    ++s->t.index;
    return ret;
  }
  return NULL;
}

static int lua_char_stream_alpha(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("ALPHA\n");
  fflush(stdout);
#endif
  const char *x = char_stream_alpha(s);
  if (x == NULL)
    return 0;
  lua_pushlstring(L, x, 1);
  return 1;
}

const char *char_stream_numeric(char_stream_t *s) {
  if (s->t.index >= s->len)
    return NULL;
  const char *ret = &s->data[s->t.index];
  const char x = *ret;
  if (x >= 48 && x <= 57) {
    ++s->t.index;
    return ret;
  }
  return NULL;
}

static int lua_char_stream_numeric(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0 ||
      s->t.index >= s->len)
    return 0;
#ifdef QAMAR_TRACE
  printf("NUMERIC\n");
  fflush(stdout);
#endif
  const char *x = char_stream_numeric(s);
  if (x == NULL)
    return 0;
  lua_pushlstring(L, x, 1);
  return 1;
}

const char *char_stream_alphanumeric(char_stream_t *s) {
  if (s->t.index >= s->len)
    return NULL;
  const char *ret = &s->data[s->t.index];
  const char x = *ret;
  if ((x >= 97 && x <= 122) || (x >= 65 && x <= 90) || (x >= 48 && x <= 57) ||
      x == 95) {
    ++s->t.index;
    return ret;
  }
  return NULL;
}

static int lua_char_stream_alphanumeric(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0 ||
      s->t.index >= s->len)
    return 0;
#ifdef QAMAR_TRACE
  printf("ALPHANUMERIC\n");
  fflush(stdout);
#endif
  const char *x = char_stream_alphanumeric(s);
  if (x == NULL)
    return 0;
  lua_pushlstring(L, x, 1);
  return 1;
}

const luaL_Reg library[] = {
    {"new", lua_char_stream_new},
    {"peek", lua_char_stream_peek},
    {"take", lua_char_stream_take},
    {"begin", lua_char_stream_begin},
    {"undo", lua_char_stream_undo},
    {"commit", lua_char_stream_commit},
    {"pos", lua_char_stream_pos},
    {"try_consume_string", lua_char_stream_try_consume_string},
    {"skipws", lua_char_stream_skipws},
    {"suspend_skip_ws", lua_char_stream_suspend_skip_ws},
    {"resume_skip_ws", lua_char_stream_resume_skip_ws},
    {"alpha", lua_char_stream_alpha},
    {"numeric", lua_char_stream_numeric},
    {"alphanumeric", lua_char_stream_alphanumeric},
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
  lua_pushcfunction(L, lua_char_stream_tostring);
  lua_rawset(L, -3);
  lua_pushstring(L, "__gc");
  lua_pushcfunction(L, lua_char_stream_destroy);
  lua_rawset(L, -3);
  lua_pop(L, 1);

  luaL_register(L, "char_stream", library);
  lua_pop(L, 1);
  return 0;
}
