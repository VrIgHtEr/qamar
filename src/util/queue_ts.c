#include "queue_ts.h"
#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>
#include <stdlib.h>

typedef struct {
  pthread_mutex_t lock;
  bool initialized;
} queue;

static queue *buffer;
static size_t bufsize;

static queue_ts *freelist;
static size_t freelistsize;
static size_t freelistptr;

static pthread_mutexattr_t mutexattr;

static bool initialize(void) {
  pthread_mutexattr_init(&mutexattr);
  pthread_mutexattr_settype(&mutexattr, PTHREAD_MUTEX_RECURSIVE);

  static bool initialized = false;
  if (initialized)
    return false;
  buffer = malloc(sizeof(queue));
  if (buffer) {
    freelist = malloc(sizeof(size_t));
    if (!freelist) {
      free(buffer);
      return true;
    }
    freelistsize = 1;
    freelistptr = 1;
    *freelist = 0;
    bufsize = 1;
    initialized = true;
    return false;
  }
  return true;
}

static bool init_queue(queue *q) {
  q->initialized = false;
  pthread_mutexattr_t attr;
  int ret = pthread_mutex_init(&q->lock, &mutexattr);
  if (ret)
    return true;
  q->initialized = true;
  return false;
}

static bool destroy_queue(queue *q) {
  if (!q->initialized)
    return true;
  if (pthread_mutex_destroy(&q->lock))
    return true;
  q->initialized = false;
  return false;
}

queue_ts queue_ts_new(void) {
  if (initialize())
    return -1;

  queue_ts ret;
  if (freelistptr > 0) {
    --freelistptr;
    ret = freelist[freelistptr];
  } else {
    size_t newsize = bufsize + 1;
    void *newptr = realloc(buffer, sizeof(queue) * newsize);
    if (!newptr)
      return -1;
    buffer = newptr;
    bufsize = newsize;
    ret = bufsize - 1;
  }
  init_queue(&buffer[ret]);
  return ret;
}

bool queue_ts_destroy(queue_ts q) {
  if (initialize())
    return true;
  if (freelistptr == freelistsize) {
    size_t newsize = freelistsize * 2;
    void *newptr = realloc(freelist, sizeof(queue_ts) * newsize);
    if (!newptr)
      return true;
    freelist = newptr;
    freelistsize = newsize;
  }
  if (destroy_queue(&buffer[q]))
    return true;
  freelist[freelistptr] = q;
  ++freelistptr;
  return false;
}
