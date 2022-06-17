#include "string.h"
#include <stddef.h>
#include <stdint.h>

void *memcpy(void *dest, const void *src, size_t size) {
  uint8_t *pdest = (uint8_t *)dest, *psrc = (uint8_t *)src;
  for (size_t loops = (size / sizeof(uint32_t)); loops;
       --loops, pdest += sizeof(uint32_t), psrc += sizeof(uint32_t))
    *((uint32_t *)pdest) = *((uint32_t *)psrc);
  for (size_t loops = (size % sizeof(uint32_t)); loops; --loops)
    *(pdest++) = *(psrc++);
  return dest;
}

void *memset(void *dest, int val, size_t size) {
  uint8_t *pdest = (uint8_t *)dest;
  if (size >= 4) {
    val = val & 0xFF;
    val = val | (val << 8);
    val = val | (val << 16);
    for (size_t loops = (size / sizeof(uint32_t)); loops;
         --loops, pdest += sizeof(uint32_t))
      *((uint32_t *)pdest) = val;
  }
  for (size_t loops = (size % sizeof(uint32_t)); loops; --loops)
    *(pdest++) = (uint8_t)val;
  return dest;
}

int memcmp(const void *ptr1, const void *ptr2, size_t size) {
  uint8_t *p1 = (uint8_t *)ptr1, *p2 = (uint8_t *)ptr2;
  for (; size; --size, ++p1, ++p2)
    if (*p1 < *p2)
      return -1;
    else if (*p1 > *p2)
      return 1;
  return 0;
}
