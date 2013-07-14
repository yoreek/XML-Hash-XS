#ifndef _XMLHASH_CONVERTER_NO_ATTR_H_
#define _XMLHASH_CONVERTER_NO_ATTR_H_

#include "xmlhash_converter.h"

INLINE void XMLHash_write_item_no_attr(convert_ctx_t *ctx, char *name, SV *value);
INLINE void XMLHash_write_item_no_attr2doc(convert_ctx_t *ctx, char *name, SV *value, xmlNodePtr rootNode);
INLINE void XMLHash_write_hash_no_attr(convert_ctx_t *ctx, char *name, SV *hash);
INLINE void XMLHash_write_hash_no_attr2doc(convert_ctx_t *ctx, char *name, SV *hash, xmlNodePtr rootNode);

INLINE void
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
        XMLHash_write_tag(ctx, TAG_EMPTY, name, ctx->opts.indent, ctx->opts.indent);
        return;
    }

    XMLHash_write_tag(ctx, TAG_OPEN, name, ctx->opts.indent, ctx->opts.indent);

    ctx->indent_count++;

    hv_iterinit(hv);

    if (ctx->opts.canonical) {
        hash_entity_t a[len];

        i = 0;
        while ((value = hv_iternextsv(hv, &key, &keylen))) {
            a[i].value = value;
            a[i].key   = key;
            i++;
        }
        len = i;

        qsort(&a, len, sizeof(hash_entity_t), XMLHash_cmpstring);

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

    XMLHash_write_tag(ctx, TAG_CLOSE, name, ctx->opts.indent, ctx->opts.indent);
}

INLINE void
XMLHash_write_item_no_attr(convert_ctx_t *ctx, char *name, SV *value)
{
    I32            i, len;
    int            raw;
    SV            *value_ref = NULL;
    char          *str;
    STRLEN         str_len;
    conv_writer_t *writer = ctx->writer;

    XMLHash_resolve_value(ctx, &value, &value_ref, &raw);

    switch (SvTYPE(value)) {
        case SVt_NULL:
            XMLHash_write_tag(ctx, TAG_EMPTY, name, ctx->opts.indent, ctx->opts.indent);
            break;
        case SVt_IV:
        case SVt_PVIV:
        case SVt_PVNV:
        case SVt_NV:
        case SVt_PV:
            /* integer, double, scalar */
            XMLHash_write_tag(ctx, TAG_OPEN, name, ctx->opts.indent, 0);
            str = SvPV(value, str_len);
            if (raw) {
                BUFFER_WRITE_STRING(str, str_len);
            }
            else {
                BUFFER_WRITE_ESCAPE(str, str_len);
            }
            XMLHash_write_tag(ctx, TAG_CLOSE, name, 0, ctx->opts.indent);
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
                str = SvPV(value, str_len);
                XMLHash_write_tag(ctx, TAG_OPEN, name, ctx->opts.indent, 0);
                if (raw) {
                    BUFFER_WRITE_STRING(str, str_len);
                }
                else {
                    BUFFER_WRITE_ESCAPE(str, str_len);
                }
                XMLHash_write_tag(ctx, TAG_CLOSE, name, 0, ctx->opts.indent);
                break;
            }
        default:
            XMLHash_write_tag(ctx, TAG_EMPTY, name, ctx->opts.indent, ctx->opts.indent);
    }

    ctx->recursion_depth--;
}

INLINE void
XMLHash_write_hash_no_attr2doc(convert_ctx_t *ctx, char *name, SV *hash, xmlNodePtr rootNode)
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

    rootNode = XMLHash_write_tag2doc(name, NULL, rootNode);

    if (len == 0) {
        return;
    }

    hv_iterinit(hv);

    if (ctx->opts.canonical) {
        hash_entity_t a[len];

        i = 0;
        while ((value = hv_iternextsv(hv, &key, &keylen))) {
            a[i].value = value;
            a[i].key   = key;
            i++;
        }
        len = i;

        qsort(&a, len, sizeof(hash_entity_t), XMLHash_cmpstring);

        for (i = 0; i < len; i++) {
            key   = a[i].key;
            value = a[i].value;
            XMLHash_write_item_no_attr2doc(ctx, key, value, rootNode);
        }
    }
    else {
        while ((value = hv_iternextsv(hv, &key, &keylen))) {
            XMLHash_write_item_no_attr2doc(ctx, key, value, rootNode);
        }
    }
}

INLINE void
XMLHash_write_item_no_attr2doc(convert_ctx_t *ctx, char *name, SV *value, xmlNodePtr rootNode)
{
    I32        i, len;
    int        raw;
    SV        *value_ref = NULL;
    char      *str;
    STRLEN     str_len;

    XMLHash_resolve_value(ctx, &value, &value_ref, &raw);

    switch (SvTYPE(value)) {
        case SVt_NULL:
            (void) XMLHash_write_tag2doc(name, NULL, rootNode);
            break;
        case SVt_IV:
        case SVt_PVIV:
        case SVt_PVNV:
        case SVt_NV:
        case SVt_PV:
            /* integer, double, scalar */
            str = SvPV(value, str_len);
            if (raw) {
                (void) XMLHash_write_tag2doc(name, str, rootNode);
            }
            else {
                (void) XMLHash_write_tag2doc_escaped(name, str, rootNode);
            }
            break;
        case SVt_PVAV:
            /* array */
            len = av_len((AV *) value);
            for (i = 0; i <= len; i++) {
                XMLHash_write_item_no_attr2doc(ctx, name, *av_fetch((AV *) value, i, 0), rootNode);
            }
            break;
        case SVt_PVHV:
            /* hash */
            XMLHash_write_hash_no_attr2doc(ctx, name, value_ref, rootNode);
            break;
        case SVt_PVMG:
            /* blessed */
            if (SvOK(value)) {
                str = SvPV(value, str_len);
                if (raw) {
                    (void) XMLHash_write_tag2doc(name, str, rootNode);
                }
                else {
                    (void) XMLHash_write_tag2doc_escaped(name, str, rootNode);
                }
                break;
            }
        default:
            (void) XMLHash_write_tag2doc(name, NULL, rootNode);
    }

    ctx->recursion_depth--;
}

#endif
