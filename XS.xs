#include "EXTERN.h"
#include "perl.h"
#define NO_XSLOCKS
#include "XSUB.h"
#include "ppport.h"

#include <libxml/parser.h>

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

#define FLAG_SIMPLE                     1
#define FLAG_COMPLEX                    2
#define FLAG_CONTENT                    4

#define MAX_RECURSION_DEPTH             128

#define BUFFER_WRITE(str, len)          xmlOutputBufferWrite(ctx->buf, len, str)
#define BUFFER_WRITE_CONSTANT(str)      xmlOutputBufferWrite(ctx->buf, sizeof(str) - 1, str)
#define BUFFER_WRITE_STRING(str)        xmlOutputBufferWriteString(ctx->buf, BAD_CAST str)
#define BUFFER_WRITE_ESCAPE(str)        xmlOutputBufferWriteEscape(ctx->buf, BAD_CAST str, NULL)
#define BUFFER_WRITE_ESCAPE_ATTR(str)   xmlOutputBufferWriteEscapeAttr(ctx->buf, BAD_CAST str)
#define BUFFER_WRITE_QUOTED(str)        xmlBufferWriteQuotedString(ctx->buf->buffer, BAD_CAST str)

typedef enum {
    TAG_OPEN,
    TAG_CLOSE,
    TAG_EMPTY,
    TAG_START,
    TAG_END
} tagType;

typedef struct {
    char *key;
    void *value;
} hash_entity_t;

typedef struct _stash_entity_t stash_entity_t;
struct _stash_entity_t {
    void                   *data;
    struct _stash_entity_t *next;
};

typedef struct {
    char              *version;
    char              *encoding;
    char              *root;
    int                recursion_depth;
    int                indent;
    int                indent_count;
    int                canonical;
    int                use_attr;
    char              *content;
    int                xml_decl;
    xmlOutputBufferPtr buf;
    stash_entity_t     stash;
} convert_ctx_t;

const char indent_string[60] = "                                                            ";

void XMLHash_write_item_no_attr(convert_ctx_t *ctx, char *name, SV *value);
int XMLHash_write_item(convert_ctx_t *ctx, char *name, SV *value, int flag);
void XMLHash_write_hash(convert_ctx_t *ctx, char *name, SV *hash);

static int
cmpstringp(const void *p1, const void *p2)
{
    hash_entity_t *e1, *e2;
    e1 = (hash_entity_t *) p1;
    e2 = (hash_entity_t *) p2;
    return strcmp(e1->key, e2->key);
}

int
XMLHash_write_handler(void *fp, char *buffer, int len)
{
    if ( buffer != NULL && len > 0)
        PerlIO_write(fp, buffer, len);

    return len;
}

int
XMLHash_write_tied_handler(void *obj, char *buffer, int len)
{
    if ( buffer != NULL && len > 0) {
        dSP;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        EXTEND(SP, 2);
        PUSHs((SV *)obj);
        PUSHs(sv_2mortal(newSVpv(buffer, len)));
        PUTBACK;

        call_method("PRINT", G_SCALAR);

        FREETMPS;
        LEAVE;
    }

    return len;
}

int
XMLHash_close_handler(void *fh)
{
    return 1;
}

void
XMLHash_write_tag(convert_ctx_t *ctx, tagType type, char *name, int indent, int lf)
{
    int indent_len;

    if (indent) {
        indent_len = ctx->indent_count * indent;
        if (indent_len > sizeof(indent_string))
            indent_len = sizeof(indent_string);

        BUFFER_WRITE(indent_string, indent_len);
    }

    if (type == TAG_CLOSE) {
        BUFFER_WRITE_CONSTANT("</");
    }
    else {
        BUFFER_WRITE_CONSTANT("<");
    }

    if (name[0] >= '1' && name[0] <= '9')
        BUFFER_WRITE_CONSTANT("_");

    BUFFER_WRITE_STRING(name);

    if (type == TAG_EMPTY) {
        BUFFER_WRITE_CONSTANT("/>");
    }
    else if (type == TAG_CLOSE || type == TAG_OPEN) {
        BUFFER_WRITE_CONSTANT(">");
    }

    if (lf)
        BUFFER_WRITE_CONSTANT("\n");
}

void
XMLHash_write_content(convert_ctx_t *ctx, char *value, int indent, int lf)
{
    int indent_len;

    if (indent) {
        indent_len = ctx->indent_count * indent;
        if (indent_len > sizeof(indent_string))
            indent_len = sizeof(indent_string);

        BUFFER_WRITE(indent_string, indent_len);
    }

    BUFFER_WRITE_ESCAPE(value);

    if (lf)
        BUFFER_WRITE_CONSTANT("\n");
}

void
xmlOutputBufferWriteEscapeAttr(xmlOutputBufferPtr buf, const xmlChar * string)
{
    xmlChar *base, *cur;

    if (string == NULL)
        return;
    base = cur = (xmlChar *) string;
    while (*cur != 0) {
        if (*cur == '\n') {
            if (base != cur)
                xmlOutputBufferWrite(buf, cur - base, base);
            xmlOutputBufferWrite(buf, 5, BAD_CAST "&#10;");
            cur++;
            base = cur;
        } else if (*cur == '\r') {
            if (base != cur)
                xmlOutputBufferWrite(buf, cur - base, base);
            xmlOutputBufferWrite(buf, 5, BAD_CAST "&#13;");
            cur++;
            base = cur;
        } else if (*cur == '\t') {
            if (base != cur)
                xmlOutputBufferWrite(buf, cur - base, base);
            xmlOutputBufferWrite(buf, 4, BAD_CAST "&#9;");
            cur++;
            base = cur;
        } else if (*cur == '"') {
            if (base != cur)
                xmlOutputBufferWrite(buf, cur - base, base);
            xmlOutputBufferWrite(buf, 6, BAD_CAST "&quot;");
            cur++;
            base = cur;
        } else if (*cur == '<') {
            if (base != cur)
                xmlOutputBufferWrite(buf, cur - base, base);
            xmlOutputBufferWrite(buf, 4, BAD_CAST "&lt;");
            cur++;
            base = cur;
        } else if (*cur == '>') {
            if (base != cur)
                xmlOutputBufferWrite(buf, cur - base, base);
            xmlOutputBufferWrite(buf, 4, BAD_CAST "&gt;");
            cur++;
            base = cur;
        } else if (*cur == '&') {
            if (base != cur)
                xmlOutputBufferWrite(buf, cur - base, base);
            xmlOutputBufferWrite(buf, 5, BAD_CAST "&amp;");
            cur++;
            base = cur;
        } else {
            cur++;
        }
    }
    if (base != cur)
        xmlOutputBufferWrite(buf, cur - base, base);
}

void
XMLHash_write_attribute_element(convert_ctx_t *ctx, char *name, xmlChar *value)
{
    BUFFER_WRITE_CONSTANT(" ");
    BUFFER_WRITE_STRING(name);
    BUFFER_WRITE_CONSTANT("=\"");
    BUFFER_WRITE_ESCAPE_ATTR(value);
    BUFFER_WRITE_CONSTANT("\"");
}

void
XMLHash_stash_push(stash_entity_t *stash, void *data)
{
    stash_entity_t *ent;
    ent = malloc(sizeof(stash_entity_t));
    if (ent == NULL)
        croak("Malloc error");

    ent->data   = data;
    ent->next   = stash->next;
    stash->next = ent;
}

void
XMLHash_stash_clean(stash_entity_t *stash)
{
    stash_entity_t *ent;

    while (stash->next != NULL) {
        ent = stash->next;
        SvREFCNT_dec((SV *)ent->data);
        stash->next = ent->next;
        free(ent);
    }
}

void
XMLHash_resolve_value(convert_ctx_t *ctx, SV **value, SV **value_ref, int *raw)
{
    int count;
    svtype svt;
    SV *sv;

    *raw = 0;

    while ( *value && SvROK(*value) ) {
        if (++ctx->recursion_depth > MAX_RECURSION_DEPTH)
            croak("Maximum recursion depth exceeded");

        *value_ref = *value;
        *value     = SvRV(*value);
        sv         = *value;

        if (expect_false( SvOBJECT(sv) )) {
            /* object */
            GV *to_string = gv_fetchmethod_autoload (SvSTASH (sv), "toString", 0);
            if (to_string) {
                dSP;

                ENTER; SAVETMPS; PUSHMARK (SP);
                XPUSHs (sv_bless (sv_2mortal (newRV_inc (sv)), SvSTASH (sv)));

                // calling with G_SCALAR ensures that we always get a 1 return value
                PUTBACK;
                call_sv ((SV *)GvCV (to_string), G_SCALAR);
                SPAGAIN;

                // catch this surprisingly common error
                if (SvROK (TOPs) && SvRV (TOPs) == sv)
                    croak("%s::toString method returned same object as was passed instead of a new one", HvNAME (SvSTASH (sv)));

                *value = POPs;
                PUTBACK;

                SvREFCNT_inc(*value);

                XMLHash_stash_push(&ctx->stash, *value);

                FREETMPS; LEAVE;

                *raw = 1;

                continue;
            }
        }
        else if(SvTYPE(*value) == SVt_PVCV) {
            /* code ref */
            *raw = 0;

            dSP;

            ENTER;
            SAVETMPS;
            count = call_sv(*value, G_SCALAR|G_NOARGS);

            SPAGAIN;

            if (count == 1) {
                *value = POPs;

                SvREFCNT_inc(*value);

                XMLHash_stash_push(&ctx->stash, *value);

                PUTBACK;

                FREETMPS;
                LEAVE;

                continue;
            }
            else {
                *value = NULL;
            }
        }
    }
}

void
XMLHash_write_hash_no_attr(convert_ctx_t *ctx, char *name, SV *hash)
{
    SV   *value;
    HV   *hv;
    char *key;
    I32   keylen;
    int   i, len;

    if (!SvROK(hash)) {
        warn("parameter is not reference\n");
        return;
    }

    hv  = (HV *) SvRV(hash);
    len = HvUSEDKEYS(hv);

    if (len == 0) {
        XMLHash_write_tag(ctx, TAG_EMPTY, name, ctx->indent, ctx->indent);
        return;
    }

    XMLHash_write_tag(ctx, TAG_OPEN, name, ctx->indent, ctx->indent);

    ctx->indent_count++;

    hv_iterinit(hv);

    if (ctx->canonical) {
        hash_entity_t a[len];

        i = 0;
        while ((value = hv_iternextsv(hv, &key, &keylen))) {
            a[i].value = value;
            a[i].key   = key;
            i++;
        }
        len = i;

        qsort(&a, len, sizeof(hash_entity_t), cmpstringp);

        for (i = 0; i < len; i++) {
            key   = a[i].key;
            value = a[i].value;
            XMLHash_write_item_no_attr(ctx, key, value);
        }
    }
    else {
        while ((value = hv_iternextsv(hv, &key, &keylen))) {
            XMLHash_write_item_no_attr(ctx, key, value);
        }
    }

    ctx->indent_count--;

    XMLHash_write_tag(ctx, TAG_CLOSE, name, ctx->indent, ctx->indent);
}

void
XMLHash_write_item_no_attr(convert_ctx_t *ctx, char *name, SV *value)
{
    I32        i, len;
    int        count, raw;
    SV        *value_ref;

    XMLHash_resolve_value(ctx, &value, &value_ref, &raw);

    switch (SvTYPE(value)) {
        case SVt_NULL:
            XMLHash_write_tag(ctx, TAG_EMPTY, name, ctx->indent, ctx->indent);
            break;
        case SVt_IV:
        case SVt_PVIV:
        case SVt_PVNV:
        case SVt_NV:
        case SVt_PV:
            /* integer, double, scalar */
            XMLHash_write_tag(ctx, TAG_OPEN, name, ctx->indent, 0);
            if (raw) {
                BUFFER_WRITE_STRING(SvPV_nolen(value));
            }
            else {
                BUFFER_WRITE_ESCAPE(SvPV_nolen(value));
            }
            XMLHash_write_tag(ctx, TAG_CLOSE, name, 0, ctx->indent);
            break;
        case SVt_PVAV:
            /* array */
            len = av_len((AV *) value);
            for (i = 0; i <= len; i++) {
                XMLHash_write_item_no_attr(ctx, name, *av_fetch((AV *) value, i, 0));
            }
            break;
        case SVt_PVHV:
            /* hash */
            XMLHash_write_hash_no_attr(ctx, name, value_ref);
            break;
        case SVt_PVMG:
            /* blessed */
            if (SvOK(value)) {
                XMLHash_write_tag(ctx, TAG_OPEN, name, ctx->indent, 0);
                if (raw) {
                    BUFFER_WRITE_STRING(SvPV_nolen(value));
                }
                else {
                    BUFFER_WRITE_ESCAPE(SvPV_nolen(value));
                }
                XMLHash_write_tag(ctx, TAG_CLOSE, name, 0, ctx->indent);
                break;
            }
        default:
            XMLHash_write_tag(ctx, TAG_EMPTY, name, ctx->indent, ctx->indent);
    }

    ctx->recursion_depth--;
}

int
XMLHash_write_item(convert_ctx_t *ctx, char *name, SV *value, int flag)
{
    int        count = 0, raw = 0;
    I32        len, i;
    SV        *value_ref;

    if (ctx->content != NULL && strcmp(name, ctx->content) == 0) {
        flag = flag | FLAG_CONTENT;
    }

    XMLHash_resolve_value(ctx, &value, &value_ref, &raw);

    switch (SvTYPE(value)) {
        case SVt_NULL:
            if (flag & FLAG_SIMPLE && flag & FLAG_COMPLEX) {
                XMLHash_write_tag(ctx, TAG_EMPTY, name, ctx->indent, ctx->indent);
            }
            else if (flag & FLAG_SIMPLE && !(flag & FLAG_CONTENT)) {
                XMLHash_write_attribute_element(ctx, name, NULL);
                count++;
            }
            break;
        case SVt_IV:
        case SVt_PVIV:
        case SVt_PVNV:
        case SVt_NV:
        case SVt_PV:
            /* integer, double, scalar */
            if (flag & FLAG_SIMPLE && flag & FLAG_COMPLEX) {
                ctx->indent_count++;
                XMLHash_write_tag(ctx, TAG_OPEN, name, ctx->indent, 0);
                BUFFER_WRITE_ESCAPE(SvPV_nolen(value));
                XMLHash_write_tag(ctx, TAG_CLOSE, name, 0, ctx->indent);
                ctx->indent_count--;
            }
            else if (flag & FLAG_COMPLEX && flag & FLAG_CONTENT) {
                ctx->indent_count++;
                XMLHash_write_content(ctx, SvPV_nolen(value), ctx->indent, ctx->indent);
                ctx->indent_count--;
            }
            else if (flag & FLAG_SIMPLE && !(flag & FLAG_CONTENT)) {
                XMLHash_write_attribute_element(ctx, name, (xmlChar *) SvPV_nolen(value));
                count++;
            }
            break;
        case SVt_PVAV:
            /* array */
            if (flag & FLAG_COMPLEX) {
                len = av_len((AV *) value);
                for (i = 0; i <= len; i++) {
                    XMLHash_write_item(ctx, name, *av_fetch((AV *) value, i, 0), FLAG_SIMPLE | FLAG_COMPLEX);
                }
                count++;
            }
            break;
        case SVt_PVHV:
            /* hash */
            if (flag & FLAG_COMPLEX) {
                ctx->indent_count++;
                XMLHash_write_hash(ctx, name, value_ref);
                ctx->indent_count--;
                count++;
            }
            break;
        case SVt_PVMG:
            /* blessed */
            if (SvOK(value)) {
                if (flag & FLAG_SIMPLE && flag & FLAG_COMPLEX) {
                    ctx->indent_count++;
                    XMLHash_write_tag(ctx, TAG_OPEN, name, ctx->indent, 0);
                    BUFFER_WRITE_ESCAPE(SvPV_nolen(value));
                    XMLHash_write_tag(ctx, TAG_CLOSE, name, 0, ctx->indent);
                    ctx->indent_count--;
                }
                else if (flag & FLAG_COMPLEX && flag & FLAG_CONTENT) {
                    ctx->indent_count++;
                    XMLHash_write_content(ctx, SvPV_nolen(value), ctx->indent, ctx->indent);
                    ctx->indent_count--;
                }
                else if (flag & FLAG_SIMPLE && !(flag & FLAG_CONTENT)) {
                    XMLHash_write_attribute_element(ctx, name, (xmlChar *) SvPV_nolen(value));
                    count++;
                }
                break;
            }
        default:
            if (flag & FLAG_SIMPLE && !(flag & FLAG_CONTENT)) {
                XMLHash_write_attribute_element(ctx, name, NULL);
                count++;
            }
    }

    ctx->recursion_depth--;

    return count;
}

void
XMLHash_write_hash(convert_ctx_t *ctx, char *name, SV *hash)
{
    SV   *value;
    HV   *hv;
    char *key;
    I32   keylen;
    int   i, done, len;

    if (!SvROK(hash)) {
        warn("parameter is not reference\n");
        return;
    }

    hv  = (HV *) SvRV(hash);
    len = HvUSEDKEYS(hv);

    if (len == 0) {
        XMLHash_write_tag(ctx, TAG_EMPTY, name, ctx->indent, ctx->indent);
        return;
    }

    XMLHash_write_tag(ctx, TAG_START, name, ctx->indent, 0);

    hv_iterinit(hv);

    if (ctx->canonical) {
        hash_entity_t a[len];

        i = 0;
        while ((value = hv_iternextsv(hv, &key, &keylen))) {
            a[i].value = value;
            a[i].key   = key;
            i++;
        }
        len = i;

        qsort(&a, len, sizeof(hash_entity_t), cmpstringp);

        done = 0;
        for (i = 0; i < len; i++) {
            key   = a[i].key;
            value = a[i].value;
            done += XMLHash_write_item(ctx, key, value, FLAG_SIMPLE);
        }

        if (done == len) {
            if (ctx->indent) {
                BUFFER_WRITE_CONSTANT("/>\n");
            }
            else {
                BUFFER_WRITE_CONSTANT("/>");
            }
        }
        else {
            if (ctx->indent) {
                BUFFER_WRITE_CONSTANT(">\n");
            }
            else {
                BUFFER_WRITE_CONSTANT(">");
            }

            for (i = 0; i < len; i++) {
                key   = a[i].key;
                value = a[i].value;
                XMLHash_write_item(ctx, key, value, FLAG_COMPLEX);
            }

            XMLHash_write_tag(ctx, TAG_CLOSE, name, ctx->indent, ctx->indent);
        }
    }
    else {
        done = 0;
        len  = 0;

        while ((value = hv_iternextsv(hv, &key, &keylen))) {
            done += XMLHash_write_item(ctx, key, value, FLAG_SIMPLE);
            len++;
        }

        if (done == len) {
            if (ctx->indent) {
                BUFFER_WRITE_CONSTANT("/>\n");
            }
            else {
                BUFFER_WRITE_CONSTANT("/>");
            }
        }
        else {
            if (ctx->indent) {
                BUFFER_WRITE_CONSTANT(">\n");
            }
            else {
                BUFFER_WRITE_CONSTANT(">");
            }

            while ((value = hv_iternextsv(hv, &key, &keylen))) {
                XMLHash_write_item(ctx, key, value, FLAG_COMPLEX);
            }


            XMLHash_write_tag(ctx, TAG_CLOSE, name, ctx->indent, ctx->indent);
        }
    }
}

void
XMLHash_hash2xml(convert_ctx_t *ctx, SV *hash)
{
    if (ctx->xml_decl) {
        /* xml declaration */
        BUFFER_WRITE_CONSTANT("<?xml version=");
        BUFFER_WRITE_QUOTED(ctx->version);
        BUFFER_WRITE_CONSTANT(" encoding=");
        BUFFER_WRITE_QUOTED(ctx->encoding);
        BUFFER_WRITE_CONSTANT("?>\n");
    }

    dXCPT;

    XCPT_TRY_START {
        if (ctx->use_attr) {
            XMLHash_write_hash(ctx, ctx->root, hash);
        }
        else {
            XMLHash_write_hash_no_attr(ctx, ctx->root, hash);
        }
        XMLHash_stash_clean(&ctx->stash);
    } XCPT_TRY_END

    XCPT_CATCH
    {
        XMLHash_stash_clean(&ctx->stash);
        xmlOutputBufferClose(ctx->buf);
        XCPT_RETHROW;
    }

}

MODULE = XML::Hash::XS PACKAGE = XML::Hash::XS

PROTOTYPES: DISABLE

SV *
_hash2xml2string(hash, root, version, encoding, indent, canonical, use_attr, content, xml_decl)
        SV   *hash;
        char *root;
        char *version;
        char *encoding;
        I32   indent;
        I32   canonical;
        I32   use_attr;
        SV   *content;
        I32   xml_decl;
    INIT:
        xmlChar                   *result    = NULL;
        int                        len       = 0;
        xmlCharEncodingHandlerPtr  conv_hdlr = NULL;
        convert_ctx_t              ctx;
    CODE:
        RETVAL = &PL_sv_undef;

        memset(&ctx, 0, sizeof(convert_ctx_t));

        ctx.root            = root;
        ctx.version         = version;
        ctx.encoding        = encoding;
        ctx.indent          = indent;
        ctx.canonical       = canonical;
        ctx.use_attr        = use_attr;
        ctx.xml_decl        = xml_decl;

        if ( SvOK(content) )
            ctx.content = SvPV_nolen(content);

        conv_hdlr = xmlFindCharEncodingHandler(encoding);
        if ( conv_hdlr == NULL )
            croak("Unknown encoding");

        if ((ctx.buf = xmlAllocOutputBuffer(conv_hdlr)) == NULL )
            croak("Buffer allocation error");

        XMLHash_hash2xml(&ctx, hash);

        xmlOutputBufferFlush(ctx.buf);

        if (ctx.buf->conv != NULL) {
            len    = ctx.buf->conv->use;
            result = xmlStrndup(ctx.buf->conv->content, len);
        }
        else {
            len    = ctx.buf->buffer->use;
            result = xmlStrndup(ctx.buf->buffer->content, len);
        }

        (void) xmlOutputBufferClose(ctx.buf);

        if ((result == NULL) && (len > 0)) {
            len = 0;
            croak("Buffer creating output");
        }

        if (result == NULL) {
            warn("Failed to convert doc to string");
            XSRETURN_UNDEF;
        }
        else {
            RETVAL = newSVpvn( (const char *)result, len );
            xmlFree(result);
        }
    OUTPUT:
        RETVAL

int
_hash2xml2fh(fh, hash, root, version, encoding, indent, canonical, use_attr, content, xml_decl)
        void *fh;
        SV   *hash;
        char *root;
        char *version;
        char *encoding;
        I32   indent;
        I32   canonical;
        I32   use_attr;
        SV   *content;
        I32   xml_decl;
    INIT:
        xmlOutputBufferPtr         buf  = NULL;
        xmlCharEncodingHandlerPtr  conv_hdlr = NULL;
        MAGIC                     *mg;
        PerlIO                    *fp;
        SV                        *obj;
        GV                        *gv = (GV *)fh;
        IO                        *io = GvIO(gv);
        convert_ctx_t              ctx;
    CODE:
        memset(&ctx, 0, sizeof(convert_ctx_t));

        ctx.root            = root;
        ctx.version         = version;
        ctx.encoding        = encoding;
        ctx.indent          = indent;
        ctx.canonical       = canonical;
        ctx.use_attr        = use_attr;
        ctx.xml_decl        = xml_decl;

        if ( SvOK(content) )
            ctx.content = SvPV_nolen(content);

        conv_hdlr = xmlFindCharEncodingHandler(encoding);
        if ( conv_hdlr == NULL )
            croak("Unknown encoding");

        xmlRegisterDefaultOutputCallbacks();

        if (io && (mg = SvTIED_mg((SV *)io, PERL_MAGIC_tiedscalar))) {
            /* tied handle */
            obj = SvTIED_obj(MUTABLE_SV(io), mg);

            ctx.buf = xmlOutputBufferCreateIO(
                (xmlOutputWriteCallback) &XMLHash_write_tied_handler,
                (xmlOutputCloseCallback) &XMLHash_close_handler,
                obj, conv_hdlr
            );
        }
        else {
            /* simple handle */
            fp = IoOFP(io);

            ctx.buf = xmlOutputBufferCreateIO(
                (xmlOutputWriteCallback) &XMLHash_write_handler,
                (xmlOutputCloseCallback) &XMLHash_close_handler,
                fp, conv_hdlr
            );
        }

        if (ctx.buf == NULL)
            croak("Buffer creating error");

        XMLHash_hash2xml(&ctx, hash);

        RETVAL = xmlOutputBufferClose(ctx.buf);
    OUTPUT:
        RETVAL
