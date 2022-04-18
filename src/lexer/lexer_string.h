#ifndef __QAMAR_LEXER_STRING__
#define __QAMAR_LEXER_STRING__

#include "lexer.h"
#include <stdint.h>

bool lexer_string_init();
int32_t qamar_find_open_long_string_terminator(const char *, size_t);
bool qamar_match_long_string(qamar_lexer_t *, const char *, size_t, int32_t,
                             qamar_token_t *);
bool qamar_match_string(qamar_lexer_t *, const char *, size_t, qamar_token_t *);

#endif
