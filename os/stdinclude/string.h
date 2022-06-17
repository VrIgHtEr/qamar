#ifndef __QAMAR_STRING__
#define __QAMAR_STRING__

#include <stddef.h>
#include <stdint.h>

inline void *memcpy(void *dest, const void *src, size_t size);

inline void *memset(void *dest, int val, size_t size);

inline int memcmp(const void *ptr1, const void *ptr2, size_t size);

#endif
