#ifndef _XMLHASH_CONVERTER_DOC_H_
#define _XMLHASH_CONVERTER_DOC_H_

#include <libxml/parser.h>
#include "xmlhash_common.h"
#include "xmlhash_converter.h"

#define Pmm_NO_PSVI      0
#define Pmm_PSVI_TAINTED 1

struct _ProxyNode {
    xmlNodePtr node;
    xmlNodePtr owner;
    int count;
};

struct _DocProxyNode {
    xmlNodePtr node;
    xmlNodePtr owner;
    int count;
    int encoding; /* only used for proxies of xmlDocPtr */
    int psvi_status; /* see below ... */
};

/* helper type for the proxy structure */
typedef struct _DocProxyNode DocProxyNode;
typedef struct _ProxyNode ProxyNode;

/* pointer to the proxy structure */
typedef ProxyNode* ProxyNodePtr;
typedef DocProxyNode* DocProxyNodePtr;

/* this my go only into the header used by the xs */
#define SvPROXYNODE(x) (INT2PTR(ProxyNodePtr,SvIV(SvRV(x))))
#define PmmPROXYNODE(x) (INT2PTR(ProxyNodePtr,x->_private))
#define SvNAMESPACE(x) (INT2PTR(xmlNsPtr,SvIV(SvRV(x))))

#define x_PmmREFCNT(node)      node->count
#define x_PmmREFCNT_inc(node)  node->count++
#define x_PmmNODE(xnode)       xnode->node
#define x_PmmOWNER(node)       node->owner
#define x_PmmOWNERPO(node)     ((node && x_PmmOWNER(node)) ? (ProxyNodePtr)x_PmmOWNER(node)->_private : node)

#define x_PmmENCODING(node)    ((DocProxyNodePtr)(node))->encoding
#define x_PmmNodeEncoding(node) ((DocProxyNodePtr)(node->_private))->encoding

#define x_SetPmmENCODING(node,code) x_PmmENCODING(node)=(code)
#define x_SetPmmNodeEncoding(node,code) x_PmmNodeEncoding(node)=(code)

#define x_PmmSvNode(n) x_PmmSvNodeExt(n,1)

#define x_PmmUSEREGISTRY       (x_PROXY_NODE_REGISTRY_MUTEX != NULL)
#define x_PmmREGISTRY          (INT2PTR(xmlHashTablePtr,SvIV(SvRV(get_sv("XML::LibXML::__PROXY_NODE_REGISTRY",0)))))

SV *x_PmmNodeToSv(xmlNodePtr node, ProxyNodePtr owner);

INLINE xmlNodePtr
XMLHash_write_tag2doc(char *name, char *content, xmlNodePtr rootNode)
{
    if (name == NULL) {
        return rootNode;
    }
    else if (name[0] >= '1' && name[0] <= '9') {
        int str_len = strlen(name);
        char *tmp = malloc(str_len + 1);
        if (tmp == NULL) {
            croak("Memory allocation error");
        }
        strcpy(&tmp[1], name);
        *tmp = '_';
        xmlNodePtr node = xmlNewChild(rootNode, NULL, BAD_CAST name, BAD_CAST content);
        free(tmp);
        return node;
    }

    return xmlNewChild(rootNode, NULL, BAD_CAST name, BAD_CAST content);
}

INLINE xmlNodePtr
XMLHash_write_tag2doc_escaped(char *name, char *content, xmlNodePtr rootNode)
{
    if (name == NULL) {
        return rootNode;
    }
    else if (name[0] >= '1' && name[0] <= '9') {
        int str_len = strlen(name);
        char *tmp = malloc(str_len + 1);
        if (tmp == NULL) {
            croak("Memory allocation error");
        }
        strcpy(&tmp[1], name);
        *tmp = '_';
        xmlNodePtr node = xmlNewTextChild(rootNode, NULL, BAD_CAST tmp, BAD_CAST content);
        free(tmp);
        return node;
    }

    return xmlNewTextChild(rootNode, NULL, BAD_CAST name, BAD_CAST content);
}

INLINE void
XMLHash_write_content2doc(convert_ctx_t *ctx, char *value, xmlNodePtr rootNode)
{
    int str_len;

    if (ctx->opts.trim) {
        value = XMLHash_trim_string(value, &str_len);
        xmlNodeAddContentLen(rootNode, BAD_CAST value, str_len);
    }
    else {
        xmlNodeAddContent(rootNode, BAD_CAST value);
    }
}

INLINE void
XMLHash_write_cdata2doc(convert_ctx_t *ctx, char *value, xmlNodePtr rootNode)
{
    int str_len;

    if (ctx->opts.trim) {
        value = XMLHash_trim_string(value, &str_len);
        (void) xmlAddChild(rootNode, xmlNewCDataBlock(rootNode->doc, BAD_CAST value, str_len));
    }
    else {
        (void) xmlAddChild(rootNode, xmlNewCDataBlock(rootNode->doc, BAD_CAST value, strlen(value)));
    }
}

INLINE void
XMLHash_write_comment2doc(convert_ctx_t *ctx, char *value, xmlNodePtr rootNode)
{
    int str_len;
    char ch;

    if (ctx->opts.trim) {
        value = XMLHash_trim_string(value, &str_len);
        ch = value[str_len];
        value[str_len] = '\0';
        (void) xmlAddChild(rootNode, xmlNewDocComment(rootNode->doc, BAD_CAST value));
        value[str_len] = ch;
    }
    else {
        (void) xmlAddChild(rootNode, xmlNewDocComment(rootNode->doc, BAD_CAST value));
    }
}

#endif
