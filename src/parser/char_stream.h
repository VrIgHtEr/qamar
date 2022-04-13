#ifndef __QAMAR_PARSER_CHAR_STREAM__
#define __QAMAR_PARSER_CHAR_STREAM__

#include "lua.h"
#include <stdbool.h>

extern const char *QAMAR_TYPE_CHAR_STREAM;

typedef struct {
  size_t file_char;
  size_t row;
  size_t col;
  size_t byte;
  size_t file_byte;
} qamar_position_t;

typedef struct {
  qamar_position_t left;
  qamar_position_t right;
} qamar_range_t;

typedef struct {
  int type;
  qamar_range_t pos;
  const char *value;
  size_t len;
} qamar_token_t;

typedef struct {
  size_t index;
  size_t file_char;
  size_t row;
  size_t col;
  size_t byte;
  size_t file_byte;
} char_stream_transaction_t;

typedef struct {
  size_t skip_ws_ctr;
  size_t len;
  char_stream_transaction_t *transactions;
  size_t transactions_capacity;
  size_t transactions_index;
  char_stream_transaction_t t;
  const char data[];
} char_stream_t;

int qamar_char_stream_init(lua_State *);

int char_stream_new(char_stream_t *c, const char *, const size_t);
const char *char_stream_peek(char_stream_t *, size_t);
const char *char_stream_take(char_stream_t *, size_t *);
void char_stream_begin(char_stream_t *);
void char_stream_undo(char_stream_t *);
void char_stream_commit(char_stream_t *);
qamar_position_t char_stream_pos(char_stream_t *);
const char *char_stream_try_consume_string(char_stream_t *, const char *,
                                           size_t);
void char_stream_skipws(char_stream_t *);
void char_stream_suspend_skip_ws(char_stream_t *);
void char_stream_resume_skip_ws(char_stream_t *);
const char *char_stream_alpha(char_stream_t *);
const char *char_stream_numeric(char_stream_t *);
const char *char_stream_alphanumeric(char_stream_t *);
bool char_stream_keyword(char_stream_t *, qamar_token_t *);

#endif
