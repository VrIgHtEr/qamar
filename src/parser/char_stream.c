#include "char_stream.h"
#include <lauxlib.h>
#include <lua.h>
#include <stdbool.h>
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

extern const char *char_stream_peek(char_stream_t *s, size_t skip) {
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

extern const char *char_stream_take(char_stream_t *s, size_t *a) {
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

extern void char_stream_begin(char_stream_t *s) {
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

extern void char_stream_undo(char_stream_t *s) {
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

extern void char_stream_commit(char_stream_t *s) {
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

extern qamar_position_t char_stream_pos(char_stream_t *s) {
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

extern const char *char_stream_try_consume_string(char_stream_t *s,
                                                  const char *str,
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

extern void char_stream_skipws(char_stream_t *s) {
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

extern void char_stream_suspend_skip_ws(char_stream_t *s) { ++s->skip_ws_ctr; }

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

extern void char_stream_resume_skip_ws(char_stream_t *s) {
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

extern const char *char_stream_alpha(char_stream_t *s) {
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

extern const char *char_stream_numeric(char_stream_t *s) {
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

extern const char *char_stream_alphanumeric(char_stream_t *s) {
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

static inline bool is_alphanum(const char x) {
  return (x >= 97 && x <= 122) || (x >= 65 && x <= 90) ||
         (x >= 48 && x <= 57) || x == 95;
}

#define QAMAR_TOKEN_AND 1
#define QAMAR_TOKEN_BREAK 2
#define QAMAR_TOKEN_DO 3
#define QAMAR_TOKEN_ELSE 4
#define QAMAR_TOKEN_ELSEIF 5
#define QAMAR_TOKEN_END 6
#define QAMAR_TOKEN_FALSE 7
#define QAMAR_TOKEN_FOR 8
#define QAMAR_TOKEN_FUNCTION 9
#define QAMAR_TOKEN_GOTO 10
#define QAMAR_TOKEN_IF 11
#define QAMAR_TOKEN_IN 12
#define QAMAR_TOKEN_LOCAL 13
#define QAMAR_TOKEN_NIL 14
#define QAMAR_TOKEN_NOT 15
#define QAMAR_TOKEN_OR 16
#define QAMAR_TOKEN_REPEAT 17
#define QAMAR_TOKEN_RETURN 18
#define QAMAR_TOKEN_THEN 19
#define QAMAR_TOKEN_TRUE 20
#define QAMAR_TOKEN_UNTIL 21
#define QAMAR_TOKEN_WHILE 22
#define QAMAR_TOKEN_COMMENT 23
#define QAMAR_TOKEN_NAME 24
#define QAMAR_TOKEN_STRING 25
#define QAMAR_TOKEN_NUMBER 26
#define QAMAR_TOKEN_PLUS 27
#define QAMAR_TOKEN_DASH 28
#define QAMAR_TOKEN_ASTERISK 29
#define QAMAR_TOKEN_SLASH 30
#define QAMAR_TOKEN_PERCENT 31
#define QAMAR_TOKEN_CARET 32
#define QAMAR_TOKEN_HASH 33
#define QAMAR_TOKEN_AMPERSAND 34
#define QAMAR_TOKEN_TILDE 35
#define QAMAR_TOKEN_PIPE 36
#define QAMAR_TOKEN_LSHIFT 37
#define QAMAR_TOKEN_RSHIFT 38
#define QAMAR_TOKEN_DOUBLESLASH 39
#define QAMAR_TOKEN_EQUAL 40
#define QAMAR_TOKEN_NOTEQUAL 41
#define QAMAR_TOKEN_LESSEQUAL 42
#define QAMAR_TOKEN_GREATEREQUAL 43
#define QAMAR_TOKEN_LESS 44
#define QAMAR_TOKEN_GREATER 45
#define QAMAR_TOKEN_ASSIGNMENT 46
#define QAMAR_TOKEN_LPAREN 47
#define QAMAR_TOKEN_RPAREN 48
#define QAMAR_TOKEN_LBRACE 49
#define QAMAR_TOKEN_RBRACE 50
#define QAMAR_TOKEN_LBRACKET 51
#define QAMAR_TOKEN_RBRACKET 52
#define QAMAR_TOKEN_DOUBLECOLON 53
#define QAMAR_TOKEN_SEMICOLON 54
#define QAMAR_TOKEN_COLON 55
#define QAMAR_TOKEN_COMMA 56
#define QAMAR_TOKEN_DOT 57
#define QAMAR_TOKEN_DOUBLEDOT 58
#define QAMAR_TOKEN_TRIPLEDOT 59

static void lua_create_token_type_table(lua_State *L) {
  lua_newtable(L);
  lua_pushstring(L, "kw_and");
  lua_rawseti(L, -2, 1);
  lua_pushstring(L, "kw_break");
  lua_rawseti(L, -2, 2);
  lua_pushstring(L, "kw_do");
  lua_rawseti(L, -2, 3);
  lua_pushstring(L, "kw_else");
  lua_rawseti(L, -2, 4);
  lua_pushstring(L, "kw_elseif");
  lua_rawseti(L, -2, 5);
  lua_pushstring(L, "kw_end");
  lua_rawseti(L, -2, 6);
  lua_pushstring(L, "kw_false");
  lua_rawseti(L, -2, 7);
  lua_pushstring(L, "kw_for");
  lua_rawseti(L, -2, 8);
  lua_pushstring(L, "kw_function");
  lua_rawseti(L, -2, 9);
  lua_pushstring(L, "kw_goto");
  lua_rawseti(L, -2, 10);
  lua_pushstring(L, "kw_if");
  lua_rawseti(L, -2, 11);
  lua_pushstring(L, "kw_in");
  lua_rawseti(L, -2, 12);
  lua_pushstring(L, "kw_local");
  lua_rawseti(L, -2, 13);
  lua_pushstring(L, "kw_nil");
  lua_rawseti(L, -2, 14);
  lua_pushstring(L, "kw_not");
  lua_rawseti(L, -2, 15);
  lua_pushstring(L, "kw_or");
  lua_rawseti(L, -2, 16);
  lua_pushstring(L, "kw_repeat");
  lua_rawseti(L, -2, 17);
  lua_pushstring(L, "kw_return");
  lua_rawseti(L, -2, 18);
  lua_pushstring(L, "kw_then");
  lua_rawseti(L, -2, 19);
  lua_pushstring(L, "kw_true");
  lua_rawseti(L, -2, 20);
  lua_pushstring(L, "kw_until");
  lua_rawseti(L, -2, 21);
  lua_pushstring(L, "kw_while");
  lua_rawseti(L, -2, 22);
  lua_pushstring(L, "comment");
  lua_rawseti(L, -2, 23);
  lua_pushstring(L, "name");
  lua_rawseti(L, -2, 24);
  lua_pushstring(L, "string");
  lua_rawseti(L, -2, 25);
  lua_pushstring(L, "number");
  lua_rawseti(L, -2, 26);
  lua_pushstring(L, "plus");
  lua_rawseti(L, -2, 27);
  lua_pushstring(L, "dash");
  lua_rawseti(L, -2, 28);
  lua_pushstring(L, "asterisk");
  lua_rawseti(L, -2, 29);
  lua_pushstring(L, "slash");
  lua_rawseti(L, -2, 30);
  lua_pushstring(L, "percent");
  lua_rawseti(L, -2, 31);
  lua_pushstring(L, "caret");
  lua_rawseti(L, -2, 32);
  lua_pushstring(L, "hash");
  lua_rawseti(L, -2, 33);
  lua_pushstring(L, "ampersand");
  lua_rawseti(L, -2, 34);
  lua_pushstring(L, "tilde");
  lua_rawseti(L, -2, 35);
  lua_pushstring(L, "pipe");
  lua_rawseti(L, -2, 36);
  lua_pushstring(L, "lshift");
  lua_rawseti(L, -2, 37);
  lua_pushstring(L, "rshift");
  lua_rawseti(L, -2, 38);
  lua_pushstring(L, "doubleslash");
  lua_rawseti(L, -2, 39);
  lua_pushstring(L, "equal");
  lua_rawseti(L, -2, 40);
  lua_pushstring(L, "notequal");
  lua_rawseti(L, -2, 41);
  lua_pushstring(L, "lessequal");
  lua_rawseti(L, -2, 42);
  lua_pushstring(L, "greaterequal");
  lua_rawseti(L, -2, 43);
  lua_pushstring(L, "less");
  lua_rawseti(L, -2, 44);
  lua_pushstring(L, "greater");
  lua_rawseti(L, -2, 45);
  lua_pushstring(L, "assignment");
  lua_rawseti(L, -2, 46);
  lua_pushstring(L, "lparen");
  lua_rawseti(L, -2, 47);
  lua_pushstring(L, "rparen");
  lua_rawseti(L, -2, 48);
  lua_pushstring(L, "lbrace");
  lua_rawseti(L, -2, 49);
  lua_pushstring(L, "rbrace");
  lua_rawseti(L, -2, 50);
  lua_pushstring(L, "lbracket");
  lua_rawseti(L, -2, 51);
  lua_pushstring(L, "rbracket");
  lua_rawseti(L, -2, 52);
  lua_pushstring(L, "doublecolon");
  lua_rawseti(L, -2, 53);
  lua_pushstring(L, "semicolon");
  lua_rawseti(L, -2, 54);
  lua_pushstring(L, "colon");
  lua_rawseti(L, -2, 55);
  lua_pushstring(L, "comma");
  lua_rawseti(L, -2, 56);
  lua_pushstring(L, "dot");
  lua_rawseti(L, -2, 57);
  lua_pushstring(L, "doubledot");
  lua_rawseti(L, -2, 58);
  lua_pushstring(L, "tripledot");
  lua_rawseti(L, -2, 59);
}

extern bool char_stream_keyword(char_stream_t *s, qamar_token_t *out) {
  char_stream_skipws(s);
  out->pos.left = char_stream_pos(s);
  size_t amt = s->len - s->t.index;
  if (amt == 0)
    return false;
  const char *start = &s->data[s->t.index];
  const char *p = start;
  switch (*p) {
  case 'a':
    if (--amt == 0 || *++p != 'n' || --amt == 0 || *++p != 'd' ||
        (--amt > 0 && is_alphanum(*++p)))
      return false;
    if (--amt == 0 || *++p)
      out->len = 3;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_AND;
    return true;
  case 'b':
    if (--amt == 0 || *++p != 'r' || --amt == 0 || *++p != 'e' || --amt == 0 ||
        *++p != 'a' || --amt == 0 || *++p != 'k' ||
        (--amt > 0 && is_alphanum(*++p)))
      return false;
    out->len = 5;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_BREAK;
    return true;
  case 'd':
    if (--amt == 0 || *++p != 'o' || (--amt > 0 && is_alphanum(*++p)))
      return false;
    out->len = 2;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_DO;
    return true;
  case 'e':
    if (--amt == 0)
      return false;
    switch (*++p) {
    case 'l':
      if (--amt == 0 || *++p != 's' || --amt == 0 || *++p != 'e')
        return false;
      if (--amt > 0 && !is_alphanum(*++p)) {
        out->len = 4;
        out->value = char_stream_take(s, &out->len);
        out->pos.right = char_stream_pos(s);
        out->type = QAMAR_TOKEN_ELSE;
        return true;
      } else if (*p != 'i' || --amt == 0 || *++p != 'f' ||
                 (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 6;
      out->value = char_stream_take(s, &out->len);
      out->pos.right = char_stream_pos(s);
      out->type = QAMAR_TOKEN_ELSEIF;
      return true;
    case 'n':
      if (--amt == 0 || *++p != 'd' || (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 3;
      out->value = char_stream_take(s, &out->len);
      out->pos.right = char_stream_pos(s);
      out->type = QAMAR_TOKEN_END;
      return true;
    }
    break;
  case 'f':
    if (--amt == 0)
      return false;
    switch (*++p) {
    case 'a':
      if (--amt == 0 || *++p != 'l' || --amt == 0 || *++p != 's' ||
          --amt == 0 || *++p != 'e' || (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 5;
      out->value = char_stream_take(s, &out->len);
      out->pos.right = char_stream_pos(s);
      out->type = QAMAR_TOKEN_FALSE;
      return true;
    case 'o':
      if (--amt == 0 || *++p != 'r' || (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 3;
      out->value = char_stream_take(s, &out->len);
      out->pos.right = char_stream_pos(s);
      out->type = QAMAR_TOKEN_FOR;
      return true;
    case 'u':
      if (--amt == 0 || *++p != 'n' || --amt == 0 || *++p != 'c' ||
          --amt == 0 || *++p != 't' || --amt == 0 || *++p != 'i' ||
          --amt == 0 || *++p != 'o' || --amt == 0 || *++p != 'n' ||
          (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 8;
      out->value = char_stream_take(s, &out->len);
      out->pos.right = char_stream_pos(s);
      out->type = QAMAR_TOKEN_FUNCTION;
      return true;
    }
    break;
  case 'g':
    if (--amt == 0 || *++p != 'o' || --amt == 0 || *++p != 't' || --amt == 0 ||
        *++p != 'o' || (--amt > 0 && is_alphanum(*++p)))
      return false;
    out->len = 4;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_GOTO;
    return true;
    break;
  case 'i':
    if (--amt == 0)
      return false;
    switch (*++p) {
    case 'f':
      if (--amt > 0 && is_alphanum(*++p))
        return false;
      out->len = 2;
      out->value = char_stream_take(s, &out->len);
      out->pos.right = char_stream_pos(s);
      out->type = QAMAR_TOKEN_IF;
      return true;
    case 'n':
      if (--amt > 0 && is_alphanum(*++p))
        return false;
      out->len = 2;
      out->value = char_stream_take(s, &out->len);
      out->pos.right = char_stream_pos(s);
      out->type = QAMAR_TOKEN_IN;
      return true;
    }
    break;
  case 'l':
    if (--amt == 0 || *++p != 'o' || --amt == 0 || *++p != 'c' || --amt == 0 ||
        *++p != 'a' || --amt == 0 || *++p != 'l' ||
        (--amt > 0 && is_alphanum(*++p)))
      return false;
    out->len = 5;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_LOCAL;
    return true;
  case 'n':
    if (--amt == 0)
      return false;
    switch (*++p) {
    case 'i':
      if (--amt == 0 || *++p != 'l' || (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 3;
      out->value = char_stream_take(s, &out->len);
      out->pos.right = char_stream_pos(s);
      out->type = QAMAR_TOKEN_NIL;
      return true;
    case 'o':
      if (--amt == 0 || *++p != 't' || (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 3;
      out->value = char_stream_take(s, &out->len);
      out->pos.right = char_stream_pos(s);
      out->type = QAMAR_TOKEN_NOT;
      return true;
    }
    break;
  case 'o':
    if (--amt == 0 || *++p != 'r' || (--amt > 0 && is_alphanum(*++p)))
      return false;
    out->len = 2;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_OR;
    return true;
  case 'r':
    if (--amt == 0 || *++p != 'e')
      return false;
    if (--amt == 0)
      return false;
    switch (*++p) {
    case 'p':
      if (--amt == 0 || *++p != 'e' || --amt == 0 || *++p != 'a' ||
          --amt == 0 || *++p != 't' || (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 6;
      out->value = char_stream_take(s, &out->len);
      out->pos.right = char_stream_pos(s);
      out->type = QAMAR_TOKEN_REPEAT;
      return true;
    case 't':
      if (--amt == 0 || *++p != 'u' || --amt == 0 || *++p != 'r' ||
          --amt == 0 || *++p != 'n' || (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 6;
      out->value = char_stream_take(s, &out->len);
      out->pos.right = char_stream_pos(s);
      out->type = QAMAR_TOKEN_RETURN;
      return true;
    }
    break;
  case 't':
    if (--amt == 0)
      return false;
    switch (*++p) {
    case 'h':
      if (--amt == 0 || *++p != 'e' || --amt == 0 || *++p != 'n' ||
          (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 4;
      out->value = char_stream_take(s, &out->len);
      out->pos.right = char_stream_pos(s);
      out->type = QAMAR_TOKEN_THEN;
      return true;
    case 'r':
      if (--amt == 0 || *++p != 'u' || --amt == 0 || *++p != 'e' ||
          (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 4;
      out->value = char_stream_take(s, &out->len);
      out->pos.right = char_stream_pos(s);
      out->type = QAMAR_TOKEN_TRUE;
      return true;
    }
    break;
  case 'u':
    if (--amt == 0 || *++p != 'n' || --amt == 0 || *++p != 't' || --amt == 0 ||
        *++p != 'i' || --amt == 0 || *++p != 'l' ||
        (--amt > 0 && is_alphanum(*++p)))
      return false;
    out->len = 5;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_UNTIL;
    return true;
  case 'w':
    if (--amt == 0 || *++p != 'h' || --amt == 0 || *++p != 'i' || --amt == 0 ||
        *++p != 'l' || --amt == 0 || *++p != 'e' ||
        (--amt > 0 && is_alphanum(*++p)))
      return false;
    out->len = 5;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_WHILE;
    return true;
  case '#':
    out->len = 1;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_HASH;
    return true;
  case '%':
    out->len = 1;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_PERCENT;
    return true;
  case '&':
    out->len = 1;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_AMPERSAND;
    return true;
  case '(':
    out->len = 1;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_LPAREN;
    return true;
  case ')':
    out->len = 1;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_RPAREN;
    return true;
  case '*':
    out->len = 1;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_ASTERISK;
    return true;
  case '+':
    out->len = 1;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_PLUS;
    return true;
  case ',':
    out->len = 1;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_COMMA;
    return true;
  case '-':
    out->len = 1;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_DASH;
    return true;
  case '[':
    out->len = 1;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_LBRACKET;
    return true;
  case ']':
    out->len = 1;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_RBRACKET;
    return true;
  case '^':
    out->len = 1;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_CARET;
    return true;
  case '{':
    out->len = 1;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_LBRACE;
    return true;
  case '|':
    out->len = 1;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_PIPE;
    return true;
  case '}':
    out->len = 1;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_RBRACE;
    return true;
  case ';':
    out->len = 1;
    out->value = char_stream_take(s, &out->len);
    out->pos.right = char_stream_pos(s);
    out->type = QAMAR_TOKEN_SEMICOLON;
    return true;
  case '/':
    if (--amt == 0) {
      out->len = 1;
      out->value = char_stream_take(s, &out->len);
      out->pos.right = char_stream_pos(s);
      out->type = QAMAR_TOKEN_SLASH;
      return true;
    }
    if (*++p == '/') {
      out->len = 2;
      out->value = char_stream_take(s, &out->len);
      out->type = QAMAR_TOKEN_DOUBLESLASH;
    } else {
      out->len = 1;
      out->value = char_stream_take(s, &out->len);
      out->type = QAMAR_TOKEN_SLASH;
    }
    out->pos.right = char_stream_pos(s);
    return true;
  case ':':
    if (--amt == 0) {
      out->len = 1;
      out->value = char_stream_take(s, &out->len);
      out->pos.right = char_stream_pos(s);
      out->type = QAMAR_TOKEN_COLON;
      return true;
    }
    if (*++p == ':') {
      out->len = 2;
      out->value = char_stream_take(s, &out->len);
      out->type = QAMAR_TOKEN_DOUBLECOLON;
    } else {
      out->len = 1;
      out->value = char_stream_take(s, &out->len);
      out->type = QAMAR_TOKEN_COLON;
    }
    out->pos.right = char_stream_pos(s);
    return true;
  case '=':
    if (--amt == 0) {
      out->len = 1;
      out->value = char_stream_take(s, &out->len);
      out->pos.right = char_stream_pos(s);
      out->type = QAMAR_TOKEN_ASSIGNMENT;
      return true;
    }
    if (*++p == '=') {
      out->len = 2;
      out->value = char_stream_take(s, &out->len);
      out->type = QAMAR_TOKEN_EQUAL;
    } else {
      out->len = 1;
      out->value = char_stream_take(s, &out->len);
      out->type = QAMAR_TOKEN_ASSIGNMENT;
    }
    out->pos.right = char_stream_pos(s);
    return true;
  case '~':
    if (--amt == 0) {
      out->len = 1;
      out->value = char_stream_take(s, &out->len);
      out->pos.right = char_stream_pos(s);
      out->type = QAMAR_TOKEN_TILDE;
      return true;
    }
    if (*++p == '=') {
      out->len = 2;
      out->value = char_stream_take(s, &out->len);
      out->type = QAMAR_TOKEN_NOTEQUAL;
    } else {
      out->len = 1;
      out->value = char_stream_take(s, &out->len);
      out->type = QAMAR_TOKEN_TILDE;
    }
    out->pos.right = char_stream_pos(s);
    return true;
  }
  return false;
}
/*
        ["."] = token.dot,
        [".."] = token.doubledot,
        ["..."] = token.tripledot,
        ["<"] = token.less,
        ["<<"] = token.lshift,
        ["<="] = token.lessequal,
        [">"] = token.greater,
        [">="] = token.greaterequal,
        [">>"] = token.rshift,
 */

static void lua_qamar_create_token(lua_State *L, const qamar_token_t *token) {
  lua_newtable(L);
  lua_pushstring(L, "value");
  lua_pushlstring(L, token->value, token->len);
  lua_rawset(L, -3);
  lua_pushstring(L, "type");
  lua_pushnumber(L, token->type);
  lua_rawset(L, -3);
  lua_pushstring(L, "pos");
  lua_newtable(L);
  lua_pushstring(L, "left");
  lua_newtable(L);
  lua_pushstring(L, "col");
  lua_pushnumber(L, token->pos.left.col);
  lua_rawset(L, -3);
  lua_pushstring(L, "row");
  lua_pushnumber(L, token->pos.left.row);
  lua_rawset(L, -3);
  lua_pushstring(L, "byte");
  lua_pushnumber(L, token->pos.left.byte);
  lua_rawset(L, -3);
  lua_pushstring(L, "file_char");
  lua_pushnumber(L, token->pos.left.file_char);
  lua_rawset(L, -3);
  lua_pushstring(L, "file_byte");
  lua_pushnumber(L, token->pos.left.file_byte);
  lua_rawset(L, -3);
  lua_rawset(L, -3);
  lua_pushstring(L, "right");
  lua_newtable(L);
  lua_pushstring(L, "col");
  lua_pushnumber(L, token->pos.right.col);
  lua_rawset(L, -3);
  lua_pushstring(L, "row");
  lua_pushnumber(L, token->pos.right.row);
  lua_rawset(L, -3);
  lua_pushstring(L, "byte");
  lua_pushnumber(L, token->pos.right.byte);
  lua_rawset(L, -3);
  lua_pushstring(L, "file_char");
  lua_pushnumber(L, token->pos.right.file_char);
  lua_rawset(L, -3);
  lua_pushstring(L, "file_byte");
  lua_pushnumber(L, token->pos.right.file_byte);
  lua_rawset(L, -3);
  lua_rawset(L, -3);
  lua_rawset(L, -3);
}

static int lua_char_stream_keyword(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0 ||
      s->t.index >= s->len)
    return 0;
  qamar_token_t token;
  if (!char_stream_keyword(s, &token))
    return 0;
  lua_qamar_create_token(L, &token);
  return 1;
}

extern bool char_stream_name(char_stream_t *s, qamar_token_t *out) {
  char_stream_skipws(s);
  out->pos.left = char_stream_pos(s);
  out->value = char_stream_alpha(s);
  if (out->value == NULL)
    return false;
  out->len = 1;
  out->type = QAMAR_TOKEN_NAME;
  while (char_stream_alphanumeric(s))
    ++out->len;
  out->pos.right = char_stream_pos(s);
  return true;
}

static int lua_char_stream_name(lua_State *L) {
  char_stream_t *s;
  if (lua_gettop(L) < 1 ||
      (s = luaL_checkudata(L, 1, QAMAR_TYPE_CHAR_STREAM)) == 0 ||
      s->t.index >= s->len)
    return 0;
  qamar_token_t token;
  if (!char_stream_name(s, &token))
    return 0;
  lua_qamar_create_token(L, &token);
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
    {"keyword", lua_char_stream_keyword},
    {"name", lua_char_stream_name},
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
  lua_pushstring(L, "types");
  lua_create_token_type_table(L);
  lua_rawset(L, -3);

  lua_pop(L, 1);
  return 0;
}
