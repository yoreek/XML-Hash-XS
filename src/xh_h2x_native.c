#include "xh_config.h"
#include "xh_core.h"

void
xh_h2x_native(xh_h2x_ctx_t *ctx, char *key, I32 key_len, SV *value)
{
    xh_bool_t        raw;
    size_t           i, len;
    SV              *item_value;
    char            *item;
    I32              item_len;
    xh_sort_hash_t  *sorted_hash;

    xh_h2x_resolve_value(ctx, &value, &raw);

    switch (SvTYPE(value)) {
        case SVt_PVMG:
            /* blessed */
            if (!SvOK(value)) {
                goto ADD_EMPTY_NODE;
            }
        case SVt_PV: case SVt_IV: case SVt_PVIV: case SVt_PVNV: case SVt_NV:
            /* integer, double, scalar */
            xh_xml_write_node(ctx->writer, key, key_len, value, raw);
            break;
        case SVt_PVAV:
            /* array */
            len = av_len((AV *) value) + 1;
            for (i = 0; i < len; i++) {
                xh_h2x_native(ctx, key, key_len, *av_fetch((AV *) value, i, 0));
            }

            break;
        case SVt_PVHV:
            /* hash */
            len = HvUSEDKEYS((HV *) value);
            if (len == 0) {
                goto ADD_EMPTY_NODE;
            }

            xh_xml_write_start_node(ctx->writer, key, key_len);

            if (len > 1 && ctx->opts.canonical) {
                sorted_hash = xh_sort_hash((HV *) value, len);
                for (i = 0; i < len; i++) {
                    xh_h2x_native(ctx, sorted_hash[i].key, sorted_hash[i].key_len, sorted_hash[i].value);
                }
                free(sorted_hash);
            }
            else {
                hv_iterinit((HV *) value);
                while ((item_value = hv_iternextsv((HV *) value, &item, &item_len))) {
                    xh_h2x_native(ctx, item, item_len, item_value);
                }
            }

            xh_xml_write_end_node(ctx->writer, key, key_len);

            break;
        default:
ADD_EMPTY_NODE:
            xh_xml_write_empty_node(ctx->writer, key, key_len);
    }

    ctx->depth--;
}

#ifdef XH_HAVE_DOM
void
xh_h2d_native(xh_h2x_ctx_t *ctx, xmlNodePtr rootNode, char *key, I32 key_len, SV *value)
{
    xh_bool_t        raw;
    size_t           i, len;
    SV              *item_value;
    char            *item;
    I32              item_len;
    xh_sort_hash_t  *sorted_hash;

    xh_h2x_resolve_value(ctx, &value, &raw);

    switch (SvTYPE(value)) {
        case SVt_PVMG:
            /* blessed */
            if (!SvOK(value)) {
                goto ADD_EMPTY_NODE;
            }
        case SVt_PV: case SVt_IV: case SVt_PVIV: case SVt_PVNV: case SVt_NV:
            /* integer, double, scalar */
            (void) xh_dom_new_node(ctx, rootNode, key, key_len, value, raw);
            break;
        case SVt_PVAV:
            /* array */
            len = av_len((AV *) value) + 1;
            for (i = 0; i < len; i++) {
                (void) xh_h2d_native(ctx, rootNode, key, key_len, *av_fetch((AV *) value, i, 0));
            }

            break;
        case SVt_PVHV:
            /* hash */
            len = HvUSEDKEYS((HV *) value);
            if (len == 0) {
                goto ADD_EMPTY_NODE;
            }

            rootNode = xh_dom_new_node(ctx, rootNode, key, key_len, NULL, FALSE);

            if (len > 1 && ctx->opts.canonical) {
                sorted_hash = xh_sort_hash((HV *) value, len);
                for (i = 0; i < len; i++) {
                    xh_h2d_native(ctx, rootNode, sorted_hash[i].key, sorted_hash[i].key_len, sorted_hash[i].value);
                }
                free(sorted_hash);
            }
            else {
                hv_iterinit((HV *) value);
                while ((item_value = hv_iternextsv((HV *) value, &item, &item_len))) {
                    xh_h2d_native(ctx, rootNode, item, item_len, item_value);
                }
            }

            break;
        default:
ADD_EMPTY_NODE:
            xh_dom_new_node(ctx, rootNode, key, key_len, NULL, FALSE);
    }

    ctx->depth--;
}
#endif
