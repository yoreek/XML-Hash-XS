#ifndef _XH_SORT_H_
#define _XH_SORT_H_

#include "xh_config.h"
#include "xh_core.h"

typedef struct {
    char             *key;
    I32               key_len;
    void             *value;
} xh_sort_hash_t;

xh_sort_hash_t *xh_sort_hash(HV *hash, size_t len);

#endif /* _XH_SORT_H_ */
