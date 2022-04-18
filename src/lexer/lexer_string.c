#include "lexer_string.h"
#include "lexer.h"
#include "token_types.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static size_t capacity;
static char *buf = NULL;

bool lexer_string_init() {
  capacity = 1;
  buf = malloc(capacity);
  return buf == NULL;
}

int32_t qamar_find_open_long_string_terminator(const char *p, size_t amt) {
  if (amt == 0)
    return -1;
  if (*p != '[')
    return -1;
  int32_t counter = 0;
  while (true) {
    if (--amt == 0)
      return -1;
    char c = *++p;
    if (c != '=')
      return c == '[' ? counter : -1;
    ++counter;
  }
}

bool qamar_match_long_string_close_terminator(const char *p, size_t amt,
                                              int32_t len) {
  if (amt < len + 2 || *p != ']')
    return false;
  for (; len > 0; --len)
    if (*++p != '=')
      return false;
  if (*++p != ']')
    return false;
  return true;
}

bool qamar_match_long_string(qamar_lexer_t *s, const char *p, size_t amt,
                             int32_t term_len, qamar_token_t *token) {
  if (amt < term_len * 2 + 4)
    return true;
  token->pos.left = lexer_pos(s);
  size_t ilen = term_len + 2;
  amt -= ilen;
  p += term_len + 2;
  size_t stringlength = 0;
  --amt;
  bool first = true;
  while (true) {
    if (amt == 0)
      return true;
    if (qamar_match_long_string_close_terminator(p, amt, term_len)) {
      ilen += term_len + 2;
      lexer_take(s, &ilen);
      token->pos.right = lexer_pos(s);
      token->len = stringlength;
      token->value = buf;
      token->type = QAMAR_TOKEN_STRING;
      return false;
    }
    if (stringlength == capacity) {
      capacity *= 2;
      char *newbuf = realloc(buf, capacity);
      if (newbuf == NULL)
        exit(1);
      buf = newbuf;
    }
    if (!first || *p != '\n')
      buf[stringlength++] = *p;
    ++p;
    --amt;
    ++ilen;
    first = false;
  }
}
