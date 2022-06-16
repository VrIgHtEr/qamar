#include <stddef.h>
#include <stdint.h>
#include <string.h>

void *memcpy(void *dest, const void *src, size_t size) {
  uint8_t *pdest = (uint8_t *)dest, *psrc = (uint8_t *)src;
  for (size_t loops = (size / sizeof(uint32_t)); loops;
       --loops, pdest += sizeof(uint32_t), psrc += sizeof(uint32_t))
    *((uint32_t *)pdest) = *((uint32_t *)psrc);
  for (size_t loops = (size % sizeof(uint32_t)); loops; --loops)
    *(pdest++) = *(psrc++);
  return dest;
}

void *memset(void *dest, int32_t val, size_t size) {
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
