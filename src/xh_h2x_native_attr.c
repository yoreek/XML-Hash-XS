#include "xh_config.h"
#include "xh_core.h"

xh_int_t
xh_h2x_native_attr(xh_h2x_ctx_t *ctx, char *key, I32 key_len, SV *value, xh_int_t flag)
{
    xh_bool_t       raw;
    size_t          len, i, nattrs, done;
    xh_sort_hash_t *sorted_hash;
    SV             *item_value;
    char           *item;
    I32             item_len;

    nattrs = 0;

    if (ctx->opts.content[0] != '\0' && strcmp(key, ctx->opts.content) == 0) {
        flag = flag | XH_H2X_F_CONTENT;
    }

    xh_h2x_resolve_value(ctx, &value, &raw);

    switch (SvTYPE(value)) {
        case SVt_PVMG:
            /* blessed */
            if (!SvOK(value)) break;
        case SVt_IV: case SVt_PVIV: case SVt_PVNV: case SVt_NV: case SVt_PV:
            /* integer, double, scalar */
            if (flag & XH_H2X_F_SIMPLE && flag & XH_H2X_F_COMPLEX) {
                xh_xml_write_node(ctx->writer, key, key_len, value, raw);
            }
            else if (flag & XH_H2X_F_COMPLEX && flag & XH_H2X_F_CONTENT) {
                xh_xml_write_content(ctx->writer, value);
            }
            else if (flag & XH_H2X_F_SIMPLE && !(flag & XH_H2X_F_CONTENT)) {
                xh_xml_write_attribute(ctx->writer, key, key_len, value);
                nattrs++;
            }
            break;
        case SVt_PVAV:
            /* array */
            if (!(flag & XH_H2X_F_COMPLEX)) break;
            len = av_len((AV *) value) + 1;
            for (i = 0; i < len; i++) {
                (void) xh_h2x_native_attr(ctx, key, key_len, *av_fetch((AV *) value, i, 0), XH_H2X_F_SIMPLE | XH_H2X_F_COMPLEX);
            }
            nattrs++;
            break;
        case SVt_PVHV:
            /* hash */
            if (!(flag & XH_H2X_F_COMPLEX)) break;

            len = HvUSEDKEYS((SV *) value);
            if (len == 0) {
                xh_xml_write_empty_node(ctx->writer, key, key_len);
                break;
            }

            xh_xml_write_start_tag(ctx->writer, key, key_len);

            done = 0;

            if (len > 1 && ctx->opts.canonical) {
                sorted_hash = xh_sort_hash((HV *) value, len);

                for (i = 0; i < len; i++) {
                    done += xh_h2x_native_attr(ctx, sorted_hash[i].key, sorted_hash[i].key_len, sorted_hash[i].value, XH_H2X_F_SIMPLE);
                }

                if (done == len) {
                    xh_xml_write_closed_end_tag(ctx->writer);
                }
                else {
                    xh_xml_write_end_tag(ctx->writer);

                    for (i = 0; i < len; i++) {
                        (void) xh_h2x_native_attr(ctx, sorted_hash[i].key, sorted_hash[i].key_len, sorted_hash[i].value, XH_H2X_F_COMPLEX);
                    }

                    xh_xml_write_end_node(ctx->writer, key, key_len);
                }

                free(sorted_hash);
            }
            else {
                hv_iterinit((HV *) value);
                while ((item_value = hv_iternextsv((HV *) value, &item, &item_len))) {
                    done += xh_h2x_native_attr(ctx, item, item_len,item_value, XH_H2X_F_SIMPLE);
                }

                if (done == len) {
                    xh_xml_write_closed_end_tag(ctx->writer);
                }
                else {
                    xh_xml_write_end_tag(ctx->writer);

                    hv_iterinit((HV *) value);
                    while ((item_value = hv_iternextsv((HV *) value, &item, &item_len))) {
                        (void) xh_h2x_native_attr(ctx, item, item_len,item_value, XH_H2X_F_COMPLEX);
                    }

                    xh_xml_write_end_node(ctx->writer, key, key_len);
                }
            }

            nattrs++;

            break;
        default:
            if (flag & XH_H2X_F_SIMPLE && flag & XH_H2X_F_COMPLEX) {
                xh_xml_write_empty_node(ctx->writer, key, key_len);
            }
            else if (flag & XH_H2X_F_SIMPLE && !(flag & XH_H2X_F_CONTENT)) {
                xh_xml_write_attribute(ctx->writer, key, key_len, NULL);
                nattrs++;
            }
    }

    ctx->depth--;

    return nattrs;
}

#ifdef XH_HAVE_DOM
xh_int_t
xh_h2d_native_attr(xh_h2x_ctx_t *ctx, xmlNodePtr rootNode, char *key, I32 key_len, SV *value, xh_int_t flag)
{
    xh_bool_t       raw;
    size_t          len, i, nattrs, done;
    xh_sort_hash_t *sorted_hash;
    SV             *item_value;
    char           *item;
    I32             item_len;

    nattrs = 0;

    if (ctx->opts.content[0] != '\0' && strcmp(key, ctx->opts.content) == 0) {
        flag = flag | XH_H2X_F_CONTENT;
    }

    xh_h2x_resolve_value(ctx, &value, &raw);

    switch (SvTYPE(value)) {
        case SVt_PVMG:
            /* blessed */
            if (!SvOK(value)) break;
        case SVt_IV: case SVt_PVIV: case SVt_PVNV: case SVt_NV: case SVt_PV:
            /* integer, double, scalar */
            if (flag & XH_H2X_F_SIMPLE && flag & XH_H2X_F_COMPLEX) {
                (void) xh_dom_new_node(ctx, rootNode, key, key_len, value, raw);
            }
            else if (flag & XH_H2X_F_COMPLEX && flag & XH_H2X_F_CONTENT) {
                xh_dom_new_content(ctx, rootNode, value);
            }
            else if (flag & XH_H2X_F_SIMPLE && !(flag & XH_H2X_F_CONTENT)) {
                xh_dom_new_attribute(ctx, rootNode, key, key_len, value);
                nattrs++;
            }
            break;
        case SVt_PVAV:
            /* array */
            if (!(flag & XH_H2X_F_COMPLEX)) break;
            len = av_len((AV *) value) + 1;
            for (i = 0; i < len; i++) {
                (void) xh_h2d_native_attr(ctx, rootNode, key, key_len, *av_fetch((AV *) value, i, 0), XH_H2X_F_SIMPLE | XH_H2X_F_COMPLEX);
            }
            nattrs++;
            break;
        case SVt_PVHV:
            /* hash */
            if (!(flag & XH_H2X_F_COMPLEX)) break;

            rootNode = xh_dom_new_node(ctx, rootNode, key, key_len, NULL, raw);

            len = HvUSEDKEYS((SV *) value);
            if (len == 0) {
                break;
            }

            done = 0;

            if (len > 1 && ctx->opts.canonical) {
                sorted_hash = xh_sort_hash((HV *) value, len);

                for (i = 0; i < len; i++) {
                    done += xh_h2d_native_attr(ctx, rootNode, sorted_hash[i].key, sorted_hash[i].key_len, sorted_hash[i].value, XH_H2X_F_SIMPLE);
                }

                if (done != len) {
                    for (i = 0; i < len; i++) {
                        (void) xh_h2d_native_attr(ctx, rootNode, sorted_hash[i].key, sorted_hash[i].key_len, sorted_hash[i].value, XH_H2X_F_COMPLEX);
                    }
                }

                free(sorted_hash);
            }
            else {
                hv_iterinit((HV *) value);
                while ((item_value = hv_iternextsv((HV *) value, &item, &item_len))) {
                    done += xh_h2d_native_attr(ctx, rootNode, item, item_len,item_value, XH_H2X_F_SIMPLE);
                }

                if (done != len) {
                    hv_iterinit((HV *) value);
                    while ((item_value = hv_iternextsv((HV *) value, &item, &item_len))) {
                        (void) xh_h2d_native_attr(ctx, rootNode, item, item_len,item_value, XH_H2X_F_COMPLEX);
                    }
                }
            }

            nattrs++;

            break;
        default:
            if (flag & XH_H2X_F_SIMPLE && flag & XH_H2X_F_COMPLEX) {
                (void) xh_dom_new_node(ctx, rootNode, key, key_len, NULL, raw);
            }
            else if (flag & XH_H2X_F_SIMPLE && !(flag & XH_H2X_F_CONTENT)) {
                xh_dom_new_attribute(ctx, rootNode, key, key_len, NULL);
                nattrs++;
            }
    }

    ctx->depth--;

    return nattrs;
}
#endif
