#ifndef __QAMAR_QUEUE_TS__
#define __QAMAR_QUEUE_TS__

#include <pthread.h>
#include <stdbool.h>
#include <stdint.h>

typedef int32_t queue_ts;

queue_ts queue_ts_new(void);
bool queue_ts_destroy(queue_ts);

#endif
