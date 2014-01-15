#include "src/xh_config.h"
#include "src/xh_core.h"
#include "src/xh_h2x.h"

MODULE = XML::Hash::XS PACKAGE = XML::Hash::XS

PROTOTYPES: DISABLE

xh_h2x_opts_t *
new(CLASS,...)
    PREINIT:
        xh_h2x_opts_t  *opts;
    CODE:
        if ((opts = xh_h2x_create()) == NULL) {
            croak("Malloc error in new()");
        }

        dXCPT;
        XCPT_TRY_START
        {
            xh_h2x_parse_param(opts, 1, ax, items);
        } XCPT_TRY_END

        XCPT_CATCH
        {
            xh_h2x_destroy(opts);
            XCPT_RETHROW;
        }

        RETVAL = opts;
    OUTPUT:
        RETVAL

SV *
hash2xml(...)
    PREINIT:
        xh_h2x_opts_t *opts = NULL;
        xh_h2x_ctx_t   ctx;
        SV         *p, *hash, *result;
        xh_int_t    nparam    = 0;
    CODE:
        /* get object reference */
        if (nparam >= items)
            croak("Invalid parameters");

        p = ST(nparam);
        if ( sv_isa(p, "XML::Hash::XS") ) {
            /* reference to object */
            IV tmp = SvIV((SV *) SvRV(p));
            opts = INT2PTR(xh_h2x_opts_t *, tmp);
            nparam++;
        }
        else if ( SvTYPE(p) == SVt_PV ) {
            /* class name */
            nparam++;
        }

        /* get hash reference */
        if (nparam >= items)
            croak("Invalid parameters");

        p = ST(nparam);
        if (SvROK(p) && SvTYPE(SvRV(p)) == SVt_PVHV) {
            hash = p;
            nparam++;
        }
        else {
            croak("Parameter is not hash reference");
        }

        /* set options */
        memset(&ctx, 0, sizeof(xh_h2x_ctx_t));
        if (opts == NULL) {
            /* read global options */
            xh_h2x_init_opts(&ctx.opts);
        }
        else {
            /* read options from object */
            memcpy(&ctx.opts, opts, sizeof(xh_h2x_opts_t));
        }
        if (nparam < items) {
            xh_h2x_parse_param(&ctx.opts, nparam, ax, items);
        }

        /* run */
#ifdef XH_HAVE_DOM
        if (ctx.opts.doc) {
            result = xh_h2d(&ctx, hash);
        }
        else {
            result = xh_h2x(&ctx, hash);
        }
#else
        result = xh_h2x(&ctx, hash);
#endif

        if (ctx.opts.output != NULL) {
            XSRETURN_UNDEF;
        }

        if (result == NULL) {
            warn("Failed to convert");
            XSRETURN_UNDEF;
        }

        RETVAL = result;

    OUTPUT:
        RETVAL

void
DESTROY(conv)
        xh_h2x_opts_t *conv;
    CODE:
        xh_h2x_destroy(conv);
