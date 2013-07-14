#ifndef _XMLHASH_CONVERTER_H_
#define _XMLHASH_CONVERTER_H_

#include "xmlhash_writer.h"

extern const char indent_string[60];

#define FLAG_SIMPLE                     1
#define FLAG_COMPLEX                    2
#define FLAG_CONTENT                    4
#define FLAG_ATTR_ONLY                  8

#define MAX_RECURSION_DEPTH             128

#define CONV_STR_PARAM_LEN              32

typedef enum {
    CONV_METHOD_NATIVE = 0,
    CONV_METHOD_NATIVE_ATTR_MODE,
    CONV_METHOD_LX
} convMethodType;

struct _conv_opts_t {
    convMethodType         method;

    /* native options */
    char                   version[CONV_STR_PARAM_LEN];
    char                   encoding[CONV_STR_PARAM_LEN];
    char                   root[CONV_STR_PARAM_LEN];
    bool_t                 xml_decl;
    bool_t                 canonical;
    char                   content[CONV_STR_PARAM_LEN];
    int                    indent;
    void                  *output;
    bool_t                 doc;

    /* LX options */
    char                   attr[CONV_STR_PARAM_LEN];
    int                    attr_len;
    char                   text[CONV_STR_PARAM_LEN];
    bool_t                 trim;
    char                   cdata[CONV_STR_PARAM_LEN];
    char                   comm[CONV_STR_PARAM_LEN];
};
typedef struct _conv_opts_t conv_opts_t;

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
    conv_opts_t        opts;
    int                recursion_depth;
    int                indent_count;
    stash_entity_t     stash;
    conv_writer_t     *writer;
} convert_ctx_t;

INLINE void
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

INLINE void
XMLHash_resolve_value(convert_ctx_t *ctx, SV **value, SV **value_ref, int *raw)
{
    int count;
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

                /* calling with G_SCALAR ensures that we always get a 1 return value */
                PUTBACK;
                call_sv ((SV *)GvCV (to_string), G_SCALAR);
                SPAGAIN;

                /* catch this surprisingly common error */
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

            ENTER; SAVETMPS; PUSHMARK (SP);

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

INLINE void
XMLHash_write_tag(convert_ctx_t *ctx, tagType type, char *name, int indent, int lf)
{
    int            indent_len;
    conv_writer_t *writer = ctx->writer;

    if (name == NULL) return;

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

    BUFFER_WRITE_STRING(name, strlen(name));

    if (type == TAG_EMPTY) {
        BUFFER_WRITE_CONSTANT("/>");
    }
    else if (type == TAG_CLOSE || type == TAG_OPEN) {
        BUFFER_WRITE_CONSTANT(">");
    }

    if (lf)
        BUFFER_WRITE_CONSTANT("\n");
}

INLINE void
XMLHash_write_content(convert_ctx_t *ctx, char *value, int indent, int lf)
{
    int            indent_len, str_len;
    conv_writer_t *writer = ctx->writer;

    if (indent) {
        indent_len = ctx->indent_count * indent;
        if (indent_len > sizeof(indent_string))
            indent_len = sizeof(indent_string);

        BUFFER_WRITE(indent_string, indent_len);
    }

    if (ctx->opts.trim) {
        value = XMLHash_trim_string(value, &str_len);
        BUFFER_WRITE_ESCAPE(value, str_len);
    }
    else {
        BUFFER_WRITE_ESCAPE(value, -1);
    }

    if (lf)
        BUFFER_WRITE_CONSTANT("\n");
}

INLINE void
XMLHash_write_cdata(convert_ctx_t *ctx, char *value, int indent, int lf)
{
    int            indent_len, str_len;
    conv_writer_t *writer = ctx->writer;

    if (indent) {
        indent_len = ctx->indent_count * indent;
        if (indent_len > sizeof(indent_string))
            indent_len = sizeof(indent_string);

        BUFFER_WRITE(indent_string, indent_len);
    }

    BUFFER_WRITE_CONSTANT("<![CDATA[");
    if (ctx->opts.trim) {
        value = XMLHash_trim_string(value, &str_len);
        BUFFER_WRITE_STRING(value, str_len);
    }
    else {
        BUFFER_WRITE_STRING(value, strlen(value));
    }
    BUFFER_WRITE_CONSTANT("]]>");

    if (lf)
        BUFFER_WRITE_CONSTANT("\n");
}

INLINE void
XMLHash_write_comment(convert_ctx_t *ctx, char *value, int indent, int lf)
{
    int            indent_len, str_len;
    conv_writer_t *writer = ctx->writer;

    if (indent) {
        indent_len = ctx->indent_count * indent;
        if (indent_len > sizeof(indent_string))
            indent_len = sizeof(indent_string);

        BUFFER_WRITE(indent_string, indent_len);
    }

    BUFFER_WRITE_CONSTANT("<!--");
    if (ctx->opts.trim) {
        value = XMLHash_trim_string(value, &str_len);
        BUFFER_WRITE_STRING(value, str_len);
    }
    else {
        BUFFER_WRITE_STRING(value, strlen(value));
    }
    BUFFER_WRITE_CONSTANT("-->");

    if (lf)
        BUFFER_WRITE_CONSTANT("\n");
}

INLINE void
XMLHash_write_attribute_element(convert_ctx_t *ctx, char *name, char *value)
{
    conv_writer_t *writer;

    if (name == NULL) return;

    writer = ctx->writer;

    BUFFER_WRITE_CONSTANT(" ");
    BUFFER_WRITE_STRING(name, strlen(name));
    if (value == NULL) {
        BUFFER_WRITE_CONSTANT("=\"\"");
    }
    else {
        BUFFER_WRITE_CONSTANT("=\"");
        BUFFER_WRITE_ESCAPE_ATTR(value);
        BUFFER_WRITE_CONSTANT("\"");
    }
}

int XMLHash_cmpstring(const void *p1, const void *p2);
SV *XMLHash_hash2xml(convert_ctx_t *ctx, SV *hash);
SV *XMLHash_hash2dom(convert_ctx_t *ctx, SV *hash);

#endif
