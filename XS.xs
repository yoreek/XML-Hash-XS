#include "src/xh_config.h"
#include "src/xh_core.h"

MODULE = XML::Hash::XS PACKAGE = XML::Hash::XS

PROTOTYPES: DISABLE

xh_opts_t *
new(CLASS,...)
    PREINIT:
        xh_opts_t  *opts;
    CODE:
        dXCPT;

        if ((opts = xh_create_opts()) == NULL)
            croak("Malloc error in new()");

        XCPT_TRY_START
        {
            xh_parse_param(opts, 1, ax, items);
        } XCPT_TRY_END

        XCPT_CATCH
        {
            xh_destroy_opts(opts);
            XCPT_RETHROW;
        }

        RETVAL = opts;
    OUTPUT:
        RETVAL

SV *
hash2xml(...)
    PREINIT:
        xh_opts_t    *opts = NULL;
        xh_h2x_ctx_t  ctx;
        SV           *param, *hash, *result;
        xh_int_t      nparam    = 0;
    CODE:
        /* get object reference */
        if (nparam >= items)
            croak("Invalid parameters");
        param = ST(nparam);
        if ( sv_derived_from(param, "XML::Hash::XS") ) {
            if ( sv_isobject(param) ) {
                /* reference to object */
                IV tmp = SvIV((SV *) SvRV(param));
                opts = INT2PTR(xh_opts_t *, tmp);
            }
            nparam++;
        }

        /* get hash reference */
        if (nparam >= items)
            croak("Invalid parameters");
        param = ST(nparam);
        if (SvROK(param) && SvTYPE(SvRV(param)) == SVt_PVHV) {
            hash = param;
            nparam++;
        }
        else {
            croak("Parameter is not hash reference");
        }

        /* parse options */
        memset(&ctx, 0, sizeof(xh_h2x_ctx_t));
        if (opts == NULL) {
            /* read global options */
            xh_init_opts(&ctx.opts);
        }
        else {
            /* read options from object */
            memcpy(&ctx.opts, opts, sizeof(xh_opts_t));
        }
        if (nparam < items) {
            xh_parse_param(&ctx.opts, nparam, ax, items);
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

SV *
xml2hash(...)
    PREINIT:
        xh_opts_t     *opts = NULL;
        xh_x2h_ctx_t   ctx;
        SV            *param, *result, *input;
        xh_int_t       nparam = 0;
    CODE:
        /* get object reference */
        if (nparam >= items)
            croak("Invalid parameters");
        param = ST(nparam);
        if ( sv_derived_from(param, "XML::Hash::XS") ) {
            if ( sv_isobject(param) ) {
                /* reference to object */
                IV tmp = SvIV((SV *) SvRV(param));
                opts = INT2PTR(xh_opts_t *, tmp);
            }
            nparam++;
        }

        /* get xml as string or file name */
        if (nparam >= items)
            croak("Invalid parameters");
        param = ST(nparam);
        if (SvROK(param))
            param = SvRV(param);
        if (!SvOK(param))
            croak("Invalid parameters");
        if (!SvPOK(param) && SvTYPE(param) != SVt_PVGV)
            croak("Invalid parameters");
        input = param;
        nparam++;

        /* parse options */
        memset(&ctx, 0, sizeof(xh_x2h_ctx_t));
        if (opts == NULL) {
            /* read global options */
            xh_init_opts(&ctx.opts);
        }
        else {
            /* read options from object */
            memcpy(&ctx.opts, opts, sizeof(xh_opts_t));
        }
        if (nparam < items) {
            xh_parse_param(&ctx.opts, nparam, ax, items);
        }

        ctx.nodes = malloc(sizeof(SV *) * ctx.opts.max_depth);
        memset(ctx.nodes, 0, sizeof(SV *) * ctx.opts.max_depth);

        result = xh_x2h(&ctx, input);

        free(ctx.nodes);
        if (ctx.tmp != NULL)
            free(ctx.tmp);

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
DESTROY(opts)
        xh_opts_t *opts;
    CODE:
        xh_destroy_opts(opts);
