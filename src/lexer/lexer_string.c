#include "lexer_string.h"
#include "lexer.h"
#include "token_types.h"
#include <stdint.h>
#include <stdio.h>
#include <stdlib.h>

static size_t capacity;
static char *buf = NULL;
static size_t stringlength;

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
  if (amt < len + 2 || *p != ']') {
    return false;
  }
  for (; len > 0; --len)
    if (*++p != '=')
      return false;
  if (*++p != ']')
    return false;
  return true;
}

static void insert_char(const char x) {

  if (stringlength == capacity) {
    capacity *= 2;
    char *newbuf = realloc(buf, capacity);
    if (newbuf == NULL)
      exit(1);
    buf = newbuf;
  }
  buf[stringlength++] = x;
}

bool qamar_match_long_string(qamar_lexer_t *s, const char *p, size_t amt,
                             int32_t term_len, qamar_token_t *token) {
  if (amt < term_len * 2 + 4)
    return true;
  token->pos.left = lexer_pos(s);
  size_t ilen = term_len + 2;
  amt -= ilen;
  p += ilen;
  stringlength = 0;
  --amt;
  bool first = true;
  while (true) {
    if (amt == 0) {
      return true;
    }
    if (qamar_match_long_string_close_terminator(p, amt + 1, term_len)) {
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
      insert_char(*p);
    ++p;
    --amt;
    ++ilen;
    first = false;
  }
}

bool qamar_match_string(qamar_lexer_t *s, const char *p, size_t amt,
                        qamar_token_t *token) {
  if (amt == 0)
    return true;
  char delimiter = *p;
  if (delimiter != '\'' && delimiter != '"')
    return true;
  token->type = QAMAR_TOKEN_STRING;
  token->pos.left = lexer_pos(s);
  size_t ilen = 1;
  stringlength = 0;
  while (true) {
    --amt;
    ++p;
    ++ilen;
    if (amt == 0)
      return true;
    char x = *p;
    if (x == delimiter) {
      lexer_take(s, &ilen);
      token->value = buf;
      token->len = stringlength;
      token->pos.right = lexer_pos(s);
      return false;
    }
    switch (x) {
    case '\r':
    case '\n':
      return true;
    case '\\':
      if (--amt == 0)
        return true;
      ++ilen;
      char x = *++p;
      switch (x) {
      case 'z':
        while (true) {
          if (--amt == 0)
            return true;
          char x = *++p;
          ++ilen;
          if (x != ' ' && x != '\t' && x != '\r' && x != '\n' && x != '\v' &&
              x != '\f') {
            --p, ++amt, --ilen;
            break;
          }
        }
        break;
      case 'x':
        if (--amt == 0)
          return true;
        char c1 = *++p;
        ++ilen;
        if (--amt == 0)
          return true;
        char c2 = *++p;
        ++ilen;
        char c;
        if (c1 >= '0' && c1 <= '9')
          c = c1 - '0';
        else if (c1 >= 'a' && c1 <= 'f')
          c = c1 - 'a' + 10;
        else if (c1 >= 'A' && c1 <= 'F')
          c = c1 - 'A' + 10;
        else
          return true;
        c <<= 4;
        if (c2 >= '0' && c2 <= '9')
          c |= c2 - '0';
        else if (c2 >= 'a' && c2 <= 'f')
          c |= c2 - 'a' + 10;
        else if (c2 >= 'A' && c2 <= 'F')
          c |= c2 - 'A' + 10;
        else
          return true;
        insert_char(c);
        break;
      case '0':
      case '1':
      case '2':
      case '3':
      case '4':
      case '5':
      case '6':
      case '7':
      case '8':
      case '9': {
        int32_t c = x - '0';
        if (--amt == 0) {
          ++amt;
          goto finish;
        }
        x = *++p;
        ++ilen;
        if (x < '0' || x > '9') {
          --ilen;
          --p;
          ++amt;
          goto finish;
        }
        c = c * 10 + (x - '0');
        if (--amt == 0) {
          ++amt;
          goto finish;
        }
        x = *++p;
        ++ilen;
        if (x < '0' || x > '9') {
          --ilen;
          --p;
          ++amt;
          goto finish;
        }
        c = c * 10 + (x - '0');
      finish:
        if (c > 255)
          return true;
        insert_char((char)c);
        break;
      case 'u':
        if (--amt == 0)
          return true;
        ++p, ++ilen;
        if (*p != '{')
          return true;
        uint32_t val = 0;
        int x = 8;
        while (true) {
          if (--amt == 0)
            return true;
          ++ilen, ++p;
          if (*p == '}') {
            if (x == 8)
              return true;
            break;
          }
          if (x == 0)
            return true;
          --x;
          val <<= 4;
          if (*p >= '0' && *p <= '9')
            val |= *p - '0';
          else if (*p >= 'A' && *p <= 'F')
            val |= *p - ('A' - 10);
          else if (*p >= 'a' && *p <= 'f')
            val |= *p - ('a' - 10);
          else
            return true;
        }
        if (val <= 0177)
          insert_char(val);
        else if (val <= 03777) {
          insert_char(0300 | (val >> 6));
          insert_char(0200 | (val & 077));
        } else if (val <= 0177777) {
          insert_char(0340 | (val >> 12));
          insert_char(0200 | ((val >> 6) & 077));
          insert_char(0200 | (val & 077));
        } else if (val <= 07777777) {
          insert_char(0360 | (val >> 18));
          insert_char(0200 | ((val >> 12) & 077));
          insert_char(0200 | ((val >> 6) & 077));
          insert_char(0200 | (val & 077));
        } else if (val <= 0x0377777777) {
          insert_char(0370 | (val >> 24));
          insert_char(0200 | ((val >> 18) & 077));
          insert_char(0200 | ((val >> 12) & 077));
          insert_char(0200 | ((val >> 6) & 077));
          insert_char(0200 | (val & 077));
        } else if (val <= 0x017777777777) {
          insert_char(0374 | (val >> 30));
          insert_char(0200 | ((val >> 24) & 077));
          insert_char(0200 | ((val >> 18) & 077));
          insert_char(0200 | ((val >> 12) & 077));
          insert_char(0200 | ((val >> 6) & 077));
          insert_char(0200 | (val & 077));
        } else
          return true;
      }
      case 'a':
        insert_char('\a');
        break;
      case 'b':
        insert_char('\b');
        break;
      case 'f':
        insert_char('\f');
        break;
      case 'n':
        insert_char('\n');
        break;
      case 'r':
        insert_char('\r');
        break;
      case 't':
        insert_char('\t');
        break;
      case 'v':
        insert_char('\v');
        break;
      case '\\':
        insert_char('\\');
        break;
      case '\'':
        insert_char('\'');
        break;
      case '"':
        insert_char('"');
        break;
      case '\n':
        insert_char('\n');
        break;
      default:
        return true;
      }
    default:
      insert_char(*p);
    }
  }
}
