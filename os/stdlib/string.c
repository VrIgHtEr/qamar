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
