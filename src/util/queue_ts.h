#ifndef __QAMAR_QUEUE_TS__
#define __QAMAR_QUEUE_TS__

#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>

typedef void *queue_ts;

bool queue_ts_new(size_t, queue_ts *);
bool queue_ts_destroy(queue_ts);
bool queue_ts_push_back(queue_ts, const void *);
bool queue_ts_pop_front(queue_ts, void *);
bool queue_ts_push_front(queue_ts, const void *);
bool queue_ts_pop_back(queue_ts, void *);

#endif
