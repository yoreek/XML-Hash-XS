#include "xmlhash_common.h"
#include "xmlhash_converter.h"
#include "xmlhash_converter_doc.h"
#include "xmlhash_converter_native.h"
#include "xmlhash_converter_no_attr.h"
#include "xmlhash_converter_lx.h"

const char indent_string[60] = "                                                            ";

int
XMLHash_cmpstring(const void *p1, const void *p2)
{
    hash_entity_t *e1, *e2;
    e1 = (hash_entity_t *) p1;
    e2 = (hash_entity_t *) p2;
    return strcmp(e1->key, e2->key);
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

SV *
XMLHash_hash2xml(convert_ctx_t *ctx, SV *hash)
{
    SV            *result;
    conv_writer_t *writer = NULL;

    /* run */
    dXCPT;
    XCPT_TRY_START
    {
        ctx->writer = writer = XMLHash_writer_create(ctx->opts.encoding, ctx->opts.output, 16384);

        if (ctx->opts.xml_decl) {
            /* xml declaration */
            BUFFER_WRITE_CONSTANT("<?xml version=");
            BUFFER_WRITE_QUOTED(ctx->opts.version);
            BUFFER_WRITE_CONSTANT(" encoding=");
            BUFFER_WRITE_QUOTED(ctx->opts.encoding);
            BUFFER_WRITE_CONSTANT("?>\n");
        }

        switch (ctx->opts.method) {
            case CONV_METHOD_NATIVE:
                ctx->opts.trim = 0;
                XMLHash_write_hash_no_attr(ctx, ctx->opts.root, hash);
                break;
            case CONV_METHOD_NATIVE_ATTR_MODE:
                ctx->opts.trim = 0;
                XMLHash_write_hash(ctx, ctx->opts.root, hash);
                break;
            case CONV_METHOD_LX:
                XMLHash_write_hash_lx(ctx, hash, 0);
                break;
            default:
                croak("Invalid method");
        }
    } XCPT_TRY_END

    XCPT_CATCH
    {
        XMLHash_stash_clean(&ctx->stash);
        XMLHash_writer_destroy(writer);
        XCPT_RETHROW;
    }

    XMLHash_stash_clean(&ctx->stash);
    result = XMLHash_writer_flush(writer);
    if (result != NULL) {
#if defined(XMLHASH_HAVE_ICONV) || defined(XMLHASH_HAVE_ICU)
        if (writer->encoder == NULL) {
            SvUTF8_on(result);
        }
#else
        SvUTF8_on(result);
#endif
    }
    XMLHash_writer_destroy(writer);

    return result;
}

SV *
XMLHash_hash2dom(convert_ctx_t *ctx, SV *hash)
{
    xmlDocPtr doc = xmlNewDoc(BAD_CAST ctx->opts.version);
    if (doc == NULL) {
        croak("Can't create new document");
    }
    doc->encoding = (const xmlChar*) xmlStrdup((const xmlChar*) ctx->opts.encoding);

    dXCPT;
    XCPT_TRY_START
    {
        switch (ctx->opts.method) {
            case CONV_METHOD_NATIVE:
                ctx->opts.trim = 0;
                XMLHash_write_hash_no_attr2doc(ctx, ctx->opts.root, hash, (xmlNodePtr) doc);
                break;
            case CONV_METHOD_NATIVE_ATTR_MODE:
                ctx->opts.trim = 0;
                XMLHash_write_hash2doc(ctx, ctx->opts.root, hash, (xmlNodePtr) doc);
                break;
            case CONV_METHOD_LX:
                XMLHash_write_hash_lx2doc(ctx, hash, 0, (xmlNodePtr) doc);
                break;
            default:
                croak("Invalid method");
        }
    } XCPT_TRY_END

    XCPT_CATCH
    {
        XMLHash_stash_clean(&ctx->stash);
        XCPT_RETHROW;
    }

    XMLHash_stash_clean(&ctx->stash);

    return x_PmmNodeToSv((xmlNodePtr) doc, NULL);
}
