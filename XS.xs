#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <libxml/parser.h>

#define MAX_TAG_LEN         1024
#define MAX_RECURSION_DEPTH 128
#define ARRAY_ITEM_TAG      "item"

void XMLHash_hash2xml(xmlNodePtr parentNode, SV * hash);

static char tag[MAX_TAG_LEN] = {'_'};
static int  recursion_depth  = 0;

void
XMLHash_hash2xml_create_element(
    xmlNodePtr parentNode, char *key, SV *value)
{
    xmlNodePtr node;
    I32        i, len;
    int        count;
    SV        *value_ref;

    if (key[0] >= '1' && key[0] <= '9') {
        strncpy(&tag[1], key, MAX_TAG_LEN - 1);

        tag[MAX_TAG_LEN - 1] = '\0';

        key = tag;
    }

    node = xmlNewChild( parentNode, NULL, (const xmlChar *) key, NULL );

    while ( value && SvROK(value) ) {
        if (++recursion_depth > MAX_RECURSION_DEPTH) {
            Perl_croak(aTHX_ "Maximum recursion depth exceeded");
            /*croak("Maximum recursion depth exceeded");*/
        }

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
        ;;
        break;
    case SVt_IV:
    case SVt_PVIV:
    case SVt_PVNV:
    case SVt_NV:
    case SVt_PV:
        /* integer */
        /* double */
        /* scalar */
        xmlNodeAddContent(node, SvPV_nolen(value));
        break;
    case SVt_PVAV:
        /* array */
        len = av_len((AV *) value);
        for (i = 0; i <= len; i++) {
            XMLHash_hash2xml_create_element(
                node, ARRAY_ITEM_TAG, *av_fetch((AV *) value, i, 0));
        }
        break;
    case SVt_PVHV:
        /* hash */
        XMLHash_hash2xml(node, value_ref);
        break;
    case SVt_BIND:
        break;
    case SVt_PVMG:
        /* blessed */
        if (SvOK(value)) {
            xmlNodeAddContent(node, SvPV_nolen(value));
        }
        break;
    default:
        /* undef */
        break;
    }

    recursion_depth--;
}

void
XMLHash_hash2xml(xmlNodePtr parentNode, SV * hash)
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
        XMLHash_hash2xml_create_element(parentNode, key, value);
    }
}

int
XMLHash_output_write_handler(void * ioref, char * buffer, int len)
{
    if ( buffer != NULL && len > 0) {
        dTHX;
        dSP;

        SV * tbuff = newSVpv(buffer,len);
        SV * tsize = newSViv(len);


        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        EXTEND(SP, 3);
        PUSHs((SV*)ioref);
        PUSHs(sv_2mortal(tbuff));
        PUSHs(sv_2mortal(tsize));
        PUTBACK;

        call_pv("XML::Hash::XS::__write", G_SCALAR | G_EVAL | G_DISCARD );

        FREETMPS;
        LEAVE;
    }
    return len;
}

int
XMLHash_output_close_handler(void * fh)
{
    return 1;
}

MODULE = XML::Hash::XS PACKAGE = XML::Hash::XS

SV *
_hash2xml2string(hash, rootNodeName, version, encoding, indent)
        SV   *hash;
        char *rootNodeName;
        char *version;
        char *encoding;
        I32   indent;
    INIT:
        xmlDocPtr  doc    = NULL;
        xmlChar   *result = NULL;
        xmlNodePtr node   = NULL;
        int        len    = 0;
    CODE:
        RETVAL = &PL_sv_undef;

        doc = xmlNewDoc((const xmlChar*) version);
        doc->encoding = strdup(encoding);

        node = xmlNewNode( NULL, (const xmlChar *) rootNodeName );
        xmlDocSetRootElement(doc, node);

        XMLHash_hash2xml(node, hash);

        xmlDocDumpFormatMemoryEnc(doc, &result, &len, NULL, indent);

        xmlFreeDoc(doc);

        if (result == NULL) {
            warn("Failed to convert doc to string");
            XSRETURN_UNDEF;
        } else {
            RETVAL = newSVpvn( (const char *)result, len );
            xmlFree(result);
        }
    OUTPUT:
        RETVAL

int
_hash2xml2fh(fh, hash, rootNodeName, version, encoding, indent)
        SV   *fh;
        SV   *hash;
        char *rootNodeName;
        char *version;
        char *encoding;
        I32   indent;
    INIT:
        xmlOutputBufferPtr        buffer;
        xmlCharEncodingHandlerPtr handler = NULL;
        xmlDocPtr                 doc     = NULL;
        xmlNodePtr                node    = NULL;
    CODE:
        doc = xmlNewDoc((const xmlChar*) version);
        doc->encoding = strdup(encoding);

        node = xmlNewNode( NULL, (const xmlChar *)strdup(rootNodeName) );
        xmlDocSetRootElement(doc, node);

        XMLHash_hash2xml(node, hash);

        xmlRegisterDefaultOutputCallbacks();

        if ( xmlParseCharEncoding((const char*) doc->encoding) != XML_CHAR_ENCODING_UTF8) {
            handler = xmlFindCharEncodingHandler((const char*)encoding);
        }

        buffer = xmlOutputBufferCreateIO(
            (xmlOutputWriteCallback) &XMLHash_output_write_handler,
            (xmlOutputCloseCallback) &XMLHash_output_close_handler,
            fh,
            handler
        );

        RETVAL = xmlSaveFormatFileTo(buffer, doc, (const char *) doc->encoding, 0);

        xmlFreeDoc(doc);
    OUTPUT:
        RETVAL
