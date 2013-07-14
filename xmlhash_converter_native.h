#ifndef _XMLHASH_CONVERTER_NATIVE_H_
#define _XMLHASH_CONVERTER_NATIVE_H_

#include "xmlhash_converter.h"

INLINE int XMLHash_write_item(convert_ctx_t *ctx, char *name, SV *value, int flag);
INLINE void XMLHash_write_hash(convert_ctx_t *ctx, char *name, SV *hash);
INLINE void XMLHash_write_hash2doc(convert_ctx_t *ctx, char *name, SV *hash, xmlNodePtr rootNode);

INLINE int
XMLHash_write_item(convert_ctx_t *ctx, char *name, SV *value, int flag)
{
    int            count = 0, raw = 0;
    I32            len, i;
    SV            *value_ref = NULL;
    conv_writer_t *writer = ctx->writer;

    if (ctx->opts.content[0] != '\0' && strcmp(name, ctx->opts.content) == 0) {
        flag = flag | FLAG_CONTENT;
    }

    XMLHash_resolve_value(ctx, &value, &value_ref, &raw);

    switch (SvTYPE(value)) {
        case SVt_NULL:
            if (flag & FLAG_SIMPLE && flag & FLAG_COMPLEX) {
                XMLHash_write_tag(ctx, TAG_EMPTY, name, ctx->opts.indent, ctx->opts.indent);
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
                XMLHash_write_tag(ctx, TAG_OPEN, name, ctx->opts.indent, 0);
                BUFFER_WRITE_ESCAPE(SvPV_nolen(value), -1);
                XMLHash_write_tag(ctx, TAG_CLOSE, name, 0, ctx->opts.indent);
                ctx->indent_count--;
            }
            else if (flag & FLAG_COMPLEX && flag & FLAG_CONTENT) {
                ctx->indent_count++;
                XMLHash_write_content(ctx, SvPV_nolen(value), ctx->opts.indent, ctx->opts.indent);
                ctx->indent_count--;
            }
            else if (flag & FLAG_SIMPLE && !(flag & FLAG_CONTENT)) {
                XMLHash_write_attribute_element(ctx, name, (char *) SvPV_nolen(value));
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
                    XMLHash_write_tag(ctx, TAG_OPEN, name, ctx->opts.indent, 0);
                    BUFFER_WRITE_ESCAPE(SvPV_nolen(value), -1);
                    XMLHash_write_tag(ctx, TAG_CLOSE, name, 0, ctx->opts.indent);
                    ctx->indent_count--;
                }
                else if (flag & FLAG_COMPLEX && flag & FLAG_CONTENT) {
                    ctx->indent_count++;
                    XMLHash_write_content(ctx, SvPV_nolen(value), ctx->opts.indent, ctx->opts.indent);
                    ctx->indent_count--;
                }
                else if (flag & FLAG_SIMPLE && !(flag & FLAG_CONTENT)) {
                    XMLHash_write_attribute_element(ctx, name, (char *) SvPV_nolen(value));
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

INLINE void
XMLHash_write_hash(convert_ctx_t *ctx, char *name, SV *hash)
{
    SV            *value;
    HV            *hv;
    char          *key;
    I32            keylen;
    int            i, done, len;
    conv_writer_t *writer = ctx->writer;

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

    XMLHash_write_tag(ctx, TAG_START, name, ctx->opts.indent, 0);

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

        done = 0;
        for (i = 0; i < len; i++) {
            key   = a[i].key;
            value = a[i].value;
            done += XMLHash_write_item(ctx, key, value, FLAG_SIMPLE);
        }

        if (done == len) {
            if (ctx->opts.indent) {
                BUFFER_WRITE_CONSTANT("/>\n");
            }
            else {
                BUFFER_WRITE_CONSTANT("/>");
            }
        }
        else {
            if (ctx->opts.indent) {
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

            XMLHash_write_tag(ctx, TAG_CLOSE, name, ctx->opts.indent, ctx->opts.indent);
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
            if (ctx->opts.indent) {
                BUFFER_WRITE_CONSTANT("/>\n");
            }
            else {
                BUFFER_WRITE_CONSTANT("/>");
            }
        }
        else {
            if (ctx->opts.indent) {
                BUFFER_WRITE_CONSTANT(">\n");
            }
            else {
                BUFFER_WRITE_CONSTANT(">");
            }

            while ((value = hv_iternextsv(hv, &key, &keylen))) {
                XMLHash_write_item(ctx, key, value, FLAG_COMPLEX);
            }


            XMLHash_write_tag(ctx, TAG_CLOSE, name, ctx->opts.indent, ctx->opts.indent);
        }
    }
}

int
XMLHash_write_item2doc(convert_ctx_t *ctx, char *name, SV *value, int flag, xmlNodePtr rootNode)
{
    int            count = 0, raw = 0;
    I32            len, i;
    SV            *value_ref = NULL;

    if (ctx->opts.content[0] != '\0' && strcmp(name, ctx->opts.content) == 0) {
        flag = flag | FLAG_CONTENT;
    }

    XMLHash_resolve_value(ctx, &value, &value_ref, &raw);

    switch (SvTYPE(value)) {
        case SVt_NULL:
            if (flag & FLAG_SIMPLE && flag & FLAG_COMPLEX) {
                (void) xmlNewChild(rootNode, NULL, BAD_CAST name, NULL);
            }
            else if (flag & FLAG_SIMPLE && !(flag & FLAG_CONTENT)) {
                xmlSetProp(rootNode, BAD_CAST name, NULL);
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
                (void) xmlNewTextChild(rootNode, NULL, BAD_CAST name, BAD_CAST SvPV_nolen(value));
            }
            else if (flag & FLAG_COMPLEX && flag & FLAG_CONTENT) {
                XMLHash_write_content2doc(ctx, SvPV_nolen(value), rootNode);
            }
            else if (flag & FLAG_SIMPLE && !(flag & FLAG_CONTENT)) {
                (void) xmlSetProp(rootNode, BAD_CAST name, BAD_CAST SvPV_nolen(value));
                count++;
            }
            break;
        case SVt_PVAV:
            /* array */
            if (flag & FLAG_COMPLEX) {
                len = av_len((AV *) value);
                for (i = 0; i <= len; i++) {
                    XMLHash_write_item2doc(ctx, name, *av_fetch((AV *) value, i, 0), FLAG_SIMPLE | FLAG_COMPLEX, rootNode);
                }
                count++;
            }
            break;
        case SVt_PVHV:
            /* hash */
            if (flag & FLAG_COMPLEX) {
                XMLHash_write_hash2doc(ctx, name, value_ref, rootNode);
                count++;
            }
            break;
        case SVt_PVMG:
            /* blessed */
            if (SvOK(value)) {
                if (flag & FLAG_SIMPLE && flag & FLAG_COMPLEX) {
                    (void) xmlNewTextChild(rootNode, NULL, BAD_CAST name, BAD_CAST SvPV_nolen(value));
                }
                else if (flag & FLAG_COMPLEX && flag & FLAG_CONTENT) {
                    XMLHash_write_content2doc(ctx, SvPV_nolen(value), rootNode);
                }
                else if (flag & FLAG_SIMPLE && !(flag & FLAG_CONTENT)) {
                    (void) xmlSetProp(rootNode, BAD_CAST name, BAD_CAST SvPV_nolen(value));
                    count++;
                }
                break;
            }
        default:
            if (flag & FLAG_SIMPLE && !(flag & FLAG_CONTENT)) {
                (void) xmlSetProp(rootNode, BAD_CAST name, NULL);
                count++;
            }
    }

    ctx->recursion_depth--;

    return count;
}

INLINE void
XMLHash_write_hash2doc(convert_ctx_t *ctx, char *name, SV *hash, xmlNodePtr rootNode)
{
    SV            *value;
    HV            *hv;
    char          *key;
    I32            keylen;
    int            i, done, len;

    if (!SvROK(hash)) {
        warn("parameter is not reference\n");
        return;
    }

    hv  = (HV *) SvRV(hash);
    len = HvUSEDKEYS(hv);

    if (len == 0) {
        (void) xmlNewChild(rootNode, NULL, BAD_CAST name, NULL);
        return;
    }

    rootNode = xmlNewChild(rootNode, NULL, BAD_CAST name, NULL);

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

        done = 0;
        for (i = 0; i < len; i++) {
            key   = a[i].key;
            value = a[i].value;
            done += XMLHash_write_item2doc(ctx, key, value, FLAG_SIMPLE, rootNode);
        }

        if (done != len) {
            for (i = 0; i < len; i++) {
                key   = a[i].key;
                value = a[i].value;
                XMLHash_write_item2doc(ctx, key, value, FLAG_COMPLEX, rootNode);
            }
        }
    }
    else {
        done = 0;
        len  = 0;

        while ((value = hv_iternextsv(hv, &key, &keylen))) {
            done += XMLHash_write_item2doc(ctx, key, value, FLAG_SIMPLE, rootNode);
            len++;
        }

        if (done != len) {
            while ((value = hv_iternextsv(hv, &key, &keylen))) {
                XMLHash_write_item2doc(ctx, key, value, FLAG_COMPLEX, rootNode);
            }
        }
    }
}

#endif
