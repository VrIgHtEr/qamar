#ifndef __QAMAR_LEXER__
#define __QAMAR_LEXER__

#include "lua.h"
#include <stdbool.h>

extern const char *QAMAR_TYPE_LEXER;

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
} qamar_lexer_transaction_t;

typedef struct {
  size_t skip_ws_ctr;
  size_t len;
  qamar_lexer_transaction_t *transactions;
  size_t transactions_capacity;
  size_t transactions_index;
  qamar_lexer_transaction_t t;
  const char data[];
} qamar_lexer_t;

int qamar_lexer_init(lua_State *);

int lexer_new(qamar_lexer_t *c, const char *, const size_t);
const char *lexer_peek(qamar_lexer_t *, size_t);
const char *lexer_take(qamar_lexer_t *, size_t *);
void lexer_begin(qamar_lexer_t *);
void lexer_undo(qamar_lexer_t *);
void lexer_commit(qamar_lexer_t *);
qamar_position_t lexer_pos(qamar_lexer_t *);
const char *lexer_try_consume_string(qamar_lexer_t *, const char *, size_t);
void lexer_skipws(qamar_lexer_t *);
void lexer_suspend_skip_ws(qamar_lexer_t *);
void lexer_resume_skip_ws(qamar_lexer_t *);
const char *lexer_alpha(qamar_lexer_t *);
const char *lexer_numeric(qamar_lexer_t *);
const char *lexer_alphanumeric(qamar_lexer_t *);
bool lexer_keyword(qamar_lexer_t *, qamar_token_t *);

#endif
