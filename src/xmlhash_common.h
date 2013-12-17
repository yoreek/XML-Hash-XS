#ifndef _XMLHASH_COMMON_H_
#define _XMLHASH_COMMON_H_

#include "EXTERN.h"
#include "perl.h"
#define NO_XSLOCKS
#include "XSUB.h"
#include "ppport.h"
#include <stdint.h>

#ifndef MUTABLE_PTR
#if defined(__GNUC__) && !defined(PERL_GCC_BRACE_GROUPS_FORBIDDEN)
#  define MUTABLE_PTR(p) ({ void *_p = (p); _p; })
#else
#  define MUTABLE_PTR(p) ((void *) (p))
#endif
#endif

#ifndef MUTABLE_SV
#define MUTABLE_SV(p)   ((SV *)MUTABLE_PTR(p))
#endif

#if __GNUC__ >= 3
# define expect(expr,value)         __builtin_expect ((expr), (value))
# define INLINE                     static inline
#else
# define expect(expr,value)         (expr)
# define INLINE                     static
#endif

#define expect_false(expr) expect ((expr) != 0, 0)
#define expect_true(expr)  expect ((expr) != 0, 1)

typedef uintptr_t bool_t;

#ifndef FALSE
#define FALSE (0)
#endif

#ifndef TRUE
#define TRUE  (1)
#endif

#define str3cmp(p, c0, c1, c2)                                                \
    *(uint32_t *) p == ((c2 << 16) | (c1 << 8) | c0)

#define str4cmp(p, c0, c1, c2, c3)                                            \
    *(uint32_t *) p == ((c3 << 24) | (c2 << 16) | (c1 << 8) | c0)

#define str5cmp(p, c0, c1, c2, c3, c4)                                        \
    *(uint32_t *) p == ((c3 << 24) | (c2 << 16) | (c1 << 8) | c0)             \
        && p[4] == c4

#define str6cmp(p, c0, c1, c2, c3, c4, c5)                                    \
    *(uint32_t *) p == ((c3 << 24) | (c2 << 16) | (c1 << 8) | c0)             \
        && (((uint32_t *) p)[1] & 0xffff) == ((c5 << 8) | c4)

#define str7cmp(p, c0, c1, c2, c3, c4, c5, c6)                                \
    *(uint32_t *) p == ((c3 << 24) | (c2 << 16) | (c1 << 8) | c0)             \
        && ((uint32_t *) p)[1] == ((c6 << 16) | (c5 << 8) | c4)

#define str8cmp(p, c0, c1, c2, c3, c4, c5, c6, c7)                            \
    *(uint32_t *) p == ((c3 << 24) | (c2 << 16) | (c1 << 8) | c0)             \
        && ((uint32_t *) p)[1] == ((c7 << 24) | (c6 << 16) | (c5 << 8) | c4)

#define str9cmp(p, c0, c1, c2, c3, c4, c5, c6, c7, c8)                        \
    *(uint32_t *) p == ((c3 << 24) | (c2 << 16) | (c1 << 8) | c0)             \
        && ((uint32_t *) p)[1] == ((c7 << 24) | (c6 << 16) | (c5 << 8) | c4)  \
        && p[8] == c8

INLINE char *
XMLHash_trim_string(char *s, int *len)
{
    char *cur, *end, ch;
    int first = 1;

    end = cur = s;
    while ((ch = *cur++) != '\0') {
        switch (ch) {
            case ' ':
            case '\t':
            case '\n':
            case '\r':
                if (first) {
                    s = end = cur;
                }
                break;
            default:
                if (first) {
                    first--;
                }
                end = cur;
        }
    }

    *len = end - s;

    return s;
}

#endif
