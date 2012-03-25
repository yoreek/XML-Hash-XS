#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <libxml/parser.h>

#define MAX_RECURSION_DEPTH 128
#define ARRAY_ITEM_TAG      "item"
#define INDENT_STEP         2

typedef enum {
    TAG_OPEN,
    TAG_CLOSE,
    TAG_EMPTY
} tagType;

const char indent_string[60] = "                                                            ";

void XMLHash_hash2xml(xmlOutputBufferPtr out_buff, SV *hash, int indent);

static int recursion_depth  = 0;
static int indent_count     = 0;

int
XMLHash_output_write_handler(void *fp, char *buffer, int len)
{
    if ( buffer != NULL && len > 0)
        PerlIO_write(fp, buffer, len);

    return len;
}

int
XMLHash_output_write_tied_handler(void *obj, char *buffer, int len)
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
XMLHash_output_close_handler(void *fh)
{
    return 1;
}

void
XMLHash_hash2xml_write_tag(
    xmlOutputBufferPtr out_buff, tagType type, char *name, int indent, int lf)
{
    int indent_len;

    if (indent) {
        indent_len = indent_count *INDENT_STEP;
        if (indent_len > sizeof(indent_string))
            indent_len = sizeof(indent_string);

        xmlOutputBufferWrite(out_buff, indent_len, indent_string);
    }

    if (type == TAG_CLOSE) {
        xmlOutputBufferWrite(out_buff, 2, "</");
    }
    else {
        xmlOutputBufferWrite(out_buff, 1, "<");
    }

    if (name[0] >= '1' && name[0] <= '9')
        xmlOutputBufferWrite(out_buff, 1, "_");

    xmlOutputBufferWriteString(out_buff, (xmlChar *) name);

    if (type == TAG_EMPTY) {
        xmlOutputBufferWrite(out_buff, 2, "/>");
    }
    else {
        xmlOutputBufferWrite(out_buff, 1, ">");
    }

    if (lf)
        xmlOutputBufferWrite(out_buff, 1, "\n");
}

void
XMLHash_hash2xml_create_element(
    xmlOutputBufferPtr out_buff, char *name, SV *value, int indent)
{
    I32        i, len;
    int        count;
    SV        *value_ref;

    indent_count++;

    while ( value && SvROK(value) ) {
        if (++recursion_depth > MAX_RECURSION_DEPTH)
            croak("Maximum recursion depth exceeded");

        value_ref = value;
        value     = SvRV(value);

        if(SvTYPE(value) == SVt_PVCV) {
            /* code ref */
            dSP;

            ENTER;
            SAVETMPS;
            count = call_sv(value, G_SCALAR);

            SPAGAIN;

            if (count == 1) {
                value = POPs;

                SvREFCNT_inc(value);

                PUTBACK;

                FREETMPS;
                LEAVE;

                continue;
            }
            else {
                value = NULL;
            }
        }
    }

    switch (SvTYPE(value)) {
        case SVt_NULL:
            XMLHash_hash2xml_write_tag(out_buff, TAG_EMPTY, name, indent, indent);
            break;
        case SVt_IV:
        case SVt_PVIV:
        case SVt_PVNV:
        case SVt_NV:
        case SVt_PV:
            /* integer, double, scalar */
            XMLHash_hash2xml_write_tag(out_buff, TAG_OPEN, name, indent, 0);
            xmlOutputBufferWriteEscape(out_buff, (xmlChar *) SvPV_nolen(value), NULL);
            XMLHash_hash2xml_write_tag(out_buff, TAG_CLOSE, name, 0, indent);
            break;
        case SVt_PVAV:
            /* array */
            len = av_len((AV *) value);
            XMLHash_hash2xml_write_tag(out_buff, TAG_OPEN, name, indent, indent);

            for (i = 0; i <= len; i++) {
                XMLHash_hash2xml_create_element(
                    out_buff, ARRAY_ITEM_TAG, *av_fetch((AV *) value, i, 0),
                    indent);
            }

            XMLHash_hash2xml_write_tag(out_buff, TAG_CLOSE, name, indent, indent);
            break;
        case SVt_PVHV:
            /* hash */
            XMLHash_hash2xml_write_tag(out_buff, TAG_OPEN, name, indent, indent);
            XMLHash_hash2xml(out_buff, value_ref, indent);
            XMLHash_hash2xml_write_tag(out_buff, TAG_CLOSE, name, indent, indent);
            break;
        case SVt_PVMG:
            /* blessed */
            if (SvOK(value)) {
                XMLHash_hash2xml_write_tag(out_buff, TAG_OPEN, name, indent, 0);
                xmlOutputBufferWriteEscape(out_buff, (xmlChar *) SvPV_nolen(value), NULL);
                XMLHash_hash2xml_write_tag(out_buff, TAG_CLOSE, name, 0, indent);
                break;
            }
        default:
            XMLHash_hash2xml_write_tag(out_buff, TAG_EMPTY, name, indent, indent);
    }

    recursion_depth--;
    indent_count--;
}

void
XMLHash_hash2xml(xmlOutputBufferPtr out_buff, SV *hash, int indent)
{
    SV   *value;
    char *key;
    I32   keylen;

    if (!SvROK(hash)) {
        warn("parameter is not reference\n");
        return;
    }

    hv_iterinit((HV *)SvRV(hash));
    while ((value = hv_iternextsv((HV *)SvRV(hash), &key, &keylen))) {
        XMLHash_hash2xml_create_element(out_buff, key, value, indent);
    }
}

void
XMLHash_hash2xml_process(xmlOutputBufferPtr out_buff, SV *hash,
    char *rootNodeName, char *version, char *encoding, int indent)
{
    /* xml declaration */
    xmlOutputBufferWrite(out_buff, 14, "<?xml version=");
    xmlBufferWriteQuotedString(out_buff->buffer, (xmlChar *) version);
    xmlOutputBufferWrite(out_buff, 10, " encoding=");
    xmlBufferWriteQuotedString(out_buff->buffer, (xmlChar *) encoding);
    xmlOutputBufferWrite(out_buff, 3, "?>\n");

    /* open root tag */
    XMLHash_hash2xml_write_tag(out_buff, TAG_OPEN, rootNodeName, indent, indent);

    /* write document */
    XMLHash_hash2xml(out_buff, hash, indent);

    /* close root tag */
    XMLHash_hash2xml_write_tag(out_buff, TAG_CLOSE, rootNodeName, indent, 1);
}

MODULE = XML::Hash::XS PACKAGE = XML::Hash::XS

PROTOTYPES: DISABLE

SV *
_hash2xml2string(hash, rootNodeName, version, encoding, indent)
        SV   *hash;
        char *rootNodeName;
        char *version;
        char *encoding;
        I32   indent;
    INIT:
        xmlChar                   *result    = NULL;
        int                        len       = 0;
        xmlOutputBufferPtr         out_buff  = NULL;
        xmlCharEncodingHandlerPtr  conv_hdlr = NULL;
    CODE:
        RETVAL = &PL_sv_undef;

        recursion_depth = 0;
        indent_count    = 0;

        conv_hdlr = xmlFindCharEncodingHandler(encoding);
        if ( conv_hdlr == NULL )
            croak("Unknown encoding");

        if ((out_buff = xmlAllocOutputBuffer(conv_hdlr)) == NULL )
            croak("Buffer allocation error");

        XMLHash_hash2xml_process(out_buff, hash, rootNodeName, version,
                                 encoding, indent);

        xmlOutputBufferFlush(out_buff);

        if (out_buff->conv != NULL) {
            len    = out_buff->conv->use;
            result = xmlStrndup(out_buff->conv->content, len);
        }
        else {
            len    = out_buff->buffer->use;
            result = xmlStrndup(out_buff->buffer->content, len);
        }

        (void) xmlOutputBufferClose(out_buff);

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
_hash2xml2fh(fh, hash, rootNodeName, version, encoding, indent)
        void *fh;
        SV   *hash;
        char *rootNodeName;
        char *version;
        char *encoding;
        I32   indent;
    INIT:
        xmlOutputBufferPtr         out_buff  = NULL;
        xmlCharEncodingHandlerPtr  conv_hdlr = NULL;
        MAGIC                     *mg;
        PerlIO                    *fp;
        SV                        *obj;
        GV                        *gv = (GV *)fh;
        IO                        *io = GvIO(gv);
    CODE:
        recursion_depth = 0;
        indent_count    = 0;

        conv_hdlr = xmlFindCharEncodingHandler(encoding);
        if ( conv_hdlr == NULL )
            croak("Unknown encoding");

        xmlRegisterDefaultOutputCallbacks();

        if (io && (mg = SvTIED_mg((const SV *)io, PERL_MAGIC_tiedscalar))) {
            /* tied handle */
            obj = SvTIED_obj(MUTABLE_SV(io), mg);

            out_buff = xmlOutputBufferCreateIO(
                (xmlOutputWriteCallback) &XMLHash_output_write_tied_handler,
                (xmlOutputCloseCallback) &XMLHash_output_close_handler,
                obj, conv_hdlr
            );
        }
        else {
            /* simple handle */
            fp = IoOFP(io);

            out_buff = xmlOutputBufferCreateIO(
                (xmlOutputWriteCallback) &XMLHash_output_write_handler,
                (xmlOutputCloseCallback) &XMLHash_output_close_handler,
                fp, conv_hdlr
            );
        }

        if (out_buff == NULL)
            croak("Buffer creating error");

        XMLHash_hash2xml_process(out_buff, hash, rootNodeName, version,
                                 encoding, indent);

        RETVAL = xmlOutputBufferClose(out_buff);
    OUTPUT:
        RETVAL
