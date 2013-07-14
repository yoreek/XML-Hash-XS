#include "xmlhash_common.h"
#include "xmlhash_converter.h"

#define CONV_DEF_OUTPUT    NULL
#define CONV_DEF_METHOD    "NATIVE"
#define CONV_DEF_ROOT      "root"
#define CONV_DEF_VERSION   "1.0"
#define CONV_DEF_ENCODING  "utf-8"
#define CONV_DEF_INDENT    0
#define CONV_DEF_CANONICAL FALSE
#define CONV_DEF_USE_ATTR  FALSE
#define CONV_DEF_CONTENT   ""
#define CONV_DEF_XML_DECL  TRUE
#define CONV_DEF_DOC       FALSE

#define CONV_DEF_ATTR      "-"
#define CONV_DEF_TEXT      "#text"
#define CONV_DEF_TRIM      TRUE
#define CONV_DEF_CDATA     ""
#define CONV_DEF_COMM      ""

#define CONV_READ_PARAM_INIT                            \
    SV   *sv;                                           \
    char *str;
#define CONV_READ_STRING_PARAM(var, name, def_value)    \
    if ( (sv = get_sv(name, 0)) != NULL ) {             \
        if ( SvOK(sv) ) {                               \
            str = (char *) SvPV_nolen(sv);              \
            strncpy(var, str, CONV_STR_PARAM_LEN);      \
        }                                               \
        else {                                          \
            var[0] = '\0';                              \
        }                                               \
    }                                                   \
    else {                                              \
        strncpy(var, def_value, CONV_STR_PARAM_LEN);    \
    }
#define CONV_READ_BOOL_PARAM(var, name, def_value)      \
    if ( (sv = get_sv(name, 0)) != NULL ) {             \
        if ( SvTRUE(sv) ) {                             \
            var = TRUE;                                 \
        }                                               \
        else {                                          \
            var = FALSE;                                \
        }                                               \
    }                                                   \
    else {                                              \
        var = def_value;                                \
    }
#define CONV_READ_INT_PARAM(var, name, def_value)       \
    if ( (sv = get_sv(name, 0)) != NULL ) {             \
        var = SvIV(sv);                                 \
    }                                                   \
    else {                                              \
        var = def_value;                                \
    }
#define CONV_READ_REF_PARAM(var, name, def_value)       \
    if ( (sv = get_sv(name, 0)) != NULL ) {             \
        if ( SvOK(sv) && SvROK(sv) ) {                  \
            var = sv;                                   \
        }                                               \
        else {                                          \
            var = NULL;                                 \
        }                                               \
    }                                                   \
    else {                                              \
        var = def_value;                                \
    }

void
XMLHash_conv_destroy(conv_opts_t *conv_opts)
{
    if (conv_opts != NULL) {
        free(conv_opts);
    }
}

bool_t
XMLHash_conv_init_options(conv_opts_t *opts)
{
    char   method[CONV_STR_PARAM_LEN];
    bool_t use_attr;

    CONV_READ_PARAM_INIT

    /* native options */
    CONV_READ_STRING_PARAM(opts->root,      "XML::Hash::XS::root",      CONV_DEF_ROOT);
    CONV_READ_STRING_PARAM(opts->version,   "XML::Hash::XS::version",   CONV_DEF_VERSION);
    CONV_READ_STRING_PARAM(opts->encoding,  "XML::Hash::XS::encoding",  CONV_DEF_ENCODING);
    CONV_READ_INT_PARAM   (opts->indent,    "XML::Hash::XS::indent",    CONV_DEF_INDENT);
    CONV_READ_BOOL_PARAM  (opts->canonical, "XML::Hash::XS::canonical", CONV_DEF_CANONICAL);
    CONV_READ_STRING_PARAM(opts->content,   "XML::Hash::XS::content",   CONV_DEF_CONTENT);
    CONV_READ_BOOL_PARAM  (opts->xml_decl,  "XML::Hash::XS::xml_decl",  CONV_DEF_XML_DECL);
    CONV_READ_BOOL_PARAM  (opts->doc,       "XML::Hash::XS::doc",       CONV_DEF_DOC);
    CONV_READ_BOOL_PARAM  (use_attr,        "XML::Hash::XS::use_attr",  CONV_DEF_USE_ATTR);

    /* XML::Hash::LX options */
    CONV_READ_STRING_PARAM(opts->attr,      "XML::Hash::XS::attr",      CONV_DEF_ATTR);
    opts->attr_len = strlen(opts->attr);
    CONV_READ_STRING_PARAM(opts->text,      "XML::Hash::XS::text",      CONV_DEF_TEXT);
    CONV_READ_BOOL_PARAM  (opts->trim,      "XML::Hash::XS::trim",      CONV_DEF_TRIM);
    CONV_READ_STRING_PARAM(opts->cdata,     "XML::Hash::XS::cdata",     CONV_DEF_CDATA);
    CONV_READ_STRING_PARAM(opts->comm,      "XML::Hash::XS::comm",      CONV_DEF_COMM);

    /* method */
    CONV_READ_STRING_PARAM(method,          "XML::Hash::XS::method",    CONV_DEF_METHOD);
    if (strcmp(method, "LX") == 0) {
        opts->method = CONV_METHOD_LX;
    }
    else if (use_attr) {
        opts->method = CONV_METHOD_NATIVE_ATTR_MODE;
    }
    else {
        opts->method = CONV_METHOD_NATIVE;
    }

    /* output, NULL - to string */
    CONV_READ_REF_PARAM   (opts->output,    "XML::Hash::XS::output",    CONV_DEF_OUTPUT);

    return TRUE;
}

conv_opts_t *
XMLHash_conv_create(void)
{
    conv_opts_t *conv_opts;

    if ((conv_opts = malloc(sizeof(conv_opts_t))) == NULL) {
        return NULL;
    }
    memset(conv_opts, 0, sizeof(conv_opts_t));

    if (! XMLHash_conv_init_options(conv_opts)) {
        XMLHash_conv_destroy(conv_opts);
        return NULL;
    }

    return conv_opts;
}

void
XMLHash_conv_assign_string_param(char param[], SV *value)
{
    char *str;

    if ( SvOK(value) ) {
        str = (char *) SvPV_nolen(value);
        strncpy(param, str, CONV_STR_PARAM_LEN);
    }
    else {
        *param = 0;
    }
}

void
XMLHash_conv_assign_int_param(char *name, int *param, SV *value)
{
    if ( !SvOK(value) ) {
        croak("Parameter '%s' is undefined", name);
    }
    *param = SvIV(value);
}

bool_t
XMLHash_conv_assign_bool_param(SV *value)
{
    if ( SvTRUE(value) ) {
        return TRUE;
    }
    return FALSE;
}

void
XMLHash_conv_parse_param(conv_opts_t *opts, int first, I32 ax, I32 items)
{
    if ((items - first) % 2 != 0) {
        croak("Odd number of parameters in new()");
    }

    int      i;
    char    *p, *cv;
    SV      *v;
    STRLEN   len;
    bool_t   use_attr = -1;

    for (i = first; i < items; i = i + 2) {
        v = ST(i);
        if (!SvOK(v)) {
            croak("Parameter name is undefined");
        }

        p = (char *) SvPV(v, len);
        v = ST(i + 1);

        switch (len) {
            case 3:
                if (str3cmp(p, 'd', 'o', 'c')) {
                    opts->doc = XMLHash_conv_assign_bool_param(v);
                    break;
                }
                goto error;
            case 4:
                if (str4cmp(p, 'a', 't', 't', 'r')) {
                    XMLHash_conv_assign_string_param(opts->attr, v);
                    if (opts->attr[0] == '\0') {
                        opts->attr_len = 0;
                    }
                    else {
                        opts->attr_len = strlen(opts->attr);
                    }
                    break;
                }
                if (str4cmp(p, 'c', 'o', 'm', 'm')) {
                    XMLHash_conv_assign_string_param(opts->comm, v);
                    break;
                }
                if (str4cmp(p, 'r', 'o', 'o', 't')) {
                    XMLHash_conv_assign_string_param(opts->root, v);
                    break;
                }
                if (str4cmp(p, 't', 'r', 'i', 'm')) {
                    opts->trim = XMLHash_conv_assign_bool_param(v);
                    break;
                }
                if (str4cmp(p, 't', 'e', 'x', 't')) {
                    XMLHash_conv_assign_string_param(opts->text, v);
                    break;
                }
                goto error;
            case 5:
                if (str5cmp(p, 'c', 'd', 'a', 't', 'a')) {
                    XMLHash_conv_assign_string_param(opts->cdata, v);
                    break;
                }
                goto error;
            case 6:
                if (str6cmp(p, 'i', 'n', 'd', 'e', 'n', 't')) {
                    XMLHash_conv_assign_int_param(p, &opts->indent, v);
                    break;
                }
                if (str6cmp(p, 'm', 'e', 't', 'h', 'o', 'd')) {
                    if (!SvOK(v)) {
                        croak("Parameter '%s' is undefined", p);
                    }
                    cv = SvPV(v, len);
                    switch  (len) {
                        case 6:
                            if (str6cmp(cv, 'N', 'A', 'T', 'I', 'V', 'E')) {
                                opts->method = CONV_METHOD_NATIVE;
                                break;
                            }
                            goto error_value;
                        case 2:
                            if (cv[0] == 'L' && cv[1] == 'X') {
                                opts->method = CONV_METHOD_LX;
                                break;
                            }
                            goto error_value;
                        default:
                            goto error_value;
                    }
                    break;
                }
                if (str6cmp(p, 'o', 'u', 't', 'p', 'u', 't')) {
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
                if (str7cmp(p, 'c', 'o', 'n', 't', 'e', 'n', 't')) {
                    XMLHash_conv_assign_string_param(opts->content, v);
                    break;
                }
                if (str7cmp(p, 'v', 'e', 'r', 's', 'i', 'o', 'n')) {
                    XMLHash_conv_assign_string_param(opts->version, v);
                    break;
                }
                goto error;
            case 8:
                if (str8cmp(p, 'e', 'n', 'c', 'o', 'd', 'i', 'n', 'g')) {
                    XMLHash_conv_assign_string_param(opts->encoding, v);
                    break;
                }
                if (str8cmp(p, 'u', 's', 'e', '_', 'a', 't', 't', 'r')) {
                    use_attr = XMLHash_conv_assign_bool_param(v);
                    break;
                }
                if (str8cmp(p, 'x', 'm', 'l', '_', 'd', 'e', 'c', 'l')) {
                    opts->xml_decl = XMLHash_conv_assign_bool_param(v);
                    break;
                }
                goto error;
            case 9:
                if (str9cmp(p, 'c', 'a', 'n', 'o', 'n', 'i', 'c', 'a', 'l')) {
                    opts->canonical = XMLHash_conv_assign_bool_param(v);
                    break;
                }
                goto error;
            default:
                goto error;
        }
    }

    if (use_attr != -1 && (opts->method == CONV_METHOD_NATIVE || opts->method == CONV_METHOD_NATIVE_ATTR_MODE)) {
        if (use_attr == TRUE) {
            opts->method = CONV_METHOD_NATIVE_ATTR_MODE;
        }
        else {
            opts->method = CONV_METHOD_NATIVE;
        }
    }

    return;

error_value:
    croak("Invalid parameter value for '%s': %s", p, cv);
    return;

error:
    croak("Invalid parameter '%s'", p);
}

MODULE = XML::Hash::XS PACKAGE = XML::Hash::XS

PROTOTYPES: DISABLE

conv_opts_t *
new(CLASS,...)
    PREINIT:
        conv_opts_t  *conv_opts;
    CODE:
        if ((conv_opts = XMLHash_conv_create()) == NULL) {
            croak("Malloc error in new()");
        }

        dXCPT;
        XCPT_TRY_START
        {
            XMLHash_conv_parse_param(conv_opts, 1, ax, items);
        } XCPT_TRY_END

        XCPT_CATCH
        {
            XMLHash_conv_destroy(conv_opts);
            XCPT_RETHROW;
        }

        RETVAL = conv_opts;
    OUTPUT:
        RETVAL

SV *
hash2xml(...)
    PREINIT:
        conv_opts_t   *conv_opts = NULL;
        convert_ctx_t  ctx;
        SV            *p, *hash, *result;
        int            nparam    = 0;
    CODE:
        /* get object reference */
        if (nparam >= items)
            croak("Invalid parameters");

        p = ST(nparam);
        if ( sv_isa(p, "XML::Hash::XS") ) {
            /* reference to object */
            IV tmp = SvIV((SV *) SvRV(p));
            conv_opts = INT2PTR(conv_opts_t *, tmp);
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
        memset(&ctx, 0, sizeof(convert_ctx_t));
        if (conv_opts == NULL) {
            /* read global options */
            XMLHash_conv_init_options(&ctx.opts);
        }
        else {
            /* read options from object */
            memcpy(&ctx.opts, conv_opts, sizeof(conv_opts_t));
        }
        if (nparam < items) {
            XMLHash_conv_parse_param(&ctx.opts, nparam, ax, items);
        }

        /* run */
        if (ctx.opts.doc) {
            result = XMLHash_hash2dom(&ctx, hash);
        }
        else {
            result = XMLHash_hash2xml(&ctx, hash);
        }

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
        conv_opts_t *conv;
    CODE:
        XMLHash_conv_destroy(conv);
