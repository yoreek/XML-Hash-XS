#include "xh_config.h"
#include "xh_core.h"

XH_INLINE void
_xh_h2x_lx(xh_h2x_ctx_t *ctx, char *key, I32 key_len, SV *value, xh_int_t flag)
{
    xh_uint_t type;

    value = xh_h2x_resolve_value(ctx, value, &type);

    if (ctx->opts.cdata[0] != '\0' && strcmp(key, ctx->opts.cdata) == 0) {
        if (flag & XH_H2X_F_ATTR_ONLY || !(type & XH_H2X_T_SCALAR)) return;
        xh_xml_write_cdata(ctx->writer, value);
    }
    else if (ctx->opts.text[0] != '\0' && strcmp(key, ctx->opts.text) == 0) {
        if (flag & XH_H2X_F_ATTR_ONLY || !(type & XH_H2X_T_SCALAR)) return;
        xh_xml_write_content(ctx->writer, value);
    }
    else if (ctx->opts.comm[0] != '\0' && strcmp(key, ctx->opts.comm) == 0) {
        if (flag & XH_H2X_F_ATTR_ONLY) return;

        if (type & XH_H2X_T_SCALAR) {
            xh_xml_write_comment(ctx->writer, value);
        }
        else {
            xh_xml_write_comment(ctx->writer, NULL);
        }
    }
    else if (ctx->opts.attr[0] != '\0') {
        if (strncmp(key, ctx->opts.attr, ctx->opts.attr_len) == 0) {
            if (!(flag & XH_H2X_F_ATTR_ONLY)) return;

            key     += ctx->opts.attr_len;
            key_len -= ctx->opts.attr_len;

            if (type & XH_H2X_T_SCALAR) {
                xh_xml_write_attribute(ctx->writer, key, key_len, value);
            }
            else {
                xh_xml_write_attribute(ctx->writer, key, key_len, NULL);
            }
        }
        else {
            if (flag & XH_H2X_F_ATTR_ONLY) return;

            if (type & XH_H2X_T_NOT_NULL) {
                /* '<tag' */
                xh_xml_write_start_tag(ctx->writer, key, key_len);
                /* ' attr1="..." attr2="..."' */
                xh_h2x_lx(ctx, value, XH_H2X_F_ATTR_ONLY);
                /* '>' */
                xh_xml_write_end_tag(ctx->writer);

                xh_h2x_lx(ctx, value, XH_H2X_F_NONE);

                xh_xml_write_end_node(ctx->writer, key, key_len);
            }
            else {
                xh_xml_write_empty_node(ctx->writer, key, key_len);
            }
        }
    }
    else {
        if (type & XH_H2X_T_NOT_NULL) {
            /* '<tag>' */
            xh_xml_write_start_node(ctx->writer, key, key_len);

            xh_h2x_lx(ctx, value, XH_H2X_F_NONE);

            /* '</tag>' */
            xh_xml_write_end_node(ctx->writer, key, key_len);
        }
        else {
            xh_xml_write_empty_node(ctx->writer, key, key_len);
        }
    }
}

void
xh_h2x_lx(xh_h2x_ctx_t *ctx, SV *value, xh_int_t flag)
{
    SV             *hash_value;
    char           *key;
    I32             key_len;
    size_t          len, i;
    xh_uint_t       type;
    xh_sort_hash_t *sorted_hash;

    value = xh_h2x_resolve_value(ctx, value, &type);

    if (type & XH_H2X_T_SCALAR) {
        if (flag & XH_H2X_F_ATTR_ONLY) goto FINISH;
        xh_xml_write_content(ctx->writer, value);
    }
    else if (type & XH_H2X_T_HASH) {
        len = HvUSEDKEYS((HV *) value);

        if (len > 1 && ctx->opts.canonical) {
            sorted_hash = xh_sort_hash((HV *) value, len);
            for (i = 0; i < len; i++) {
                _xh_h2x_lx(ctx, sorted_hash[i].key, sorted_hash[i].key_len, sorted_hash[i].value, flag);
            }
            free(sorted_hash);
        }
        else {
            hv_iterinit((HV *) value);
            while ((hash_value = hv_iternextsv((HV *) value, &key, &key_len))) {
                _xh_h2x_lx(ctx, key, key_len, hash_value, flag);
            }
        }
    }
    else if (type & XH_H2X_T_ARRAY) {
        len = av_len((AV *) value) + 1;
        for (i = 0; i < len; i++) {
            xh_h2x_lx(ctx, *av_fetch((AV *) value, i, 0), flag);
        }
    }

FINISH:
    ctx->depth--;
}

#ifdef XH_HAVE_DOM
XH_INLINE void
_xh_h2d_lx(xh_h2x_ctx_t *ctx, xmlNodePtr rootNode, char *key, I32 key_len, SV *value, xh_int_t flag)
{
    xh_uint_t      type;

    value = xh_h2x_resolve_value(ctx, value, &type);

    if (ctx->opts.cdata[0] != '\0' && strcmp(key, ctx->opts.cdata) == 0) {
        if (flag & XH_H2X_F_ATTR_ONLY || !(type & XH_H2X_T_SCALAR)) return;
        xh_dom_new_cdata(ctx, rootNode, value);
    }
    else if (ctx->opts.text[0] != '\0' && strcmp(key, ctx->opts.text) == 0) {
        if (flag & XH_H2X_F_ATTR_ONLY || !(type & XH_H2X_T_SCALAR)) return;
        xh_dom_new_content(ctx, rootNode, value);
    }
    else if (ctx->opts.comm[0] != '\0' && strcmp(key, ctx->opts.comm) == 0) {
        if (flag & XH_H2X_F_ATTR_ONLY) return;

        if (!type) {
            xh_dom_new_comment(ctx, rootNode, NULL);
        }
        else if (type & XH_H2X_T_SCALAR) {
            xh_dom_new_comment(ctx, rootNode, value);
        }
    }
    else if (ctx->opts.attr[0] != '\0') {
        if (strncmp(key, ctx->opts.attr, ctx->opts.attr_len) == 0) {
            if (!(flag & XH_H2X_F_ATTR_ONLY)) return;

            key     += ctx->opts.attr_len;
            key_len -= ctx->opts.attr_len;

            if (type & XH_H2X_T_SCALAR) {
                xh_dom_new_attribute(ctx, rootNode, key, key_len, value);
            }
            else {
                xh_dom_new_attribute(ctx, rootNode, key, key_len, NULL);
            }
        }
        else {
            if (flag & XH_H2X_F_ATTR_ONLY) return;
            rootNode = xh_dom_new_node(ctx, rootNode, key, key_len, NULL, type & XH_H2X_T_RAW);
            if (type & XH_H2X_T_NOT_NULL) {
                xh_h2d_lx(ctx, rootNode, value, XH_H2X_F_ATTR_ONLY);
                xh_h2d_lx(ctx, rootNode, value, XH_H2X_F_NONE);
            }
        }
    }
    else {
        rootNode = xh_dom_new_node(ctx, rootNode, key, key_len, NULL, type & XH_H2X_T_RAW);
        if (type & XH_H2X_T_NOT_NULL) {
            xh_h2d_lx(ctx, rootNode, value, XH_H2X_F_NONE);
        }
    }
}

void
xh_h2d_lx(xh_h2x_ctx_t *ctx, xmlNodePtr rootNode, SV *value, xh_int_t flag)
{
    SV             *hash_value;
    char           *key;
    I32             key_len;
    size_t          len, i;
    xh_uint_t       type;
    xh_sort_hash_t *sorted_hash;

    value = xh_h2x_resolve_value(ctx, value, &type);

    if (type & XH_H2X_T_SCALAR) {
        if (flag & XH_H2X_F_ATTR_ONLY) goto FINISH;
        xh_dom_new_content(ctx, rootNode, value);
    }
    else if (type & XH_H2X_T_HASH) {
        len = HvUSEDKEYS((HV *) value);
        hv_iterinit((HV *) value);

        if (len > 1 && ctx->opts.canonical) {
            sorted_hash = xh_sort_hash((HV *) value, len);
            for (i = 0; i < len; i++) {
                _xh_h2d_lx(ctx, rootNode, sorted_hash[i].key, sorted_hash[i].key_len, sorted_hash[i].value, flag);
            }
            free(sorted_hash);
        }
        else {
            while ((hash_value = hv_iternextsv((HV *) value, &key, &key_len))) {
                _xh_h2d_lx(ctx, rootNode, key, key_len, hash_value, flag);
            }
        }
    }
    else if (type & XH_H2X_T_ARRAY) {
        len = av_len((AV *) value) + 1;
        for (i = 0; i < len; i++) {
            xh_h2d_lx(ctx, rootNode, *av_fetch((AV *) value, i, 0), flag);
        }
    }

FINISH:
    ctx->depth--;
}
#endif
