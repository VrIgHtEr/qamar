#include "lexer.h"
#include "lexer_string.h"
#include "token_types.h"
#include <lauxlib.h>
#include <lua.h>
#include <stdbool.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

//#define QAMAR_TRACE

const char *QAMAR_TYPE_LEXER = "__QAMAR_LEXER";

extern int lexer_new(qamar_lexer_t *c, const char *str, const size_t len) {
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
      malloc(sizeof(qamar_lexer_transaction_t) * c->transactions_capacity);
  if (c->transactions == NULL)
    return 1;
  return 0;
}

static int lua_lexer_new(lua_State *L) {
#ifdef QAMAR_TRACE
  printf("NEW\n");
  fflush(stdout);
#endif
  if (!lua_isstring(L, 1))
    return 0;
  size_t len;
  const char *str = lua_tolstring(L, 1, &len);
  qamar_lexer_t *c = lua_newuserdata(L, sizeof(qamar_lexer_t) + len);
  if (lexer_new(c, str, len))
    return 0;
  luaL_getmetatable(L, QAMAR_TYPE_LEXER);
  lua_setmetatable(L, -2);
  return 1;
}

extern void lexer_destroy(qamar_lexer_t *s) {
  if (s->transactions != NULL)
    free(s->transactions);
  s->transactions = NULL;
}

static int lua_lexer_destroy(lua_State *L) {
  qamar_lexer_t *s;
  if (lua_gettop(L) < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_LEXER)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("DESTROY\n");
  fflush(stdout);
#endif
  lexer_destroy(s);
  return 0;
}

static int lua_lexer_tostring(lua_State *L) {
  qamar_lexer_t *s;
  if (lua_gettop(L) < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_LEXER)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  //  printf("TOSTRING\n");
  fflush(stdout);
#endif
  int amt = snprintf(0, 0, "<lexer>:%ld:%ld:%ld", s->len, s->t.index,
                     s->transactions_index);
  if (amt < 0)
    return 0;
  char t[amt + 1];
  snprintf(t, amt + 1, "<lexer>:%ld:%ld:%ld", s->len, s->t.index,
           s->transactions_index);
  lua_pushlstring(L, t, amt);
  return 1;
}

static void lua_qamar_create_position(lua_State *L, const qamar_position_t *t) {
  lua_newtable(L);
  lua_pushstring(L, "col");
  lua_pushnumber(L, t->col);
  lua_rawset(L, -3);
  lua_pushstring(L, "row");
  lua_pushnumber(L, t->row);
  lua_rawset(L, -3);
  lua_pushstring(L, "byte");
  lua_pushnumber(L, t->byte);
  lua_rawset(L, -3);
  lua_pushstring(L, "file_char");
  lua_pushnumber(L, t->file_char);
  lua_rawset(L, -3);
  lua_pushstring(L, "file_byte");
  lua_pushnumber(L, t->file_byte);
  lua_rawset(L, -3);
}

static void lua_qamar_create_range(lua_State *L, const qamar_range_t *r) {
  lua_newtable(L);
  lua_pushstring(L, "left");
  lua_qamar_create_position(L, &r->left);
  lua_rawset(L, -3);
  lua_pushstring(L, "right");
  lua_qamar_create_position(L, &r->right);
  lua_rawset(L, -3);
}

static void lua_qamar_create_token(lua_State *L, const qamar_token_t *token) {
  lua_newtable(L);
  lua_pushstring(L, "value");
  lua_pushlstring(L, token->value, token->len);
  lua_rawset(L, -3);
  lua_pushstring(L, "type");
  lua_pushnumber(L, token->type);
  lua_rawset(L, -3);
  lua_pushstring(L, "pos");
  lua_qamar_create_range(L, &token->pos);
  lua_rawset(L, -3);
}

extern const char *lexer_peek(qamar_lexer_t *s, size_t skip) {
  return s->t.index + skip < s->len ? &s->data[s->t.index + skip] : NULL;
}

static int lua_lexer_peek(lua_State *L) {
  qamar_lexer_t *s;
  int top = lua_gettop(L);
  if (top < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_LEXER)) == 0)
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
  const char *p = lexer_peek(s, skip);
  if (p == NULL)
    return 0;
  lua_pushlstring(L, p, 1);
  return 1;
}

extern const char *lexer_take(qamar_lexer_t *s, size_t *a) {
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

static int lua_lexer_take(lua_State *L) {
  qamar_lexer_t *s;
  int top = lua_gettop(L);
  if (top < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_LEXER)) == 0)
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
  const char *str = lexer_take(s, &amt);
  if (str == NULL)
    return 0;
  lua_pushlstring(L, str, amt);
  return 1;
}

extern void lexer_begin(qamar_lexer_t *s) {
  if (s->transactions_index == s->transactions_capacity) {
    size_t newcapacity = s->transactions_capacity * 2;
    qamar_lexer_transaction_t *newbuf = realloc(
        s->transactions, sizeof(qamar_lexer_transaction_t) * newcapacity);
    if (newbuf == 0)
      exit(-1);
    s->transactions_capacity = newcapacity;
    s->transactions = newbuf;
  }
  s->transactions[s->transactions_index++] = s->t;
}

static int lua_lexer_begin(lua_State *L) {
  qamar_lexer_t *s;
  if (lua_gettop(L) < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_LEXER)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("BEGIN\n");
  fflush(stdout);
#endif
  lexer_begin(s);
  return 0;
}

extern void lexer_undo(qamar_lexer_t *s) {
  if (s->transactions_index > 0)
    s->t = s->transactions[--s->transactions_index];
}

static int lua_lexer_undo(lua_State *L) {
  qamar_lexer_t *s;
  if (lua_gettop(L) < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_LEXER)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("UNDO\n");
  fflush(stdout);
#endif
  lexer_undo(s);
  return 0;
}

extern void lexer_commit(qamar_lexer_t *s) {
  if (s->transactions_index > 0)
    --s->transactions_index;
}

static int lua_lexer_commit(lua_State *L) {
  qamar_lexer_t *s;
  if (lua_gettop(L) < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_LEXER)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("COMMIT\n");
  fflush(stdout);
#endif
  lexer_commit(s);
  return 0;
}

extern qamar_position_t lexer_pos(qamar_lexer_t *s) {
  qamar_position_t p;
  p.col = s->t.col;
  p.row = s->t.row;
  p.byte = s->t.byte;
  p.file_char = s->t.file_char;
  p.file_byte = s->t.file_byte;
  return p;
}

static int lua_lexer_pos(lua_State *L) {
  qamar_lexer_t *s;
  if (lua_gettop(L) < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_LEXER)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("POS\n");
  fflush(stdout);
#endif
  qamar_position_t pos = lexer_pos(s);
  lua_qamar_create_position(L, &pos);
  return 1;
}

extern const char *lexer_try_consume_string(qamar_lexer_t *s, const char *str,
                                            const size_t len) {
  if (s->t.index + len > s->len)
    return NULL;
  for (size_t i = 0; i < len; ++i)
    if (s->data[s->t.index + i] != str[i])
      return NULL;
  s->t.index += len;
  return &s->data[s->t.index];
}

static int lua_lexer_try_consume_string(lua_State *L) {
  qamar_lexer_t *s;
  if (lua_gettop(L) < 2 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_LEXER)) == 0 ||
      !lua_isstring(L, 2))
    return 0;
#ifdef QAMAR_TRACE
  printf("TRY_CONSUME_STRING\n");
  fflush(stdout);
#endif
  size_t len;
  const char *str = lua_tolstring(L, 2, &len);
  const char *x = lexer_try_consume_string(s, str, len);
  if (x == NULL)
    return 0;
  lua_pushlstring(L, x, len);
  return 1;
}

extern void lexer_skipws(qamar_lexer_t *s) {
  if (s->skip_ws_ctr == 0) {
    for (; s->t.index < s->len; ++s->t.index) {
      char x = s->data[s->t.index];
      if (x != ' ' && x != '\f' && x != '\n' && x != '\r' && x != '\t' &&
          x != '\v')
        break;
    }
  }
}

static int lua_lexer_skipws(lua_State *L) {
  qamar_lexer_t *s;
  if (lua_gettop(L) < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_LEXER)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("SKIPWS\n");
  fflush(stdout);
#endif
  lexer_skipws(s);
  return 0;
}

extern void lexer_suspend_skip_ws(qamar_lexer_t *s) { ++s->skip_ws_ctr; }

static int lua_lexer_suspend_skip_ws(lua_State *L) {
  qamar_lexer_t *s;
  if (lua_gettop(L) < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_LEXER)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("SUSPEND_SKIP_WS\n");
  fflush(stdout);
#endif
  lexer_suspend_skip_ws(s);
  return 0;
}

extern void lexer_resume_skip_ws(qamar_lexer_t *s) {
  if (s->skip_ws_ctr > 0)
    --s->skip_ws_ctr;
}

static int lua_lexer_resume_skip_ws(lua_State *L) {
  qamar_lexer_t *s;
  if (lua_gettop(L) < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_LEXER)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("RESUME_SKIP_WS\n");
  fflush(stdout);
#endif
  lexer_resume_skip_ws(s);
  return 0;
}

extern const char *lexer_alpha(qamar_lexer_t *s) {
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

static int lua_lexer_alpha(lua_State *L) {
  qamar_lexer_t *s;
  if (lua_gettop(L) < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_LEXER)) == 0)
    return 0;
#ifdef QAMAR_TRACE
  printf("ALPHA\n");
  fflush(stdout);
#endif
  const char *x = lexer_alpha(s);
  if (x == NULL)
    return 0;
  lua_pushlstring(L, x, 1);
  return 1;
}

extern const char *lexer_numeric(qamar_lexer_t *s) {
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

static int lua_lexer_numeric(lua_State *L) {
  qamar_lexer_t *s;
  if (lua_gettop(L) < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_LEXER)) == 0 ||
      s->t.index >= s->len)
    return 0;
#ifdef QAMAR_TRACE
  printf("NUMERIC\n");
  fflush(stdout);
#endif
  const char *x = lexer_numeric(s);
  if (x == NULL)
    return 0;
  lua_pushlstring(L, x, 1);
  return 1;
}

extern const char *lexer_alphanumeric(qamar_lexer_t *s) {
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

static int lua_lexer_alphanumeric(lua_State *L) {
  qamar_lexer_t *s;
  if (lua_gettop(L) < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_LEXER)) == 0 ||
      s->t.index >= s->len)
    return 0;
#ifdef QAMAR_TRACE
  printf("ALPHANUMERIC\n");
  fflush(stdout);
#endif
  const char *x = lexer_alphanumeric(s);
  if (x == NULL)
    return 0;
  lua_pushlstring(L, x, 1);
  return 1;
}

static inline bool is_alphanum(const char x) {
  return (x >= 97 && x <= 122) || (x >= 65 && x <= 90) ||
         (x >= 48 && x <= 57) || x == 95;
}

static void lua_create_token_type_table(lua_State *L) {
  lua_newtable(L);
  lua_pushstring(L, "kw_and");
  lua_rawseti(L, -2, QAMAR_TOKEN_AND);
  lua_pushstring(L, "kw_break");
  lua_rawseti(L, -2, QAMAR_TOKEN_BREAK);
  lua_pushstring(L, "kw_do");
  lua_rawseti(L, -2, QAMAR_TOKEN_DO);
  lua_pushstring(L, "kw_else");
  lua_rawseti(L, -2, QAMAR_TOKEN_ELSE);
  lua_pushstring(L, "kw_elseif");
  lua_rawseti(L, -2, QAMAR_TOKEN_ELSEIF);
  lua_pushstring(L, "kw_end");
  lua_rawseti(L, -2, QAMAR_TOKEN_END);
  lua_pushstring(L, "kw_false");
  lua_rawseti(L, -2, QAMAR_TOKEN_FALSE);
  lua_pushstring(L, "kw_for");
  lua_rawseti(L, -2, QAMAR_TOKEN_FOR);
  lua_pushstring(L, "kw_function");
  lua_rawseti(L, -2, QAMAR_TOKEN_FUNCTION);
  lua_pushstring(L, "kw_goto");
  lua_rawseti(L, -2, QAMAR_TOKEN_GOTO);
  lua_pushstring(L, "kw_if");
  lua_rawseti(L, -2, QAMAR_TOKEN_IF);
  lua_pushstring(L, "kw_in");
  lua_rawseti(L, -2, QAMAR_TOKEN_IN);
  lua_pushstring(L, "kw_local");
  lua_rawseti(L, -2, QAMAR_TOKEN_LOCAL);
  lua_pushstring(L, "kw_nil");
  lua_rawseti(L, -2, QAMAR_TOKEN_NIL);
  lua_pushstring(L, "kw_not");
  lua_rawseti(L, -2, QAMAR_TOKEN_NOT);
  lua_pushstring(L, "kw_or");
  lua_rawseti(L, -2, QAMAR_TOKEN_OR);
  lua_pushstring(L, "kw_repeat");
  lua_rawseti(L, -2, QAMAR_TOKEN_REPEAT);
  lua_pushstring(L, "kw_return");
  lua_rawseti(L, -2, QAMAR_TOKEN_RETURN);
  lua_pushstring(L, "kw_then");
  lua_rawseti(L, -2, QAMAR_TOKEN_THEN);
  lua_pushstring(L, "kw_true");
  lua_rawseti(L, -2, QAMAR_TOKEN_TRUE);
  lua_pushstring(L, "kw_until");
  lua_rawseti(L, -2, QAMAR_TOKEN_UNTIL);
  lua_pushstring(L, "kw_while");
  lua_rawseti(L, -2, QAMAR_TOKEN_WHILE);
  lua_pushstring(L, "comment");
  lua_rawseti(L, -2, QAMAR_TOKEN_COMMENT);
  lua_pushstring(L, "name");
  lua_rawseti(L, -2, QAMAR_TOKEN_NAME);
  lua_pushstring(L, "string");
  lua_rawseti(L, -2, QAMAR_TOKEN_STRING);
  lua_pushstring(L, "number");
  lua_rawseti(L, -2, QAMAR_TOKEN_NUMBER);
  lua_pushstring(L, "plus");
  lua_rawseti(L, -2, QAMAR_TOKEN_PLUS);
  lua_pushstring(L, "dash");
  lua_rawseti(L, -2, QAMAR_TOKEN_DASH);
  lua_pushstring(L, "asterisk");
  lua_rawseti(L, -2, QAMAR_TOKEN_ASTERISK);
  lua_pushstring(L, "slash");
  lua_rawseti(L, -2, QAMAR_TOKEN_SLASH);
  lua_pushstring(L, "percent");
  lua_rawseti(L, -2, QAMAR_TOKEN_PERCENT);
  lua_pushstring(L, "caret");
  lua_rawseti(L, -2, QAMAR_TOKEN_CARET);
  lua_pushstring(L, "hash");
  lua_rawseti(L, -2, QAMAR_TOKEN_HASH);
  lua_pushstring(L, "ampersand");
  lua_rawseti(L, -2, QAMAR_TOKEN_AMPERSAND);
  lua_pushstring(L, "tilde");
  lua_rawseti(L, -2, QAMAR_TOKEN_TILDE);
  lua_pushstring(L, "pipe");
  lua_rawseti(L, -2, QAMAR_TOKEN_PIPE);
  lua_pushstring(L, "lshift");
  lua_rawseti(L, -2, QAMAR_TOKEN_LSHIFT);
  lua_pushstring(L, "rshift");
  lua_rawseti(L, -2, QAMAR_TOKEN_RSHIFT);
  lua_pushstring(L, "doubleslash");
  lua_rawseti(L, -2, QAMAR_TOKEN_DOUBLESLASH);
  lua_pushstring(L, "equal");
  lua_rawseti(L, -2, QAMAR_TOKEN_EQUAL);
  lua_pushstring(L, "notequal");
  lua_rawseti(L, -2, QAMAR_TOKEN_NOTEQUAL);
  lua_pushstring(L, "lessequal");
  lua_rawseti(L, -2, QAMAR_TOKEN_LESSEQUAL);
  lua_pushstring(L, "greaterequal");
  lua_rawseti(L, -2, QAMAR_TOKEN_GREATEREQUAL);
  lua_pushstring(L, "less");
  lua_rawseti(L, -2, QAMAR_TOKEN_LESS);
  lua_pushstring(L, "greater");
  lua_rawseti(L, -2, QAMAR_TOKEN_GREATER);
  lua_pushstring(L, "assignment");
  lua_rawseti(L, -2, QAMAR_TOKEN_ASSIGNMENT);
  lua_pushstring(L, "lparen");
  lua_rawseti(L, -2, QAMAR_TOKEN_LPAREN);
  lua_pushstring(L, "rparen");
  lua_rawseti(L, -2, QAMAR_TOKEN_RPAREN);
  lua_pushstring(L, "lbrace");
  lua_rawseti(L, -2, QAMAR_TOKEN_LBRACE);
  lua_pushstring(L, "rbrace");
  lua_rawseti(L, -2, QAMAR_TOKEN_RBRACE);
  lua_pushstring(L, "lbracket");
  lua_rawseti(L, -2, QAMAR_TOKEN_LBRACKET);
  lua_pushstring(L, "rbracket");
  lua_rawseti(L, -2, QAMAR_TOKEN_RBRACKET);
  lua_pushstring(L, "doublecolon");
  lua_rawseti(L, -2, QAMAR_TOKEN_DOUBLECOLON);
  lua_pushstring(L, "semicolon");
  lua_rawseti(L, -2, QAMAR_TOKEN_SEMICOLON);
  lua_pushstring(L, "colon");
  lua_rawseti(L, -2, QAMAR_TOKEN_COLON);
  lua_pushstring(L, "comma");
  lua_rawseti(L, -2, QAMAR_TOKEN_COMMA);
  lua_pushstring(L, "dot");
  lua_rawseti(L, -2, QAMAR_TOKEN_DOT);
  lua_pushstring(L, "doubledot");
  lua_rawseti(L, -2, QAMAR_TOKEN_DOUBLEDOT);
  lua_pushstring(L, "tripledot");
  lua_rawseti(L, -2, QAMAR_TOKEN_TRIPLEDOT);
}

extern bool lexer_keyword(qamar_lexer_t *s, qamar_token_t *out) {
  lexer_skipws(s);
  out->pos.left = lexer_pos(s);
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
    out->len = 3;
    out->type = QAMAR_TOKEN_AND;
    goto success;
  case 'b':
    if (--amt == 0 || *++p != 'r' || --amt == 0 || *++p != 'e' || --amt == 0 ||
        *++p != 'a' || --amt == 0 || *++p != 'k' ||
        (--amt > 0 && is_alphanum(*++p)))
      return false;
    out->len = 5;
    out->type = QAMAR_TOKEN_BREAK;
    goto success;
  case 'd':
    if (--amt == 0 || *++p != 'o' || (--amt > 0 && is_alphanum(*++p)))
      return false;
    out->len = 2;
    out->type = QAMAR_TOKEN_DO;
    goto success;
  case 'e':
    if (--amt == 0)
      return false;
    switch (*++p) {
    case 'l':
      if (--amt == 0 || *++p != 's' || --amt == 0 || *++p != 'e')
        return false;
      if (--amt > 0 && !is_alphanum(*++p)) {
        out->len = 4;
        out->type = QAMAR_TOKEN_ELSE;
        goto success;
      } else if (*p != 'i' || --amt == 0 || *++p != 'f' ||
                 (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 6;
      out->type = QAMAR_TOKEN_ELSEIF;
      goto success;
    case 'n':
      if (--amt == 0 || *++p != 'd' || (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 3;
      out->type = QAMAR_TOKEN_END;
      goto success;
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
      out->type = QAMAR_TOKEN_FALSE;
      goto success;
    case 'o':
      if (--amt == 0 || *++p != 'r' || (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 3;
      out->type = QAMAR_TOKEN_FOR;
      goto success;
    case 'u':
      if (--amt == 0 || *++p != 'n' || --amt == 0 || *++p != 'c' ||
          --amt == 0 || *++p != 't' || --amt == 0 || *++p != 'i' ||
          --amt == 0 || *++p != 'o' || --amt == 0 || *++p != 'n' ||
          (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 8;
      out->type = QAMAR_TOKEN_FUNCTION;
      goto success;
    }
    break;
  case 'g':
    if (--amt == 0 || *++p != 'o' || --amt == 0 || *++p != 't' || --amt == 0 ||
        *++p != 'o' || (--amt > 0 && is_alphanum(*++p)))
      return false;
    out->len = 4;
    out->type = QAMAR_TOKEN_GOTO;
    goto success;
  case 'i':
    if (--amt == 0)
      return false;
    switch (*++p) {
    case 'f':
      if (--amt > 0 && is_alphanum(*++p))
        return false;
      out->len = 2;
      out->type = QAMAR_TOKEN_IF;
      goto success;
    case 'n':
      if (--amt > 0 && is_alphanum(*++p))
        return false;
      out->len = 2;
      out->type = QAMAR_TOKEN_IN;
      goto success;
    }
    break;
  case 'l':
    if (--amt == 0 || *++p != 'o' || --amt == 0 || *++p != 'c' || --amt == 0 ||
        *++p != 'a' || --amt == 0 || *++p != 'l' ||
        (--amt > 0 && is_alphanum(*++p)))
      return false;
    out->len = 5;
    out->type = QAMAR_TOKEN_LOCAL;
    goto success;
  case 'n':
    if (--amt == 0)
      return false;
    switch (*++p) {
    case 'i':
      if (--amt == 0 || *++p != 'l' || (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 3;
      out->type = QAMAR_TOKEN_NIL;
      goto success;
    case 'o':
      if (--amt == 0 || *++p != 't' || (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 3;
      out->type = QAMAR_TOKEN_NOT;
      goto success;
    }
    break;
  case 'o':
    if (--amt == 0 || *++p != 'r' || (--amt > 0 && is_alphanum(*++p)))
      return false;
    out->len = 2;
    out->type = QAMAR_TOKEN_OR;
    goto success;
  case 'r':
    if (--amt == 0 || *++p != 'e' || --amt == 0)
      return false;
    switch (*++p) {
    case 'p':
      if (--amt == 0 || *++p != 'e' || --amt == 0 || *++p != 'a' ||
          --amt == 0 || *++p != 't' || (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 6;
      out->type = QAMAR_TOKEN_REPEAT;
      goto success;
    case 't':
      if (--amt == 0 || *++p != 'u' || --amt == 0 || *++p != 'r' ||
          --amt == 0 || *++p != 'n' || (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 6;
      out->type = QAMAR_TOKEN_RETURN;
      goto success;
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
      out->type = QAMAR_TOKEN_THEN;
      goto success;
    case 'r':
      if (--amt == 0 || *++p != 'u' || --amt == 0 || *++p != 'e' ||
          (--amt > 0 && is_alphanum(*++p)))
        return false;
      out->len = 4;
      out->type = QAMAR_TOKEN_TRUE;
      goto success;
    }
    break;
  case 'u':
    if (--amt == 0 || *++p != 'n' || --amt == 0 || *++p != 't' || --amt == 0 ||
        *++p != 'i' || --amt == 0 || *++p != 'l' ||
        (--amt > 0 && is_alphanum(*++p)))
      return false;
    out->len = 5;
    out->type = QAMAR_TOKEN_UNTIL;
    goto success;
  case 'w':
    if (--amt == 0 || *++p != 'h' || --amt == 0 || *++p != 'i' || --amt == 0 ||
        *++p != 'l' || --amt == 0 || *++p != 'e' ||
        (--amt > 0 && is_alphanum(*++p)))
      return false;
    out->len = 5;
    out->type = QAMAR_TOKEN_WHILE;
    goto success;
  case '#':
    out->len = 1;
    out->type = QAMAR_TOKEN_HASH;
    goto success;
  case '%':
    out->len = 1;
    out->type = QAMAR_TOKEN_PERCENT;
    goto success;
  case '&':
    out->len = 1;
    out->type = QAMAR_TOKEN_AMPERSAND;
    goto success;
  case '(':
    out->len = 1;
    out->type = QAMAR_TOKEN_LPAREN;
    goto success;
  case ')':
    out->len = 1;
    out->type = QAMAR_TOKEN_RPAREN;
    goto success;
  case '*':
    out->len = 1;
    out->type = QAMAR_TOKEN_ASTERISK;
    goto success;
  case '+':
    out->len = 1;
    out->type = QAMAR_TOKEN_PLUS;
    goto success;
  case ',':
    out->len = 1;
    out->type = QAMAR_TOKEN_COMMA;
    goto success;
  case '-':
    out->len = 1;
    out->type = QAMAR_TOKEN_DASH;
    goto success;
  case '[': {
    int32_t len = qamar_find_open_long_string_terminator(p, amt);
    if (len >= 0)
      return !qamar_match_long_string(s, p, amt, len, out);
    out->len = 1;
    out->type = QAMAR_TOKEN_LBRACKET;
    goto success;
  }
  case ']':
    out->len = 1;
    out->type = QAMAR_TOKEN_RBRACKET;
    goto success;
  case '^':
    out->len = 1;
    out->type = QAMAR_TOKEN_CARET;
    goto success;
  case '{':
    out->len = 1;
    out->type = QAMAR_TOKEN_LBRACE;
    goto success;
  case '|':
    out->len = 1;
    out->type = QAMAR_TOKEN_PIPE;
    goto success;
  case '}':
    out->len = 1;
    out->type = QAMAR_TOKEN_RBRACE;
    goto success;
  case ';':
    out->len = 1;
    out->type = QAMAR_TOKEN_SEMICOLON;
    goto success;
  case '/':
    if (--amt == 0 || *++p != '/') {
      out->len = 1;
      out->type = QAMAR_TOKEN_SLASH;
    } else {
      out->len = 2;
      out->type = QAMAR_TOKEN_DOUBLESLASH;
    }
    goto success;
  case ':':
    if (--amt == 0 || *++p != ':') {
      out->len = 1;
      out->type = QAMAR_TOKEN_COLON;
    } else {
      out->len = 2;
      out->type = QAMAR_TOKEN_DOUBLECOLON;
    }
    goto success;
  case '=':
    if (--amt == 0 || *++p != '=') {
      out->len = 1;
      out->type = QAMAR_TOKEN_ASSIGNMENT;
    } else {
      out->len = 2;
      out->type = QAMAR_TOKEN_EQUAL;
    }
    goto success;
  case '~':
    if (--amt == 0 || *++p != '=') {
      out->len = 1;
      out->type = QAMAR_TOKEN_TILDE;
    } else {
      out->len = 2;
      out->type = QAMAR_TOKEN_NOTEQUAL;
    }
    goto success;
  case '.':
    if (--amt == 0 || *++p != '.') {
      out->len = 1;
      out->type = QAMAR_TOKEN_DOT;
    } else if (--amt == 0 || *++p != '.') {
      out->len = 2;
      out->type = QAMAR_TOKEN_DOUBLEDOT;
    } else {
      out->len = 3;
      out->type = QAMAR_TOKEN_TRIPLEDOT;
    }
    goto success;
  case '<':
    if (--amt == 0) {
      out->len = 1;
      out->type = QAMAR_TOKEN_LESS;
      goto success;
    }
    switch (*++p) {
    case '=':
      out->len = 2;
      out->type = QAMAR_TOKEN_LESSEQUAL;
      goto success;
    case '<':
      out->len = 2;
      out->type = QAMAR_TOKEN_LSHIFT;
      goto success;
    default:
      out->len = 1;
      out->type = QAMAR_TOKEN_LESS;
      goto success;
    }
  case '>':
    if (--amt == 0) {
      out->len = 1;
      out->type = QAMAR_TOKEN_GREATER;
      goto success;
    }
    switch (*++p) {
    case '=':
      out->len = 2;
      out->type = QAMAR_TOKEN_GREATEREQUAL;
      goto success;
    case '>':
      out->len = 2;
      out->type = QAMAR_TOKEN_RSHIFT;
      goto success;
    default:
      out->len = 1;
      out->type = QAMAR_TOKEN_GREATER;
      goto success;
    }
  }
  return false;
success:
  out->value = lexer_take(s, &out->len);
  out->pos.right = lexer_pos(s);
  return true;
}

static int lua_lexer_keyword(lua_State *L) {
  qamar_lexer_t *s;
  if (lua_gettop(L) < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_LEXER)) == 0 ||
      s->t.index >= s->len)
    return 0;
  qamar_token_t token;
  if (!lexer_keyword(s, &token))
    return 0;
  lua_qamar_create_token(L, &token);
  return 1;
}

extern bool lexer_name(qamar_lexer_t *s, qamar_token_t *out) {
  lexer_skipws(s);
  out->pos.left = lexer_pos(s);
  out->value = lexer_alpha(s);
  if (out->value == NULL)
    return false;
  out->len = 1;
  out->type = QAMAR_TOKEN_NAME;
  while (lexer_alphanumeric(s))
    ++out->len;
  out->pos.right = lexer_pos(s);
  return true;
}

static int lua_lexer_name(lua_State *L) {
  qamar_lexer_t *s;
  if (lua_gettop(L) < 1 || (s = luaL_checkudata(L, 1, QAMAR_TYPE_LEXER)) == 0 ||
      s->t.index >= s->len)
    return 0;
  qamar_token_t token;
  if (!lexer_name(s, &token))
    return 0;
  lua_qamar_create_token(L, &token);
  return 1;
}

const luaL_Reg library[] = {
    {"new", lua_lexer_new},
    {"peek", lua_lexer_peek},
    {"take", lua_lexer_take},
    {"begin", lua_lexer_begin},
    {"undo", lua_lexer_undo},
    {"commit", lua_lexer_commit},
    {"pos", lua_lexer_pos},
    {"try_consume_string", lua_lexer_try_consume_string},
    {"skipws", lua_lexer_skipws},
    {"suspend_skip_ws", lua_lexer_suspend_skip_ws},
    {"resume_skip_ws", lua_lexer_resume_skip_ws},
    {"alpha", lua_lexer_alpha},
    {"numeric", lua_lexer_numeric},
    {"alphanumeric", lua_lexer_alphanumeric},
    {"keyword", lua_lexer_keyword},
    {"name", lua_lexer_name},
    {NULL, NULL}};

int qamar_lexer_init(lua_State *L) {
  if (lexer_string_init())
    return true;
  luaL_newmetatable(L, QAMAR_TYPE_LEXER);

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
  lua_pushcfunction(L, lua_lexer_tostring);
  lua_rawset(L, -3);
  lua_pushstring(L, "__gc");
  lua_pushcfunction(L, lua_lexer_destroy);
  lua_rawset(L, -3);
  lua_pop(L, 1);

  luaL_register(L, "qamar_lexer", library);
  lua_pushstring(L, "types");
  lua_create_token_type_table(L);
  lua_rawset(L, -3);
  lua_pop(L, 1);

  return false;
}
