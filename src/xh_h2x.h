#ifndef _XH_H2X_H_
#define _XH_H2X_H_

#include "xh_config.h"
#include "xh_core.h"

#define XH_H2X_F_NONE                   0
#define XH_H2X_F_SIMPLE                 1
#define XH_H2X_F_COMPLEX                2
#define XH_H2X_F_CONTENT                4
#define XH_H2X_F_ATTR_ONLY              8

#define XH_H2X_T_SCALAR                 1
#define XH_H2X_T_HASH                   2
#define XH_H2X_T_ARRAY                  4
#define XH_H2X_T_BLESSED                8
#define XH_H2X_T_RAW                    16
#define XH_H2X_T_NOT_NULL               (XH_H2X_T_SCALAR | XH_H2X_T_ARRAY | XH_H2X_T_HASH)

#define XH_H2X_STASH_SIZE               16

typedef struct {
    xh_opts_t    opts;
    xh_int_t     depth;
    xh_writer_t  writer;
    xh_stack_t   stash;
} xh_h2x_ctx_t;

XH_INLINE SV *
xh_h2x_call_method(SV *obj, GV *method, xh_char_t *method_name)
{
    int  count;
    SV  *result = &PL_sv_undef;

    dSP;

    ENTER; SAVETMPS; PUSHMARK (SP);
    XPUSHs(sv_2mortal(newRV_inc(obj)));
    PUTBACK;

    count = call_sv((SV *) GvCV(method), G_SCALAR);

    SPAGAIN;

    if (count) {
        result = POPs;
        SvREFCNT_inc_void(result);
    }

    PUTBACK;

    FREETMPS; LEAVE;

    return result;
}

XH_INLINE SV *
xh_h2x_resolve_value(xh_h2x_ctx_t *ctx, SV *value, xh_uint_t *type)
{
    xh_int_t  nitems;
    GV       *method;

    *type = 0;

    while ( SvOK(value) && SvROK(value) ) {
        if (++ctx->depth > ctx->opts.max_depth)
            croak("Maximum recursion depth exceeded");

        value = SvRV(value);
        *type = 0;

        if (SvOBJECT(value)) {
            if ((method = gv_fetchmethod_autoload(SvSTASH(value), "toString", 0)) != NULL) {
                dSP;

                ENTER; SAVETMPS; PUSHMARK(SP);
                XPUSHs(sv_2mortal(newRV_inc(value)));
                PUTBACK;

                nitems = call_sv((SV *) GvCV(method), G_SCALAR);

                SPAGAIN;

                if (nitems == 1) {
                    value = POPs;
                    PUTBACK;

                    SvREFCNT_inc_void(value);

                    xh_stash_push(&ctx->stash, value);

                    FREETMPS; LEAVE;
                }
                else {
                    value = &PL_sv_undef;
                }

                *type |= XH_H2X_T_RAW;
            }
        }
        else if( SvTYPE(value) == SVt_PVCV ) {
            dSP;

            ENTER; SAVETMPS; PUSHMARK (SP);

            nitems = call_sv(value, G_SCALAR|G_NOARGS);

            SPAGAIN;

            if (nitems == 1) {
                value = POPs;

                SvREFCNT_inc_void(value);

                xh_stash_push(&ctx->stash, value);

                PUTBACK;

                FREETMPS;
                LEAVE;
            }
            else {
                value = &PL_sv_undef;
            }
        }
    }

    if (SvTYPE(value) == SVt_PVHV) {
        *type |= XH_H2X_T_HASH;
    }
    else if (SvTYPE(value) == SVt_PVAV) {
        *type |= XH_H2X_T_ARRAY;
    }
    else if (!SvOK(value)) {
        *type = 0;
    }
    else {
        *type |= XH_H2X_T_SCALAR;
    }

    if (SvOBJECT(value))
        *type |= XH_H2X_T_BLESSED;

    return value;
}

SV *xh_h2x(xh_h2x_ctx_t *ctx, SV *hash);
void xh_h2x_native(xh_h2x_ctx_t *ctx, xh_char_t *key, I32 key_len, SV *value);
xh_int_t xh_h2x_native_attr(xh_h2x_ctx_t *ctx, xh_char_t *key, I32 key_len, SV *value, xh_int_t flag);
void xh_h2x_lx(xh_h2x_ctx_t *ctx, SV *value, xh_int_t flag);

#ifdef XH_HAVE_DOM
SV *xh_h2d(xh_h2x_ctx_t *ctx, SV *hash);
void xh_h2d_native(xh_h2x_ctx_t *ctx, xmlNodePtr rootNode, xh_char_t *key, I32 key_len, SV *value);
xh_int_t xh_h2d_native_attr(xh_h2x_ctx_t *ctx, xmlNodePtr rootNode, xh_char_t *key, I32 key_len, SV *value, xh_int_t flag);
void xh_h2d_lx(xh_h2x_ctx_t *ctx, xmlNodePtr rootNode, SV *value, xh_int_t flag);
#endif

#endif /* _XH_H2X_H_ */
