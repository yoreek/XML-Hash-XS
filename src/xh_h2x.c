#include "xh_config.h"
#include "xh_core.h"

#define XH_H2X_DEF_OUTPUT    NULL
#define XH_H2X_DEF_METHOD    "NATIVE"
#define XH_H2X_DEF_ROOT      "root"
#define XH_H2X_DEF_VERSION   "1.0"
#define XH_H2X_DEF_ENCODING  "utf-8"
#define XH_H2X_DEF_INDENT    0
#define XH_H2X_DEF_CANONICAL FALSE
#define XH_H2X_DEF_USE_ATTR  FALSE
#define XH_H2X_DEF_CONTENT   ""
#define XH_H2X_DEF_XML_DECL  TRUE
#ifdef XH_HAVE_DOM
#define XH_H2X_DEF_DOC       FALSE
#endif

#define XH_H2X_DEF_ATTR      "-"
#define XH_H2X_DEF_TEXT      "#text"
#define XH_H2X_DEF_TRIM      FALSE
#define XH_H2X_DEF_CDATA     ""
#define XH_H2X_DEF_COMM      ""

#define XH_H2X_DEF_MAX_DEPTH 1024

const char indent_string[60] = "                                                            ";

#define XH_H2X_STASH_SIZE    16

void
xh_h2x_destroy(xh_h2x_opts_t *opts)
{
    if (opts != NULL) {
        free(opts);
    }
}

xh_bool_t
xh_h2x_init_opts(xh_h2x_opts_t *opts)
{
    char      method[XH_PARAM_LEN];
    xh_bool_t use_attr;

    XH_PARAM_READ_INIT

    /* native options */
    XH_PARAM_READ_STRING(opts->root,      "XML::Hash::XS::root",      XH_H2X_DEF_ROOT);
    XH_PARAM_READ_STRING(opts->version,   "XML::Hash::XS::version",   XH_H2X_DEF_VERSION);
    XH_PARAM_READ_STRING(opts->encoding,  "XML::Hash::XS::encoding",  XH_H2X_DEF_ENCODING);
    XH_PARAM_READ_INT   (opts->indent,    "XML::Hash::XS::indent",    XH_H2X_DEF_INDENT);
    XH_PARAM_READ_BOOL  (opts->canonical, "XML::Hash::XS::canonical", XH_H2X_DEF_CANONICAL);
    XH_PARAM_READ_STRING(opts->content,   "XML::Hash::XS::content",   XH_H2X_DEF_CONTENT);
    XH_PARAM_READ_BOOL  (opts->xml_decl,  "XML::Hash::XS::xml_decl",  XH_H2X_DEF_XML_DECL);
#ifdef XH_HAVE_DOM
    XH_PARAM_READ_BOOL  (opts->doc,       "XML::Hash::XS::doc",       XH_H2X_DEF_DOC);
#endif
    XH_PARAM_READ_BOOL  (use_attr,        "XML::Hash::XS::use_attr",  XH_H2X_DEF_USE_ATTR);
    XH_PARAM_READ_INT   (opts->max_depth, "XML::Hash::XS::max_depth", XH_H2X_DEF_MAX_DEPTH);

    /* XML::Hash::LX options */
    XH_PARAM_READ_STRING(opts->attr,      "XML::Hash::XS::attr",      XH_H2X_DEF_ATTR);
    opts->attr_len = strlen(opts->attr);
    XH_PARAM_READ_STRING(opts->text,      "XML::Hash::XS::text",      XH_H2X_DEF_TEXT);
    XH_PARAM_READ_BOOL  (opts->trim,      "XML::Hash::XS::trim",      XH_H2X_DEF_TRIM);
    XH_PARAM_READ_STRING(opts->cdata,     "XML::Hash::XS::cdata",     XH_H2X_DEF_CDATA);
    XH_PARAM_READ_STRING(opts->comm,      "XML::Hash::XS::comm",      XH_H2X_DEF_COMM);

    /* method */
    XH_PARAM_READ_STRING(method,          "XML::Hash::XS::method",    XH_H2X_DEF_METHOD);
    if (strcmp(method, "LX") == 0) {
        opts->method = XH_H2X_METHOD_LX;
    }
    else if (use_attr) {
        opts->method = XH_H2X_METHOD_NATIVE_ATTR_MODE;
    }
    else {
        opts->method = XH_H2X_METHOD_NATIVE;
    }

    /* output, NULL - to string */
    XH_PARAM_READ_REF   (opts->output,    "XML::Hash::XS::output",    XH_H2X_DEF_OUTPUT);

    return TRUE;
}

xh_h2x_opts_t *
xh_h2x_create(void)
{
    xh_h2x_opts_t *opts;

    if ((opts = malloc(sizeof(xh_h2x_opts_t))) == NULL) {
        return NULL;
    }
    memset(opts, 0, sizeof(xh_h2x_opts_t));

    if (! xh_h2x_init_opts(opts)) {
        xh_h2x_destroy(opts);
        return NULL;
    }

    return opts;
}

void
xh_h2x_parse_param(xh_h2x_opts_t *opts, xh_int_t first, I32 ax, I32 items)
{
    xh_int_t  i;
    char     *p, *cv;
    SV       *v;
    STRLEN    len;
    xh_int_t  use_attr = -1;

    if ((items - first) % 2 != 0) {
        croak("Odd number of parameters in new()");
    }

    for (i = first; i < items; i = i + 2) {
        v = ST(i);
        if (!SvOK(v)) {
            croak("Parameter name is undefined");
        }

        p = (char *) SvPV(v, len);
        v = ST(i + 1);

        switch (len) {
#ifdef XH_HAVE_DOM
            case 3:
                if (xh_str_equal3(p, 'd', 'o', 'c')) {
                    opts->doc = xh_param_assign_bool(v);
                    break;
                }
                goto error;
#endif
            case 4:
                if (xh_str_equal4(p, 'a', 't', 't', 'r')) {
                    xh_param_assign_string(opts->attr, v);
                    if (opts->attr[0] == '\0') {
                        opts->attr_len = 0;
                    }
                    else {
                        opts->attr_len = strlen(opts->attr);
                    }
                    break;
                }
                if (xh_str_equal4(p, 'c', 'o', 'm', 'm')) {
                    xh_param_assign_string(opts->comm, v);
                    break;
                }
                if (xh_str_equal4(p, 'r', 'o', 'o', 't')) {
                    xh_param_assign_string(opts->root, v);
                    break;
                }
                if (xh_str_equal4(p, 't', 'r', 'i', 'm')) {
                    opts->trim = xh_param_assign_bool(v);
                    break;
                }
                if (xh_str_equal4(p, 't', 'e', 'x', 't')) {
                    xh_param_assign_string(opts->text, v);
                    break;
                }
                goto error;
            case 5:
                if (xh_str_equal5(p, 'c', 'd', 'a', 't', 'a')) {
                    xh_param_assign_string(opts->cdata, v);
                    break;
                }
                goto error;
            case 6:
                if (xh_str_equal6(p, 'i', 'n', 'd', 'e', 'n', 't')) {
                    xh_param_assign_int(p, &opts->indent, v);
                    break;
                }
                if (xh_str_equal6(p, 'm', 'e', 't', 'h', 'o', 'd')) {
                    if (!SvOK(v)) {
                        croak("Parameter '%s' is undefined", p);
                    }
                    cv = SvPV(v, len);
                    switch  (len) {
                        case 6:
                            if (xh_str_equal6(cv, 'N', 'A', 'T', 'I', 'V', 'E')) {
                                opts->method = XH_H2X_METHOD_NATIVE;
                                break;
                            }
                            goto error_value;
                        case 2:
                            if (cv[0] == 'L' && cv[1] == 'X') {
                                opts->method = XH_H2X_METHOD_LX;
                                break;
                            }
                            goto error_value;
                        default:
                            goto error_value;
                    }
                    break;
                }
                if (xh_str_equal6(p, 'o', 'u', 't', 'p', 'u', 't')) {
                    if ( SvOK(v) && SvROK(v) ) {
                        opts->output = SvRV(v);
                    }
                    else {
                        opts->output = NULL;
                    }
                    break;
                }
                goto error;
            case 7:
                if (xh_str_equal7(p, 'c', 'o', 'n', 't', 'e', 'n', 't')) {
                    xh_param_assign_string(opts->content, v);
                    break;
                }
                if (xh_str_equal7(p, 'v', 'e', 'r', 's', 'i', 'o', 'n')) {
                    xh_param_assign_string(opts->version, v);
                    break;
                }
                goto error;
            case 8:
                if (xh_str_equal8(p, 'e', 'n', 'c', 'o', 'd', 'i', 'n', 'g')) {
                    xh_param_assign_string(opts->encoding, v);
                    break;
                }
                if (xh_str_equal8(p, 'u', 's', 'e', '_', 'a', 't', 't', 'r')) {
                    use_attr = xh_param_assign_bool(v);
                    break;
                }
                if (xh_str_equal8(p, 'x', 'm', 'l', '_', 'd', 'e', 'c', 'l')) {
                    opts->xml_decl = xh_param_assign_bool(v);
                    break;
                }
                goto error;
            case 9:
                if (xh_str_equal9(p, 'c', 'a', 'n', 'o', 'n', 'i', 'c', 'a', 'l')) {
                    opts->canonical = xh_param_assign_bool(v);
                    break;
                }
                if (xh_str_equal9(p, 'm', 'a', 'x', '_', 'd', 'e', 'p', 't', 'h')) {
                    xh_param_assign_int(p, &opts->max_depth, v);
                    break;
                }
                goto error;
            default:
                goto error;
        }
    }

    if (use_attr != -1 && (opts->method == XH_H2X_METHOD_NATIVE || opts->method == XH_H2X_METHOD_NATIVE_ATTR_MODE)) {
        if (use_attr == TRUE) {
            opts->method = XH_H2X_METHOD_NATIVE_ATTR_MODE;
        }
        else {
            opts->method = XH_H2X_METHOD_NATIVE;
        }
    }

    return;

error_value:
    croak("Invalid parameter value for '%s': %s", p, cv);
    return;

error:
    croak("Invalid parameter '%s'", p);
}

SV *
xh_h2x(xh_h2x_ctx_t *ctx, SV *hash)
{
    SV          *result;
    xh_writer_t *writer = NULL;

    /* run */
    dXCPT;
    XCPT_TRY_START
    {
        xh_stack_init(&ctx->stash, XH_H2X_STASH_SIZE, sizeof(SV *));
        ctx->writer = writer = xh_writer_create(ctx->opts.encoding, ctx->opts.output, 16384, ctx->opts.indent, ctx->opts.trim);

        if (ctx->opts.xml_decl) {
            xh_xml_write_xml_declaration(writer, ctx->opts.version, ctx->opts.encoding);
        }

        switch (ctx->opts.method) {
            case XH_H2X_METHOD_NATIVE:
                xh_h2x_native(ctx, ctx->opts.root, strlen(ctx->opts.root), SvRV(hash));
                break;
            case XH_H2X_METHOD_NATIVE_ATTR_MODE:
                (void) xh_h2x_native_attr(ctx, ctx->opts.root, strlen(ctx->opts.root), SvRV(hash), XH_H2X_F_COMPLEX);
                break;
            case XH_H2X_METHOD_LX:
                xh_h2x_lx(ctx, hash, XH_H2X_F_NONE);
                break;
            default:
                croak("Invalid method");
        }
    } XCPT_TRY_END

    XCPT_CATCH
    {
        xh_stash_clean(&ctx->stash);
        xh_writer_destroy(writer);
        XCPT_RETHROW;
    }

    xh_stash_clean(&ctx->stash);
    result = xh_writer_flush(writer);
    if (result != NULL) {
#ifdef XH_HAVE_ENCODER
        if (writer->encoder == NULL) {
            SvUTF8_on(result);
        }
#else
        SvUTF8_on(result);
#endif
    }
    xh_writer_destroy(writer);

    return result;
}

#ifdef XH_HAVE_DOM
SV *
xh_h2d(xh_h2x_ctx_t *ctx, SV *hash)
{
    dXCPT;

    xmlDocPtr doc = xmlNewDoc(BAD_CAST ctx->opts.version);
    if (doc == NULL) {
        croak("Can't create new document");
    }
    doc->encoding = (const xmlChar*) xmlStrdup((const xmlChar*) ctx->opts.encoding);

    XCPT_TRY_START
    {
        xh_stack_init(&ctx->stash, XH_H2X_STASH_SIZE, sizeof(SV *));
        switch (ctx->opts.method) {
            case XH_H2X_METHOD_NATIVE:
                xh_h2d_native(ctx, (xmlNodePtr) doc, ctx->opts.root, strlen(ctx->opts.root), SvRV(hash));
                break;
            case XH_H2X_METHOD_NATIVE_ATTR_MODE:
                (void) xh_h2d_native_attr(ctx, (xmlNodePtr) doc, ctx->opts.root, strlen(ctx->opts.root), SvRV(hash), XH_H2X_F_COMPLEX);
                break;
            case XH_H2X_METHOD_LX:
                xh_h2d_lx(ctx, (xmlNodePtr) doc, hash, XH_H2X_F_NONE);
                break;
            default:
                croak("Invalid method");
        }
    } XCPT_TRY_END

    XCPT_CATCH
    {
        xh_stash_clean(&ctx->stash);
        XCPT_RETHROW;
    }

    xh_stash_clean(&ctx->stash);

    return x_PmmNodeToSv((xmlNodePtr) doc, NULL);
}
#endif
