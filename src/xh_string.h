#ifndef _XH_STRING_H_
#define _XH_STRING_H_

#include "xh_config.h"
#include "xh_core.h"

#define xh_str_equal3(p, c0, c1, c2)                                   \
    *(uint32_t *) p == ((c2 << 16) | (c1 << 8) | c0)

#define xh_str_equal4(p, c0, c1, c2, c3)                               \
    *(uint32_t *) p == ((c3 << 24) | (c2 << 16) | (c1 << 8) | c0)

#define xh_str_equal5(p, c0, c1, c2, c3, c4)                           \
    *(uint32_t *) p == ((c3 << 24) | (c2 << 16) | (c1 << 8) | c0)      \
        && p[4] == c4

#define xh_str_equal6(p, c0, c1, c2, c3, c4, c5)                       \
    *(uint32_t *) p == ((c3 << 24) | (c2 << 16) | (c1 << 8) | c0)      \
        && (((uint32_t *) p)[1] & 0xffff) == ((c5 << 8) | c4)

#define xh_str_equal7(p, c0, c1, c2, c3, c4, c5, c6)                   \
    *(uint32_t *) p == ((c3 << 24) | (c2 << 16) | (c1 << 8) | c0)      \
        && ((uint32_t *) p)[1] == ((c6 << 16) | (c5 << 8) | c4)

#define xh_str_equal8(p, c0, c1, c2, c3, c4, c5, c6, c7)               \
    *(uint32_t *) p == ((c3 << 24) | (c2 << 16) | (c1 << 8) | c0)      \
        && ((uint32_t *) p)[1] == ((c7 << 24) | (c6 << 16) | (c5 << 8) | c4)

#define xh_str_equal9(p, c0, c1, c2, c3, c4, c5, c6, c7, c8)           \
    *(uint32_t *) p == ((c3 << 24) | (c2 << 16) | (c1 << 8) | c0)      \
        && ((uint32_t *) p)[1] == ((c7 << 24) | (c6 << 16) | (c5 << 8) | c4)\
        && p[8] == c8

XH_INLINE char *
xh_str_trim(char *s, size_t *len)
{
    char *end, ch;

    end = s + *len;

    while ((ch = *s++) == ' ' || ch =='\t' || ch == '\n' || ch == '\r');
    if (ch == '\0') {
        *len = 0;
        return s - 1;
    }

    s--;

    while (--end != s && ((ch = *end) == ' ' || ch =='\t' || ch == '\n' || ch == '\r'));

    *len = end - s + 1;

    return s;
}

#endif /* _XH_STRING_H_ */
