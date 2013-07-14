#ifndef _XMLHASH_CONVERTER_LX_H_
#define _XMLHASH_CONVERTER_LX_H_

#include "xmlhash_converter.h"

INLINE void XMLHash_write_hash_lx(convert_ctx_t *ctx, SV *hash, int flag);
INLINE void XMLHash_write_hash_lx2doc(convert_ctx_t *ctx, SV *hash, int flag, xmlNodePtr rootNode);

INLINE void
XMLHash_write_hash_lx(convert_ctx_t *ctx, SV *value, int flag)
{
    SV            *value_ref = NULL;
    SV            *hash_value, *hash_value_ref;
    HV            *hv;
    char          *key;
    I32            keylen;
    int            len, i, raw = 0;
    conv_writer_t *writer = ctx->writer;

    XMLHash_resolve_value(ctx, &value, &value_ref, &raw);

    switch (SvTYPE(value)) {
        case SVt_NULL:
            XMLHash_write_content(ctx, "", ctx->opts.indent, ctx->opts.indent);
            break;
        case SVt_IV:
        case SVt_PVIV:
        case SVt_PVNV:
        case SVt_NV:
        case SVt_PV:
            if (flag & FLAG_ATTR_ONLY) break;
            XMLHash_write_content(ctx, SvPV_nolen(value), ctx->opts.indent, ctx->opts.indent);
            break;
        case SVt_PVAV:
            len = av_len((AV *) value);
            for (i = 0; i <= len; i++) {
                XMLHash_write_hash_lx(ctx, *av_fetch((AV *) value, i, 0), flag);
            }
            break;
        case SVt_PVHV:
            hv  = (HV *) value;
            len = HvUSEDKEYS(hv);
            hv_iterinit(hv);

            while ((hash_value = hv_iternextsv(hv, &key, &keylen))) {
                if (ctx->opts.cdata[0] != '\0' && strcmp(key, ctx->opts.cdata) == 0) {
                    if (flag & FLAG_ATTR_ONLY) continue;
                    XMLHash_resolve_value(ctx, &hash_value, &hash_value_ref, &raw);
                    switch (SvTYPE(hash_value)) {
                        case SVt_NULL:
                            break;
                        case SVt_IV:
                        case SVt_PVIV:
                        case SVt_PVNV:
                        case SVt_NV:
                        case SVt_PV:
                            XMLHash_write_cdata(ctx, SvPV_nolen(hash_value), ctx->opts.indent, ctx->opts.indent);
                            break;
                        case SVt_PVAV:
                        case SVt_PVHV:
                            break;
                        case SVt_PVMG:
                            if (SvOK(value)) {
                                XMLHash_write_cdata(ctx, SvPV_nolen(hash_value), ctx->opts.indent, ctx->opts.indent);
                                break;
                            }
                        default:
                            XMLHash_write_cdata(ctx, SvPV_nolen(hash_value), ctx->opts.indent, ctx->opts.indent);
                    }
                }
                else if (ctx->opts.text[0] != '\0' && strcmp(key, ctx->opts.text) == 0) {
                    if (flag & FLAG_ATTR_ONLY) continue;
                    XMLHash_resolve_value(ctx, &hash_value, &hash_value_ref, &raw);
                    switch (SvTYPE(hash_value)) {
                        case SVt_NULL:
                            XMLHash_write_content(ctx, "", ctx->opts.indent, ctx->opts.indent);
                            break;
                        case SVt_IV:
                        case SVt_PVIV:
                        case SVt_PVNV:
                        case SVt_NV:
                        case SVt_PV:
                            XMLHash_write_content(ctx, SvPV_nolen(hash_value), ctx->opts.indent, ctx->opts.indent);
                            break;
                        case SVt_PVAV:
                        case SVt_PVHV:
                            break;
                        case SVt_PVMG:
                            if (SvOK(value)) {
                                XMLHash_write_content(ctx, SvPV_nolen(hash_value), ctx->opts.indent, ctx->opts.indent);
                                break;
                            }
                        default:
                            XMLHash_write_content(ctx, SvPV_nolen(hash_value), ctx->opts.indent, ctx->opts.indent);
                    }
                }
                else if (ctx->opts.comm[0] != '\0' && strcmp(key, ctx->opts.comm) == 0) {
                    if (flag & FLAG_ATTR_ONLY) continue;
                    XMLHash_resolve_value(ctx, &hash_value, &hash_value_ref, &raw);
                    switch (SvTYPE(hash_value)) {
                        case SVt_NULL:
                            XMLHash_write_comment(ctx, "", ctx->opts.indent, ctx->opts.indent);
                            break;
                        case SVt_IV:
                        case SVt_PVIV:
                        case SVt_PVNV:
                        case SVt_NV:
                        case SVt_PV:
                            XMLHash_write_comment(ctx, SvPV_nolen(hash_value), ctx->opts.indent, ctx->opts.indent);
                            break;
                        case SVt_PVAV:
                        case SVt_PVHV:
                            break;
                        case SVt_PVMG:
                            if (SvOK(value)) {
                                XMLHash_write_comment(ctx, SvPV_nolen(hash_value), ctx->opts.indent, ctx->opts.indent);
                                break;
                            }
                        default:
                            XMLHash_write_comment(ctx, SvPV_nolen(hash_value), ctx->opts.indent, ctx->opts.indent);
                    }
                }
                else if (ctx->opts.attr[0] != '\0') {
                    if (strncmp(key, ctx->opts.attr, ctx->opts.attr_len) == 0) {
                        if (!(flag & FLAG_ATTR_ONLY)) continue;
                        key += ctx->opts.attr_len;
                        XMLHash_resolve_value(ctx, &hash_value, &hash_value_ref, &raw);
                        switch (SvTYPE(hash_value)) {
                            case SVt_NULL:
                                XMLHash_write_attribute_element(ctx, key, NULL);
                                break;
                            case SVt_IV:
                            case SVt_PVIV:
                            case SVt_PVNV:
                            case SVt_NV:
                            case SVt_PV:
                                XMLHash_write_attribute_element(ctx, key, (char *) SvPV_nolen(hash_value));
                                break;
                            case SVt_PVAV:
                            case SVt_PVHV:
                                break;
                            case SVt_PVMG:
                                if (SvOK(value)) {
                                    XMLHash_write_attribute_element(ctx, key, (char *) SvPV_nolen(hash_value));
                                    break;
                                }
                            default:
                                XMLHash_write_attribute_element(ctx, key, (char *) SvPV_nolen(hash_value));
                        }
                    }
                    else {
                        if (flag & FLAG_ATTR_ONLY) continue;
                        if (SvTYPE(hash_value) == SVt_NULL) {
                            XMLHash_write_tag(ctx, TAG_EMPTY, key, ctx->opts.indent, ctx->opts.indent);
                        }
                        else {
                            XMLHash_write_tag(ctx, TAG_START, key, ctx->opts.indent, 0);
                            XMLHash_write_hash_lx(ctx, hash_value, FLAG_ATTR_ONLY);
                            if (ctx->opts.indent) {
                                BUFFER_WRITE_CONSTANT(">\n");
                            }
                            else {
                                BUFFER_WRITE_CONSTANT(">");
                            }
                            ctx->indent_count++;
                            XMLHash_write_hash_lx(ctx, hash_value, 0);
                            ctx->indent_count--;
                            XMLHash_write_tag(ctx, TAG_CLOSE, key, ctx->opts.indent, ctx->opts.indent);
                        }
                    }
                }
                else {
                    if (SvTYPE(hash_value) == SVt_NULL) {
                        XMLHash_write_tag(ctx, TAG_EMPTY, key, ctx->opts.indent, ctx->opts.indent);
                    }
                    else {
                        XMLHash_write_tag(ctx, TAG_OPEN, key, ctx->opts.indent, ctx->opts.indent);
                        ctx->indent_count++;
                        XMLHash_write_hash_lx(ctx, hash_value, 0);
                        ctx->indent_count--;
                        XMLHash_write_tag(ctx, TAG_CLOSE, key, ctx->opts.indent, ctx->opts.indent);
                    }
                }
            }

            break;
        case SVt_PVMG:
            /* blessed */
            if (flag & FLAG_ATTR_ONLY) break;
            if (SvOK(value)) {
                XMLHash_write_content(ctx, SvPV_nolen(value), ctx->opts.indent, ctx->opts.indent);
                break;
            }
        default:
            if (flag & FLAG_ATTR_ONLY) break;
            XMLHash_write_content(ctx, SvPV_nolen(value), ctx->opts.indent, ctx->opts.indent);
    }

    ctx->recursion_depth--;
}

INLINE void
XMLHash_write_hash_lx2doc(convert_ctx_t *ctx, SV *value, int flag, xmlNodePtr rootNode)
{
    SV            *value_ref = NULL;
    SV            *hash_value, *hash_value_ref;
    HV            *hv;
    char          *key;
    I32            keylen;
    int            len, i, raw = 0;
    xmlNodePtr     node;

    XMLHash_resolve_value(ctx, &value, &value_ref, &raw);

    switch (SvTYPE(value)) {
        case SVt_NULL:
            XMLHash_write_content2doc(ctx, "", rootNode);
            break;
        case SVt_IV:
        case SVt_PVIV:
        case SVt_PVNV:
        case SVt_NV:
        case SVt_PV:
            if (flag & FLAG_ATTR_ONLY) break;
            XMLHash_write_content2doc(ctx, SvPV_nolen(value), rootNode);
            break;
        case SVt_PVAV:
            len = av_len((AV *) value);
            for (i = 0; i <= len; i++) {
                XMLHash_write_hash_lx2doc(ctx, *av_fetch((AV *) value, i, 0), flag, rootNode);
            }
            break;
        case SVt_PVHV:
            hv  = (HV *) value;
            len = HvUSEDKEYS(hv);
            hv_iterinit(hv);

            while ((hash_value = hv_iternextsv(hv, &key, &keylen))) {
                if (ctx->opts.cdata[0] != '\0' && strcmp(key, ctx->opts.cdata) == 0) {
                    if (flag & FLAG_ATTR_ONLY) continue;
                    XMLHash_resolve_value(ctx, &hash_value, &hash_value_ref, &raw);
                    switch (SvTYPE(hash_value)) {
                        case SVt_NULL:
                            break;
                        case SVt_IV:
                        case SVt_PVIV:
                        case SVt_PVNV:
                        case SVt_NV:
                        case SVt_PV:
                            XMLHash_write_cdata2doc(ctx, SvPV_nolen(hash_value), rootNode);
                            break;
                        case SVt_PVAV:
                        case SVt_PVHV:
                            break;
                        case SVt_PVMG:
                            if (SvOK(value)) {
                                XMLHash_write_cdata2doc(ctx, SvPV_nolen(hash_value), rootNode);
                                break;
                            }
                        default:
                            XMLHash_write_cdata2doc(ctx, SvPV_nolen(hash_value), rootNode);
                    }
                }
                else if (ctx->opts.text[0] != '\0' && strcmp(key, ctx->opts.text) == 0) {
                    if (flag & FLAG_ATTR_ONLY) continue;
                    XMLHash_resolve_value(ctx, &hash_value, &hash_value_ref, &raw);
                    switch (SvTYPE(hash_value)) {
                        case SVt_NULL:
                            XMLHash_write_content2doc(ctx, "", rootNode);
                            break;
                        case SVt_IV:
                        case SVt_PVIV:
                        case SVt_PVNV:
                        case SVt_NV:
                        case SVt_PV:
                            XMLHash_write_content2doc(ctx, SvPV_nolen(hash_value), rootNode);
                            break;
                        case SVt_PVAV:
                        case SVt_PVHV:
                            break;
                        case SVt_PVMG:
                            if (SvOK(value)) {
                                XMLHash_write_content2doc(ctx, SvPV_nolen(hash_value), rootNode);
                                break;
                            }
                        default:
                            XMLHash_write_content2doc(ctx, SvPV_nolen(hash_value), rootNode);
                    }
                }
                else if (ctx->opts.comm[0] != '\0' && strcmp(key, ctx->opts.comm) == 0) {
                    if (flag & FLAG_ATTR_ONLY) continue;
                    XMLHash_resolve_value(ctx, &hash_value, &hash_value_ref, &raw);
                    switch (SvTYPE(hash_value)) {
                        case SVt_NULL:
                            XMLHash_write_comment2doc(ctx, "", rootNode);
                            break;
                        case SVt_IV:
                        case SVt_PVIV:
                        case SVt_PVNV:
                        case SVt_NV:
                        case SVt_PV:
                            XMLHash_write_comment2doc(ctx, SvPV_nolen(hash_value), rootNode);
                            break;
                        case SVt_PVAV:
                        case SVt_PVHV:
                            break;
                        case SVt_PVMG:
                            if (SvOK(value)) {
                                XMLHash_write_comment2doc(ctx, SvPV_nolen(hash_value), rootNode);
                                break;
                            }
                        default:
                            XMLHash_write_comment2doc(ctx, SvPV_nolen(hash_value), rootNode);
                    }
                }
                else if (ctx->opts.attr[0] != '\0') {
                    if (strncmp(key, ctx->opts.attr, ctx->opts.attr_len) == 0) {
                        if (!(flag & FLAG_ATTR_ONLY)) continue;
                        key += ctx->opts.attr_len;
                        XMLHash_resolve_value(ctx, &hash_value, &hash_value_ref, &raw);
                        switch (SvTYPE(hash_value)) {
                            case SVt_NULL:
                                xmlSetProp(rootNode, BAD_CAST key, BAD_CAST "");
                                break;
                            case SVt_IV:
                            case SVt_PVIV:
                            case SVt_PVNV:
                            case SVt_NV:
                            case SVt_PV:
                                xmlSetProp(rootNode, BAD_CAST key, BAD_CAST SvPV_nolen(hash_value));
                                break;
                            case SVt_PVAV:
                            case SVt_PVHV:
                                break;
                            case SVt_PVMG:
                                if (SvOK(value)) {
                                    xmlSetProp(rootNode, BAD_CAST key, BAD_CAST SvPV_nolen(hash_value));
                                    break;
                                }
                            default:
                                xmlSetProp(rootNode, BAD_CAST key, BAD_CAST SvPV_nolen(hash_value));
                        }
                    }
                    else {
                        if (flag & FLAG_ATTR_ONLY) continue;
                        if (SvTYPE(hash_value) == SVt_NULL) {
                            (void) xmlNewTextChild(rootNode, NULL, BAD_CAST key, BAD_CAST "");
                        }
                        else {
                            node = xmlNewTextChild(rootNode, NULL, BAD_CAST key, BAD_CAST "");
                            XMLHash_write_hash_lx2doc(ctx, hash_value, FLAG_ATTR_ONLY, node);
                            XMLHash_write_hash_lx2doc(ctx, hash_value, 0, node);
                        }
                    }
                }
                else {
                    if (SvTYPE(hash_value) == SVt_NULL) {
                        (void) xmlNewTextChild(rootNode, NULL, BAD_CAST key, BAD_CAST "");
                    }
                    else {
                        node = xmlNewTextChild(rootNode, NULL, BAD_CAST key, BAD_CAST "");
                        XMLHash_write_hash_lx2doc(ctx, hash_value, 0, node);
                    }
                }
            }

            break;
        case SVt_PVMG:
            /* blessed */
            if (flag & FLAG_ATTR_ONLY) break;
            if (SvOK(value)) {
                XMLHash_write_content2doc(ctx, SvPV_nolen(value), rootNode);
                break;
            }
        default:
            if (flag & FLAG_ATTR_ONLY) break;
            XMLHash_write_content2doc(ctx, SvPV_nolen(value), rootNode);
    }

    ctx->recursion_depth--;
}

#endif
