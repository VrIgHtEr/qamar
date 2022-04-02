#include "queue_ts.h"
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>
#include <string.h>

typedef struct {
  pthread_mutex_t lock;
  bool initialized;
  void *buffer;
  size_t capacity;
  size_t item_size;
  size_t head;
  size_t tail;
  size_t size;
  bool parity;
} queue;

static queue *buffer;
static size_t bufsize;
static size_t bufcapacity;

static size_t *freelist;
static size_t freelistsize;
static size_t freelistptr;

static pthread_mutexattr_t mutexattr;

static bool initialize(void) {
  static bool initialized = false;
  if (initialized)
    return false;

  buffer = malloc(sizeof(queue));
  if (buffer) {
    memset(buffer, 0, sizeof(queue));
    freelist = malloc(sizeof(size_t));
    if (!freelist) {
      free(buffer);
      return true;
    }
    freelistsize = 1;
    freelistptr = 1;
    *freelist = 0;
    bufcapacity = 1;
    initialized = true;
    return false;
  }
  pthread_mutexattr_init(&mutexattr);
  pthread_mutexattr_settype(&mutexattr, PTHREAD_MUTEX_RECURSIVE);
  return true;
}

static bool queue_is_full(queue *q) { return q->head == q->tail && q->parity; }
static bool queue_is_empty(queue *q) {
  return q->head == q->tail && !q->parity;
}
static bool queue_grow(queue *q) {
  const size_t nc = q->capacity * 2;
  void *const b = realloc(q->buffer, nc * q->item_size);
  if (b == 0)
    return true;
  q->buffer = b;
  const size_t hb = q->capacity * q->item_size;
  q->capacity = nc;

  if (q->parity) {
    size_t len = (q->capacity - q->tail) * q->item_size;
    memcpy(b + hb, b + q->tail * q->item_size, len);
    memcpy(b + hb + len, b, q->head * q->item_size);
  } else
    memcpy(b + hb, b + q->tail * q->item_size,
           (q->head - q->tail) * q->item_size);
  memcpy(b, b + hb, hb);
  q->tail = 0;
  q->head = q->size;
  q->parity = false;

  free(q->buffer);
  return false;
}

static bool queue_push_front(queue *q, const void *item) {
  if (queue_is_full(q))
    if (queue_grow(q))
      return true;
  if (q->tail == 0) {
    q->tail = q->capacity - 1;
    q->parity ^= true;
  } else {
    --q->tail;
  }
  memcpy(q->buffer + q->item_size * q->tail, item, q->item_size);
  return false;
}

static bool queue_pop_back(queue *q, void *item) {
  if (queue_is_empty(q))
    return true;
  if (q->head == 0) {
    q->head = q->capacity - 1;
    q->parity ^= true;
  } else {
    --q->head;
  }
  memcpy(item, q->buffer + q->item_size * q->head, q->item_size);
  return false;
}

static bool queue_push_back(queue *q, const void *item) {
  if (queue_is_full(q))
    if (queue_grow(q))
      return true;
  memcpy(q->buffer + q->item_size * q->head, item, q->item_size);
  ++q->head;
  if (q->head == q->capacity) {
    q->head = 0;
    q->parity ^= true;
  }
  return false;
}

static bool queue_pop_front(queue *q, void *item) {
  if (queue_is_empty(q))
    return true;
  memcpy(item, q->buffer + q->item_size * q->tail, q->item_size);
  ++q->tail;
  if (q->tail == q->capacity) {
    q->tail = 0;
    q->parity ^= true;
  }
  return false;
}

static bool queue_init(queue *q, size_t item_size) {
  q->initialized = false;
  if (!item_size)
    return true;
  int ret = pthread_mutex_init(&q->lock, &mutexattr);
  if (ret)
    return true;
  q->capacity = 1;
  q->item_size = item_size;
  q->buffer = malloc(item_size * q->capacity);
  if (!q->buffer)
    goto fail;
  q->size = 0;
  q->head = 0;
  q->tail = 0;
  q->parity = false;
  q->initialized = true;
  return false;
fail:
  pthread_mutex_destroy(&q->lock);
  return true;
}

static bool queue_destroy(queue *q) {
  if (!q->initialized)
    return true;
  if (pthread_mutex_destroy(&q->lock))
    return true;
  free(q->buffer);
  q->buffer = 0;
  q->initialized = false;
  return false;
}

bool queue_ts_new(size_t item_size, queue_ts *queue) {
  if (initialize() || !item_size)
    return true;
  size_t offset;
  if (bufsize < bufcapacity) {
    offset = bufsize;
  } else if (freelistptr > 0) {
    --freelistptr;
    offset = (size_t)freelist[freelistptr];
  } else {
    size_t newsize = bufcapacity + 1;
    void *newptr = realloc(buffer, sizeof(queue) * newsize);
    if (!newptr)
      return true;
    buffer = newptr;
    bufcapacity = newsize;
    offset = bufcapacity - 1;
  }

  void *item = &buffer[offset];

  if (queue_init(item, item_size)) {
    if (freelistptr == freelistsize) {
      size_t newsize = freelistsize * 2;
      void *newptr = realloc(freelist, sizeof(size_t) * newsize);
      if (!newptr)
        return true;
      freelist = newptr;
      freelistsize = newsize;
    }
    freelist[freelistptr] = offset;
    return true;
  }

  *queue = (void *)(offset + 1);
  return false;
}

bool queue_ts_destroy(queue_ts q) {
  if (initialize() || !q || (size_t)q > bufcapacity)
    return true;
  size_t offset = (size_t)(q - 1);
  queue *p = &buffer[offset];
  if (!p->initialized)
    return true;
  if (freelistptr == freelistsize) {
    size_t newsize = freelistsize * 2;
    void *newptr = realloc(freelist, sizeof(size_t) * newsize);
    if (!newptr)
      return true;
    freelist = newptr;
    freelistsize = newsize;
  }
  if (queue_destroy(p))
    return true;
  freelist[freelistptr] = offset;
  ++freelistptr;
  return false;
}

bool queue_ts_push_back(queue_ts q, const void *item) {
  if (initialize() || !q || !item || (size_t)q > bufcapacity)
    return true;
  queue *p = &buffer[(size_t)(q - 1)];
  if (!p->initialized)
    return true;
  return queue_push_back(p, item);
}
bool queue_ts_pop_front(queue_ts q, void *item) {
  if (initialize() || !q || !item || (size_t)q > bufcapacity)
    return true;
  queue *p = &buffer[(size_t)(q - 1)];
  if (!p->initialized)
    return true;
  return queue_pop_front(p, item);
}
bool queue_ts_push_front(queue_ts q, const void *item) {
  if (initialize() || !q || !item || (size_t)q > bufcapacity)
    return true;
  queue *p = &buffer[(size_t)(q - 1)];
  if (!p->initialized)
    return true;
  return queue_push_front(p, item);
}
bool queue_ts_pop_back(queue_ts q, void *item) {
  if (initialize() || !q || !item || (size_t)q > bufcapacity)
    return true;
  queue *p = &buffer[(size_t)(q - 1)];
  if (!p->initialized)
    return true;
  return queue_pop_back(p, item);
}
