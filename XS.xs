#include "EXTERN.h"
#include "perl.h"
#include "XSUB.h"

#include <libxml/parser.h>

void XMLHash_hash2xml(xmlNodePtr parentNode, SV * hash);

void
XMLHash_hash2xml_create_element(
    xmlNodePtr parentNode, char *key, SV *value)
{
    xmlNodePtr node;
    I32        i;
    int        count;

    node      = xmlNewNode( NULL, (const xmlChar *) key );
    node->doc = parentNode->doc;

    xmlAddChild(parentNode, node);

START:
    if (value && SvROK(value)) {
        value = SvRV(value);

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

                goto START;
            }
            else {
                value = NULL;
            }
        }
        else if (SvTYPE(value) == SVt_PVMG) {
            /* blessed TODO */
        }
    }

    switch (SvTYPE(value)) {
    case SVt_PVAV:
        /* array */
        for (i = 0; i <= av_len((AV *)value); i++) {
            XMLHash_hash2xml_create_element(
                node, "item", *av_fetch((AV *)value, i, 0));
        }
        break;
    case SVt_PVHV:
        /* hash */
        XMLHash_hash2xml(node, newRV(value));
        break;
    case SVt_PV:
        /* scalar */
        xmlNodeAddContent(node, SvPV_nolen(value));
        break;
    case SVt_IV:
        /* integer */
        xmlNodeAddContent(node, SvPV_nolen(value));
        break;
    case SVt_NV:
        /* double */
        xmlNodeAddContent(node, SvPV_nolen(value));
        break;
    default:
        /* undef */
        break;
    }
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

MODULE = XML::Hash::XS PACKAGE = XML::Hash::XS

SV *
_hash2xml2string(hash, rootNodeName, version, encoding)
        SV   *hash;
        char *rootNodeName;
        char *version;
        char *encoding;
    INIT:
        xmlDocPtr  doc    = NULL;
        xmlChar   *result = NULL;
        xmlNodePtr node   = NULL;
        int        len    = 0;
    CODE:
        doc = xmlNewDoc((const xmlChar*) version);
        doc->encoding = strdup(encoding);

        node = xmlNewNode( NULL, (const xmlChar *)strdup(rootNodeName) );
        xmlDocSetRootElement(doc, node);

        XMLHash_hash2xml(node, hash);

        xmlDocDumpMemory(doc, &result, &len);

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
_hash2xml2fh(fh, hash, rootNodeName, version, encoding)
        FILE *fh
        SV   *hash;
        char *rootNodeName;
        char *version;
        char *encoding;
    INIT:
        xmlDocPtr  doc    = NULL;
        xmlNodePtr node   = NULL;
    CODE:
        doc = xmlNewDoc((const xmlChar*) version);
        doc->encoding = strdup(encoding);

        node = xmlNewNode( NULL, (const xmlChar *)strdup(rootNodeName) );
        xmlDocSetRootElement(doc, node);

        XMLHash_hash2xml(node, hash);

        RETVAL = xmlDocFormatDump(fh, doc, 0);
    OUTPUT:
        RETVAL
