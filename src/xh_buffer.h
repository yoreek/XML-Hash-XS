#ifndef _XH_BUFFER_H_
#define _XH_BUFFER_H_

#include "xh_config.h"
#include "xh_core.h"

typedef struct _xh_buffer_t xh_buffer_t;
struct _xh_buffer_t {
    SV                    *scalar;
    char                  *start;
    char                  *cur;
    char                  *end;
};

void xh_buffer_init(xh_buffer_t *buf, size_t size);
void xh_buffer_resize(xh_buffer_t *buf, size_t inc);

#endif /* _XH_BUFFER_H_ */
