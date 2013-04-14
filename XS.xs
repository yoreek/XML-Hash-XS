#include "EXTERN.h"
#include "perl.h"
#define NO_XSLOCKS
#include "XSUB.h"
#include "ppport.h"

#include <stdint.h>
#include <libxml/parser.h>
#ifdef XMLHASH_HAVE_ICONV
#include <iconv.h>
#endif
#ifdef XMLHASH_HAVE_ICU
#include <unicode/utypes.h>
#include <unicode/ucnv.h>
#endif

#ifndef MUTABLE_PTR
#if defined(__GNUC__) && !defined(PERL_GCC_BRACE_GROUPS_FORBIDDEN)
#  define MUTABLE_PTR(p) ({ void *_p = (p); _p; })
#else
#  define MUTABLE_PTR(p) ((void *) (p))
#endif
#endif

#ifndef MUTABLE_SV
#define MUTABLE_SV(p)   ((SV *)MUTABLE_PTR(p))
#endif

#if __GNUC__ >= 3
# define expect(expr,value)         __builtin_expect ((expr), (value))
# define INLINE                     static inline
#else
# define expect(expr,value)         (expr)
# define INLINE                     static
#endif

#define expect_false(expr) expect ((expr) != 0, 0)
#define expect_true(expr)  expect ((expr) != 0, 1)

#define FLAG_SIMPLE                     1
#define FLAG_COMPLEX                    2
#define FLAG_CONTENT                    4
#define FLAG_ATTR_ONLY                  8

#define MAX_RECURSION_DEPTH             128

#define BUFFER_WRITE(str, len)          XMLHash_writer_write(writer, str, len)
#define BUFFER_WRITE_CONSTANT(str)      XMLHash_writer_write(writer, str, sizeof(str) - 1)
#define BUFFER_WRITE_STRING(str,len)    XMLHash_writer_write(writer, str, len)
#define BUFFER_WRITE_ESCAPE(str, len)   XMLHash_writer_escape_content(writer, str, len)
#define BUFFER_WRITE_ESCAPE_ATTR(str)   XMLHash_writer_escape_attr(writer, str)
#define BUFFER_WRITE_QUOTED(str)        XMLHash_writer_write_quoted_string(writer, str)

#ifndef FALSE
#define FALSE (0)
#endif

#ifndef TRUE
#define TRUE  (1)
#endif

#define CONV_DEF_OUTPUT    NULL
#define CONV_DEF_METHOD    "NATIVE"
#define CONV_DEF_ROOT      "root"
#define CONV_DEF_VERSION   "1.0"
#define CONV_DEF_ENCODING  "utf-8"
#define CONV_DEF_INDENT    0
#define CONV_DEF_CANONICAL FALSE
#define CONV_DEF_USE_ATTR  FALSE
#define CONV_DEF_CONTENT   ""
#define CONV_DEF_XML_DECL  TRUE
#define CONV_DEF_DOC       FALSE

#define CONV_DEF_ATTR      "-"
#define CONV_DEF_TEXT      "#text"
#define CONV_DEF_TRIM      TRUE
#define CONV_DEF_CDATA     ""
#define CONV_DEF_COMM      ""

#define CONV_STR_PARAM_LEN 32

#define CONV_READ_PARAM_INIT                            \
    SV   *sv;                                           \
    char *str;
#define CONV_READ_STRING_PARAM(var, name, def_value)    \
    if ( (sv = get_sv(name, 0)) != NULL ) {             \
        if ( SvOK(sv) ) {                               \
            str = (char *) SvPV_nolen(sv);              \
            strncpy(var, str, CONV_STR_PARAM_LEN);      \
        }                                               \
        else {                                          \
            var[0] = '\0';                              \
        }                                               \
    }                                                   \
    else {                                              \
        strncpy(var, def_value, CONV_STR_PARAM_LEN);    \
    }
#define CONV_READ_BOOL_PARAM(var, name, def_value)      \
    if ( (sv = get_sv(name, 0)) != NULL ) {             \
        if ( SvTRUE(sv) ) {                             \
            var = TRUE;                                 \
        }                                               \
        else {                                          \
            var = FALSE;                                \
        }                                               \
    }                                                   \
    else {                                              \
        var = def_value;                                \
    }
#define CONV_READ_INT_PARAM(var, name, def_value)       \
    if ( (sv = get_sv(name, 0)) != NULL ) {             \
        var = SvIV(sv);                                 \
    }                                                   \
    else {                                              \
        var = def_value;                                \
    }
#define CONV_READ_REF_PARAM(var, name, def_value)       \
    if ( (sv = get_sv(name, 0)) != NULL ) {             \
        if ( SvOK(sv) && SvROK(sv) ) {                  \
            var = sv;                                   \
        }                                               \
        else {                                          \
            var = NULL;                                 \
        }                                               \
    }                                                   \
    else {                                              \
        var = def_value;                                \
    }

#define str3cmp(p, c0, c1, c2)                                                \
    *(uint32_t *) p == ((c2 << 16) | (c1 << 8) | c0)

#define str4cmp(p, c0, c1, c2, c3)                                            \
    *(uint32_t *) p == ((c3 << 24) | (c2 << 16) | (c1 << 8) | c0)

#define str5cmp(p, c0, c1, c2, c3, c4)                                        \
    *(uint32_t *) p == ((c3 << 24) | (c2 << 16) | (c1 << 8) | c0)             \
        && p[4] == c4

#define str6cmp(p, c0, c1, c2, c3, c4, c5)                                    \
    *(uint32_t *) p == ((c3 << 24) | (c2 << 16) | (c1 << 8) | c0)             \
        && (((uint32_t *) p)[1] & 0xffff) == ((c5 << 8) | c4)

#define str7cmp(p, c0, c1, c2, c3, c4, c5, c6)                                \
    *(uint32_t *) p == ((c3 << 24) | (c2 << 16) | (c1 << 8) | c0)             \
        && ((uint32_t *) p)[1] == ((c6 << 16) | (c5 << 8) | c4)

#define str8cmp(p, c0, c1, c2, c3, c4, c5, c6, c7)                            \
    *(uint32_t *) p == ((c3 << 24) | (c2 << 16) | (c1 << 8) | c0)             \
        && ((uint32_t *) p)[1] == ((c7 << 24) | (c6 << 16) | (c5 << 8) | c4)

#define str9cmp(p, c0, c1, c2, c3, c4, c5, c6, c7, c8)                        \
    *(uint32_t *) p == ((c3 << 24) | (c2 << 16) | (c1 << 8) | c0)             \
        && ((uint32_t *) p)[1] == ((c7 << 24) | (c6 << 16) | (c5 << 8) | c4)  \
        && p[8] == c8

typedef uintptr_t bool_t;

typedef enum {
    CONV_METHOD_NATIVE = 0,
    CONV_METHOD_NATIVE_ATTR_MODE,
    CONV_METHOD_LX
} convMethodType;

typedef struct _conv_buffer_t conv_buffer_t;
struct _conv_buffer_t {
    SV                    *scalar;
    char                  *start;
    char                  *cur;
    char                  *end;
};

#if defined(XMLHASH_HAVE_ICONV) || defined(XMLHASH_HAVE_ICU)
typedef enum {
    ENC_ICONV,
    ENC_ICU
} encoderType;

typedef struct _conv_encoder_t conv_encoder_t;
struct _conv_encoder_t {
    encoderType type;
#ifdef XMLHASH_HAVE_ICONV
    iconv_t     iconv;
#endif
#ifdef XMLHASH_HAVE_ICU
    UConverter *uconv; /* for conversion between an encoding and UTF-16 */
    UConverter *utf8;  /* for conversion between UTF-8 and UTF-16 */
#endif
};
#endif

typedef struct _conv_writer_t conv_writer_t;
struct _conv_writer_t {
#if defined(XMLHASH_HAVE_ICONV) || defined(XMLHASH_HAVE_ICU)
    conv_encoder_t        *encoder;
    conv_buffer_t          enc_buf;
#endif
    PerlIO                *perl_io;
    SV                    *perl_obj;
    conv_buffer_t          main_buf;
};

struct _conv_opts_t {
    convMethodType         method;

    /* native options */
    char                   version[CONV_STR_PARAM_LEN];
    char                   encoding[CONV_STR_PARAM_LEN];
    char                   root[CONV_STR_PARAM_LEN];
    bool_t                 xml_decl;
    bool_t                 canonical;
    char                   content[CONV_STR_PARAM_LEN];
    int                    indent;
    void                  *output;
    bool_t                 doc;

    /* LX options */
    char                   attr[CONV_STR_PARAM_LEN];
    int                    attr_len;
    char                   text[CONV_STR_PARAM_LEN];
    bool_t                 trim;
    char                   cdata[CONV_STR_PARAM_LEN];
    char                   comm[CONV_STR_PARAM_LEN];
};
typedef struct _conv_opts_t conv_opts_t;

typedef enum {
    TAG_OPEN,
    TAG_CLOSE,
    TAG_EMPTY,
    TAG_START,
    TAG_END
} tagType;

typedef struct {
    char *key;
    void *value;
} hash_entity_t;

typedef struct _stash_entity_t stash_entity_t;
struct _stash_entity_t {
    void                   *data;
    struct _stash_entity_t *next;
};

typedef struct {
    conv_opts_t        opts;
    int                recursion_depth;
    int                indent_count;
    stash_entity_t     stash;
    conv_writer_t     *writer;
} convert_ctx_t;

const char indent_string[60] = "                                                            ";

INLINE void XMLHash_write_item_no_attr(convert_ctx_t *ctx, char *name, SV *value);
INLINE void XMLHash_write_item_no_attr2doc(convert_ctx_t *ctx, char *name, SV *value, xmlNodePtr rootNode);
INLINE int  XMLHash_write_item(convert_ctx_t *ctx, char *name, SV *value, int flag);
INLINE void XMLHash_write_hash(convert_ctx_t *ctx, char *name, SV *hash);
INLINE void XMLHash_write_hash2doc(convert_ctx_t *ctx, char *name, SV *hash, xmlNodePtr rootNode);
INLINE void XMLHash_write_hash_lx(convert_ctx_t *ctx, SV *hash, int flag);
INLINE void XMLHash_write_hash_lx2doc(convert_ctx_t *ctx, SV *hash, int flag, xmlNodePtr rootNode);

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

ProxyNodePtr
x_PmmNewNode(xmlNodePtr node);

SV*
x_PmmNodeToSv( xmlNodePtr node, ProxyNodePtr owner );

SV* x_PROXY_NODE_REGISTRY_MUTEX = NULL;

const char*
x_PmmNodeTypeName( xmlNodePtr elem ){
    const char *name = "XML::LibXML::Node";

    if ( elem != NULL ) {
        switch ( elem->type ) {
        case XML_ELEMENT_NODE:
            name = "XML::LibXML::Element";
            break;
        case XML_TEXT_NODE:
            name = "XML::LibXML::Text";
            break;
        case XML_COMMENT_NODE:
            name = "XML::LibXML::Comment";
            break;
        case XML_CDATA_SECTION_NODE:
            name = "XML::LibXML::CDATASection";
            break;
        case XML_ATTRIBUTE_NODE:
            name = "XML::LibXML::Attr";
            break;
        case XML_DOCUMENT_NODE:
        case XML_HTML_DOCUMENT_NODE:
            name = "XML::LibXML::Document";
            break;
        case XML_DOCUMENT_FRAG_NODE:
            name = "XML::LibXML::DocumentFragment";
            break;
        case XML_NAMESPACE_DECL:
            name = "XML::LibXML::Namespace";
            break;
        case XML_DTD_NODE:
            name = "XML::LibXML::Dtd";
            break;
        case XML_PI_NODE:
            name = "XML::LibXML::PI";
            break;
        default:
            name = "XML::LibXML::Node";
            break;
        };
        return name;
    }
    return "";
}

ProxyNodePtr
x_PmmNewNode(xmlNodePtr node)
{
    ProxyNodePtr proxy = NULL;

    if ( node == NULL ) {
        return NULL;
    }

    if ( node->_private == NULL ) {
        switch ( node->type ) {
        case XML_DOCUMENT_NODE:
        case XML_HTML_DOCUMENT_NODE:
        case XML_DOCB_DOCUMENT_NODE:
            proxy = (ProxyNodePtr)xmlMalloc(sizeof(struct _DocProxyNode));
            if (proxy != NULL) {
                ((DocProxyNodePtr)proxy)->psvi_status = Pmm_NO_PSVI;
                x_SetPmmENCODING(proxy, XML_CHAR_ENCODING_NONE);
            }
            break;
        default:
            proxy = (ProxyNodePtr)xmlMalloc(sizeof(struct _ProxyNode));
            break;
        }
        if (proxy != NULL) {
            proxy->node  = node;
            proxy->owner   = NULL;
            proxy->count   = 0;
            node->_private = (void*) proxy;
        }
    }
    else {
        proxy = (ProxyNodePtr)node->_private;
    }

    return proxy;
}

SV*
x_PmmNodeToSv( xmlNodePtr node, ProxyNodePtr owner )
{
    ProxyNodePtr dfProxy= NULL;
    SV * retval = &PL_sv_undef;
    const char * CLASS = "XML::LibXML::Node";

    if ( node != NULL ) {
#ifdef XML_LIBXML_THREADS
        if( x_PmmUSEREGISTRY )
            SvLOCK(x_PROXY_NODE_REGISTRY_MUTEX);
#endif
        /* find out about the class */
        CLASS = x_PmmNodeTypeName( node );

        if ( node->_private != NULL ) {
            dfProxy = x_PmmNewNode(node);
            /* warn(" at 0x%08.8X\n", dfProxy); */
        }
        else {
            dfProxy = x_PmmNewNode(node);
            /* fprintf(stderr, " at 0x%08.8X\n", dfProxy); */
            if ( dfProxy != NULL ) {
                if ( owner != NULL ) {
                    dfProxy->owner = x_PmmNODE( owner );
                    x_PmmREFCNT_inc( owner );
                    /* fprintf(stderr, "REFCNT incremented on owner: 0x%08.8X\n", owner); */
                }
            }
            else {
                warn("x_PmmNodeToSv:   proxy creation failed!\n");
            }
        }

        retval = NEWSV(0,0);
        sv_setref_pv( retval, CLASS, (void*)dfProxy );
#ifdef XML_LIBXML_THREADS
    if( x_PmmUSEREGISTRY )
        x_PmmRegistryREFCNT_inc(dfProxy);
#endif
        x_PmmREFCNT_inc(dfProxy);
        /* fprintf(stderr, "REFCNT incremented on node: 0x%08.8X\n", dfProxy); */

        switch ( node->type ) {
        case XML_DOCUMENT_NODE:
        case XML_HTML_DOCUMENT_NODE:
        case XML_DOCB_DOCUMENT_NODE:
            if ( ((xmlDocPtr)node)->encoding != NULL ) {
                x_SetPmmENCODING(dfProxy, (int)xmlParseCharEncoding( (const char*)((xmlDocPtr)node)->encoding ));
            }
            break;
        default:
            break;
        }
#ifdef XML_LIBXML_THREADS
        if( x_PmmUSEREGISTRY )
            SvUNLOCK(x_PROXY_NODE_REGISTRY_MUTEX);
#endif
    }
    else {
        warn( "x_PmmNodeToSv: no node found!\n" );
    }

    return retval;
}

#ifdef XMLHASH_HAVE_ICU
void
XMLHash_encoder_uconv_destroy(UConverter *uconv)
{
    if (uconv != NULL) {
        ucnv_close(uconv);
    }
}

UConverter *
XMLHash_encoder_uconv_create(char *encoding, int toUnicode)
{
    UConverter *uconv;
    UErrorCode  status = U_ZERO_ERROR;

    uconv = ucnv_open(encoding, &status);
    if ( U_FAILURE(status) ) {
        return NULL;
    }

    if (toUnicode) {
        ucnv_setToUCallBack(uconv, UCNV_TO_U_CALLBACK_STOP,
                            NULL, NULL, NULL, &status);
    }
    else {
        ucnv_setFromUCallBack(uconv, UCNV_FROM_U_CALLBACK_STOP,
                              NULL, NULL, NULL, &status);
    }

    return uconv;
}
#endif

#if defined(XMLHASH_HAVE_ICONV) || defined(XMLHASH_HAVE_ICU)
void
XMLHash_encoder_destroy(conv_encoder_t *encoder)
{
    if (encoder != NULL) {
#ifdef XMLHASH_HAVE_ICONV
        if (encoder->iconv != NULL) {
            iconv_close(encoder->iconv);
        }
#endif

#ifdef XMLHASH_HAVE_ICU
        XMLHash_encoder_uconv_destroy(encoder->uconv);
        XMLHash_encoder_uconv_destroy(encoder->utf8);
#endif
        free(encoder);
    }
}

conv_encoder_t *
XMLHash_encoder_create(char *encoding)
{
    conv_encoder_t *encoder;

    encoder = malloc(sizeof(conv_encoder_t));
    if (encoder == NULL) {
        return NULL;
    }
    memset(encoder, 0, sizeof(conv_encoder_t));

#ifdef XMLHASH_HAVE_ICONV
    encoder->iconv = iconv_open(encoding, "UTF-8");
    if (encoder->iconv != (iconv_t) -1) {
        encoder->type = ENC_ICONV;
        return encoder;
    }
    iconv_close(encoder->iconv);
    encoder->iconv = NULL;
#endif

#ifdef XMLHASH_HAVE_ICU
    encoder->uconv = XMLHash_encoder_uconv_create(encoding, 1);
    if (encoder->uconv != NULL) {
        encoder->utf8 = XMLHash_encoder_uconv_create("UTF-8", 0);
        if (encoder->utf8 != NULL) {
            encoder->type = ENC_ICU;
            return encoder;
        }
    }
#endif

    XMLHash_encoder_destroy(encoder);

    return NULL;
}
#endif

void
XMLHash_writer_buffer_init(conv_buffer_t *buf, int size)
{
    buf->scalar = newSV(size);
    sv_setpv(buf->scalar, "");

    buf->start = buf->cur = SvPVX(buf->scalar);
    buf->end   = buf->start + size;
}

void
XMLHash_writer_buffer_resize(conv_buffer_t *buf, int inc)
{
    if (inc <= (buf->end - buf->cur)) {
        return;
    }

    int size = buf->end - buf->start;
    int use  = buf->cur - buf->start;

    size += inc < size ? size : inc;

    SvCUR_set(buf->scalar, use);
    SvGROW(buf->scalar, size);

    buf->start = SvPVX(buf->scalar);
    buf->cur   = buf->start + use;
    buf->end   = buf->start + size;
}

INLINE void
XMLHash_writer_write_to_perl_obj(conv_buffer_t *buf, SV *perl_obj)
{
    int len = buf->cur - buf->start;

    if (len > 0) {
        *buf->cur = '\0';
        SvCUR_set(buf->scalar, len);

        dSP;

        ENTER;
        SAVETMPS;

        PUSHMARK(SP);
        EXTEND(SP, 2);
        PUSHs((SV *) perl_obj);
        PUSHs(buf->scalar);
        PUTBACK;

        call_method("PRINT", G_SCALAR);

        FREETMPS;
        LEAVE;

        buf->cur = buf->start;
    }
}

INLINE void
XMLHash_writer_write_to_perl_io(conv_buffer_t *buf, PerlIO *perl_io)
{
    int len = buf->cur - buf->start;

    if (len > 0) {
        *buf->cur = '\0';
        SvCUR_set(buf->scalar, len);

        PerlIO_write(perl_io, buf->start, len);

        buf->cur = buf->start;
    }
}

INLINE SV *
XMLHash_writer_write_to_perl_scalar(conv_buffer_t *buf)
{
    *buf->cur = '\0';
    SvCUR_set(buf->scalar, buf->cur - buf->start);

    return buf->scalar;
}

SV *
XMLHash_writer_flush_buffer(conv_writer_t *writer, conv_buffer_t *buf)
{
    if (writer->perl_obj != NULL) {
        XMLHash_writer_write_to_perl_obj(buf, writer->perl_obj);
        return &PL_sv_undef;
    }
    else if (writer->perl_io != NULL) {
        XMLHash_writer_write_to_perl_io(buf, writer->perl_io);
        return &PL_sv_undef;
    }

    return XMLHash_writer_write_to_perl_scalar(buf);
}

#if defined(XMLHASH_HAVE_ICONV) || defined(XMLHASH_HAVE_ICU)
void
XMLHash_writer_encode_buffer(conv_writer_t *writer, conv_buffer_t *main_buf, conv_buffer_t *enc_buf)
{
    int   len  = (main_buf->cur - main_buf->start) * 4 + 1;
    char *src  = main_buf->start;

    if (len > (enc_buf->end - enc_buf->cur)) {
        XMLHash_writer_flush_buffer(writer, enc_buf);

        XMLHash_writer_buffer_resize(enc_buf, len);
    }

#ifdef XMLHASH_HAVE_ICONV
    if (writer->encoder->type == ENC_ICONV) {
        size_t in_left  = main_buf->cur - main_buf->start;
        size_t out_left = enc_buf->end - enc_buf->cur;

        size_t converted = iconv(writer->encoder->iconv, &src, &in_left, &enc_buf->cur, &out_left);
        if (converted == (size_t) -1) {
            croak("Convert error");
        }
        return;
    }
#endif

#ifdef XMLHASH_HAVE_ICU
    UErrorCode  err  = U_ZERO_ERROR;
    ucnv_convertEx(writer->encoder->uconv, writer->encoder->utf8, &enc_buf->cur, enc_buf->end,
                   (const char **) &src, main_buf->cur, NULL, NULL, NULL, NULL,
                   FALSE, TRUE, &err);

    if ( U_FAILURE(err) ) {
        croak("Convert error: %d", err);
    }
#endif
}
#endif

SV *
XMLHash_writer_flush(conv_writer_t *writer)
{
    conv_buffer_t *buf;

#if defined(XMLHASH_HAVE_ICONV) || defined(XMLHASH_HAVE_ICU)
    if (writer->encoder != NULL) {
        XMLHash_writer_encode_buffer(writer, &writer->main_buf, &writer->enc_buf);
        buf = &writer->enc_buf;
    }
    else {
        buf = &writer->main_buf;
    }
#else
    buf = &writer->main_buf;
#endif

    return XMLHash_writer_flush_buffer(writer, buf);
}

void
XMLHash_writer_resize_buffer(conv_writer_t *writer, int inc)
{
    (void) XMLHash_writer_flush(writer);

    XMLHash_writer_buffer_resize(&writer->main_buf, inc);
}

INLINE void
XMLHash_writer_destroy(conv_writer_t *writer)
{
    if (writer != NULL) {
        if (writer->perl_obj != NULL || writer->perl_io != NULL) {
            SvREFCNT_dec(writer->main_buf.scalar);
#if defined(XMLHASH_HAVE_ICONV) || defined(XMLHASH_HAVE_ICU)
            SvREFCNT_dec(writer->enc_buf.scalar);
        }
        else if (writer->encoder != NULL) {
            SvREFCNT_dec(writer->main_buf.scalar);
#endif
        }

#if defined(XMLHASH_HAVE_ICONV) || defined(XMLHASH_HAVE_ICU)
        XMLHash_encoder_destroy(writer->encoder);
#endif
        free(writer);
    }
}

INLINE conv_writer_t *
XMLHash_writer_create(conv_opts_t *opts, int size)
{
    conv_writer_t *writer;

    writer = malloc(sizeof(conv_writer_t));
    if (writer == NULL) {
        croak("Memory allocation error");
    }
    memset(writer, 0, sizeof(conv_writer_t));

    XMLHash_writer_buffer_init(&writer->main_buf, size);

    if (strcasecmp(opts->encoding, "UTF-8") != 0) {
#if defined(XMLHASH_HAVE_ICONV) || defined(XMLHASH_HAVE_ICU)
        writer->encoder = XMLHash_encoder_create(opts->encoding);
        if (writer->encoder == NULL) {
            croak("Can't create encoder for '%s'", opts->encoding);
        }

        XMLHash_writer_buffer_init(&writer->enc_buf, size * 4);
#else
        croak("Can't create encoder for '%s'", opts->encoding);
#endif
    }

    if (opts->output != NULL) {
        MAGIC  *mg;
        GV     *gv = (GV *) opts->output;
        IO     *io = GvIO(gv);

        if (io && (mg = SvTIED_mg((SV *)io, PERL_MAGIC_tiedscalar))) {
            /* tied handle */
            writer->perl_obj = SvTIED_obj(MUTABLE_SV(io), mg);
        }
        else {
            /* simple handle */
            writer->perl_io = IoOFP(io);
        }
    }

    return writer;
}

INLINE void
XMLHash_writer_write(conv_writer_t *writer, const char *content, int len) {
    conv_buffer_t *buf = &writer->main_buf;

    if (len > (buf->end - buf->cur -1)) {
        XMLHash_writer_resize_buffer(writer, len + 1);
    }

    if (len < 17) {
        while (len--) {
            *buf->cur++ = *content++;
        }
    }
    else {
        memcpy(buf->cur, content, len);
        buf->cur += len;
    }
}

INLINE void
XMLHash_writer_write_quoted_string(conv_writer_t *writer, const char *content)
{
    char           ch;
    const char    *cur;
    int            len = 0;
    int            dq  = 0;
    int            sq  = 0;
    conv_buffer_t *buf = &writer->main_buf;

    cur = content;
    while ((ch = *cur++) != '\0') {
        len++;
        if (ch == '"') {
            dq++;
        }
        else if (ch == '\'') {
            sq++;
        }
    }

    if (len == 0) return;

    len *= 6;

    if (len > (buf->end - buf->cur -1)) {
        XMLHash_writer_resize_buffer(writer, len + 1);
    }

    if (dq) {
        if (sq) {
            *buf->cur++ = '"';
            while ((ch = *content++) != '\0') {
                if (ch == '"') {
                    *buf->cur++ = '&';
                    *buf->cur++ = 'q';
                    *buf->cur++ = 'u';
                    *buf->cur++ = 'o';
                    *buf->cur++ = 't';
                    *buf->cur++ = ';';
                }
                else {
                    *buf->cur++ = ch;
                }
            }
            *buf->cur++ = '"';
        }
        else {
            *buf->cur++ = '\'';
            while ((ch = *content++) != '\0') {
                *buf->cur++ = ch;
            }
            *buf->cur++ = '\'';
        }
    }
    else {
        *buf->cur++ = '"';
        while ((ch = *content++) != '\0') {
            *buf->cur++ = ch;
        }
        *buf->cur++ = '"';
    }
}

INLINE void
XMLHash_writer_escape_attr(conv_writer_t *writer, const char *content)
{
    char           ch;
    int            len = strlen(content) * 6;
    conv_buffer_t *buf = &writer->main_buf;

    if (len > (buf->end - buf->cur -1)) {
        XMLHash_writer_resize_buffer(writer, len + 1);
    }

    while ((ch = *content++) != 0) {
        switch (ch) {
            case '\n':
                *buf->cur++ = '&';
                *buf->cur++ = '#';
                *buf->cur++ = '1';
                *buf->cur++ = '0';
                *buf->cur++ = ';';
                break;
            case '\r':
                *buf->cur++ = '&';
                *buf->cur++ = '#';
                *buf->cur++ = '1';
                *buf->cur++ = '3';
                *buf->cur++ = ';';
                break;
            case '\t':
                *buf->cur++ = '&';
                *buf->cur++ = '#';
                *buf->cur++ = '9';
                *buf->cur++ = ';';
                break;
            case '<':
                *buf->cur++ = '&';
                *buf->cur++ = 'l';
                *buf->cur++ = 't';
                *buf->cur++ = ';';
                break;
            case '>':
                *buf->cur++ = '&';
                *buf->cur++ = 'g';
                *buf->cur++ = 't';
                *buf->cur++ = ';';
                break;
            case '&':
                *buf->cur++ = '&';
                *buf->cur++ = 'a';
                *buf->cur++ = 'm';
                *buf->cur++ = 'p';
                *buf->cur++ = ';';
                break;
            case '"':
                *buf->cur++ = '&';
                *buf->cur++ = 'q';
                *buf->cur++ = 'u';
                *buf->cur++ = 'o';
                *buf->cur++ = 't';
                *buf->cur++ = ';';
                break;
            default:
                *buf->cur++ = ch;
        }
    }
}

INLINE void
XMLHash_writer_escape_content(conv_writer_t *writer, const char *content, int len)
{
    char           ch;
    int            max_len;
    conv_buffer_t *buf = &writer->main_buf;

    if (len == -1) len = strlen(content);
    max_len = len * 5;

    if (max_len > (buf->end - buf->cur - 1)) {
        XMLHash_writer_resize_buffer(writer, max_len + 1);
    }

    while (len--) {
        ch = *content++;
        switch (ch) {
            case '\r':
                *buf->cur++ = '&';
                *buf->cur++ = '#';
                *buf->cur++ = '1';
                *buf->cur++ = '3';
                *buf->cur++ = ';';
                break;
            case '<':
                *buf->cur++ = '&';
                *buf->cur++ = 'l';
                *buf->cur++ = 't';
                *buf->cur++ = ';';
                break;
            case '>':
                *buf->cur++ = '&';
                *buf->cur++ = 'g';
                *buf->cur++ = 't';
                *buf->cur++ = ';';
                break;
            case '&':
                *buf->cur++ = '&';
                *buf->cur++ = 'a';
                *buf->cur++ = 'm';
                *buf->cur++ = 'p';
                *buf->cur++ = ';';
                break;
            default:
                *buf->cur++ = ch;
        }
    }
}

static int
cmpstringp(const void *p1, const void *p2)
{
    hash_entity_t *e1, *e2;
    e1 = (hash_entity_t *) p1;
    e2 = (hash_entity_t *) p2;
    return strcmp(e1->key, e2->key);
}

INLINE char *
XMLHash_trim_string(char *s, int *len)
{
    char *cur, *end, ch;
    int first = 1;

    end = cur = s;
    while ((ch = *cur++) != '\0') {
        switch (ch) {
            case ' ':
            case '\t':
            case '\n':
            case '\r':
                if (first) {
                    s = end = cur;
                }
                break;
            default:
                if (first) {
                    first--;
                }
                end = cur;
        }
    }

    *len = end - s;

    return s;
}

INLINE void
XMLHash_write_tag(convert_ctx_t *ctx, tagType type, char *name, int indent, int lf)
{
    int            indent_len;
    conv_writer_t *writer = ctx->writer;

    if (name == NULL) return;

    if (indent) {
        indent_len = ctx->indent_count * indent;
        if (indent_len > sizeof(indent_string))
            indent_len = sizeof(indent_string);

        BUFFER_WRITE(indent_string, indent_len);
    }

    if (type == TAG_CLOSE) {
        BUFFER_WRITE_CONSTANT("</");
    }
    else {
        BUFFER_WRITE_CONSTANT("<");
    }

    if (name[0] >= '1' && name[0] <= '9')
        BUFFER_WRITE_CONSTANT("_");

    BUFFER_WRITE_STRING(name, strlen(name));

    if (type == TAG_EMPTY) {
        BUFFER_WRITE_CONSTANT("/>");
    }
    else if (type == TAG_CLOSE || type == TAG_OPEN) {
        BUFFER_WRITE_CONSTANT(">");
    }

    if (lf)
        BUFFER_WRITE_CONSTANT("\n");
}

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
XMLHash_write_content(convert_ctx_t *ctx, char *value, int indent, int lf)
{
    int            indent_len, str_len;
    conv_writer_t *writer = ctx->writer;

    if (indent) {
        indent_len = ctx->indent_count * indent;
        if (indent_len > sizeof(indent_string))
            indent_len = sizeof(indent_string);

        BUFFER_WRITE(indent_string, indent_len);
    }

    if (ctx->opts.trim) {
        value = XMLHash_trim_string(value, &str_len);
        BUFFER_WRITE_ESCAPE(value, str_len);
    }
    else {
        BUFFER_WRITE_ESCAPE(value, -1);
    }

    if (lf)
        BUFFER_WRITE_CONSTANT("\n");
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
XMLHash_write_cdata(convert_ctx_t *ctx, char *value, int indent, int lf)
{
    int            indent_len, str_len;
    conv_writer_t *writer = ctx->writer;

    if (indent) {
        indent_len = ctx->indent_count * indent;
        if (indent_len > sizeof(indent_string))
            indent_len = sizeof(indent_string);

        BUFFER_WRITE(indent_string, indent_len);
    }

    BUFFER_WRITE_CONSTANT("<![CDATA[");
    if (ctx->opts.trim) {
        value = XMLHash_trim_string(value, &str_len);
        BUFFER_WRITE_STRING(value, str_len);
    }
    else {
        BUFFER_WRITE_STRING(value, strlen(value));
    }
    BUFFER_WRITE_CONSTANT("]]>");

    if (lf)
        BUFFER_WRITE_CONSTANT("\n");
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
XMLHash_write_comment(convert_ctx_t *ctx, char *value, int indent, int lf)
{
    int            indent_len, str_len;
    conv_writer_t *writer = ctx->writer;

    if (indent) {
        indent_len = ctx->indent_count * indent;
        if (indent_len > sizeof(indent_string))
            indent_len = sizeof(indent_string);

        BUFFER_WRITE(indent_string, indent_len);
    }

    BUFFER_WRITE_CONSTANT("<!--");
    if (ctx->opts.trim) {
        value = XMLHash_trim_string(value, &str_len);
        BUFFER_WRITE_STRING(value, str_len);
    }
    else {
        BUFFER_WRITE_STRING(value, strlen(value));
    }
    BUFFER_WRITE_CONSTANT("-->");

    if (lf)
        BUFFER_WRITE_CONSTANT("\n");
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

INLINE void
XMLHash_write_attribute_element(convert_ctx_t *ctx, char *name, char *value)
{
    if (name == NULL) return;

    conv_writer_t *writer = ctx->writer;

    BUFFER_WRITE_CONSTANT(" ");
    BUFFER_WRITE_STRING(name, strlen(name));
    BUFFER_WRITE_CONSTANT("=\"");
    BUFFER_WRITE_ESCAPE_ATTR(value);
    BUFFER_WRITE_CONSTANT("\"");
}

INLINE void
XMLHash_stash_push(stash_entity_t *stash, void *data)
{
    stash_entity_t *ent;
    ent = malloc(sizeof(stash_entity_t));
    if (ent == NULL)
        croak("Malloc error");

    ent->data   = data;
    ent->next   = stash->next;
    stash->next = ent;
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

INLINE void
XMLHash_resolve_value(convert_ctx_t *ctx, SV **value, SV **value_ref, int *raw)
{
    int count;
    SV *sv;

    *raw = 0;

    while ( *value && SvROK(*value) ) {
        if (++ctx->recursion_depth > MAX_RECURSION_DEPTH)
            croak("Maximum recursion depth exceeded");

        *value_ref = *value;
        *value     = SvRV(*value);
        sv         = *value;

        if (expect_false( SvOBJECT(sv) )) {
            /* object */
            GV *to_string = gv_fetchmethod_autoload (SvSTASH (sv), "toString", 0);
            if (to_string) {
                dSP;

                ENTER; SAVETMPS; PUSHMARK (SP);
                XPUSHs (sv_bless (sv_2mortal (newRV_inc (sv)), SvSTASH (sv)));

                /* calling with G_SCALAR ensures that we always get a 1 return value */
                PUTBACK;
                call_sv ((SV *)GvCV (to_string), G_SCALAR);
                SPAGAIN;

                /* catch this surprisingly common error */
                if (SvROK (TOPs) && SvRV (TOPs) == sv)
                    croak("%s::toString method returned same object as was passed instead of a new one", HvNAME (SvSTASH (sv)));

                *value = POPs;
                PUTBACK;

                SvREFCNT_inc(*value);

                XMLHash_stash_push(&ctx->stash, *value);

                FREETMPS; LEAVE;

                *raw = 1;

                continue;
            }
        }
        else if(SvTYPE(*value) == SVt_PVCV) {
            /* code ref */
            *raw = 0;

            dSP;

            ENTER; SAVETMPS; PUSHMARK (SP);

            count = call_sv(*value, G_SCALAR|G_NOARGS);

            SPAGAIN;

            if (count == 1) {
                *value = POPs;

                SvREFCNT_inc(*value);

                XMLHash_stash_push(&ctx->stash, *value);

                PUTBACK;

                FREETMPS;
                LEAVE;

                continue;
            }
            else {
                *value = NULL;
            }
        }
    }
}

void
XMLHash_write_hash_no_attr(convert_ctx_t *ctx, char *name, SV *hash)
{
    SV   *value;
    HV   *hv;
    char *key;
    I32   keylen;
    int   i, len;

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

    XMLHash_write_tag(ctx, TAG_OPEN, name, ctx->opts.indent, ctx->opts.indent);

    ctx->indent_count++;

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

        qsort(&a, len, sizeof(hash_entity_t), cmpstringp);

        for (i = 0; i < len; i++) {
            key   = a[i].key;
            value = a[i].value;
            XMLHash_write_item_no_attr(ctx, key, value);
        }
    }
    else {
        while ((value = hv_iternextsv(hv, &key, &keylen))) {
            XMLHash_write_item_no_attr(ctx, key, value);
        }
    }

    ctx->indent_count--;

    XMLHash_write_tag(ctx, TAG_CLOSE, name, ctx->opts.indent, ctx->opts.indent);
}

void
XMLHash_write_item_no_attr(convert_ctx_t *ctx, char *name, SV *value)
{
    I32            i, len;
    int            raw;
    SV            *value_ref = NULL;
    char          *str;
    STRLEN         str_len;
    conv_writer_t *writer = ctx->writer;

    XMLHash_resolve_value(ctx, &value, &value_ref, &raw);

    switch (SvTYPE(value)) {
        case SVt_NULL:
            XMLHash_write_tag(ctx, TAG_EMPTY, name, ctx->opts.indent, ctx->opts.indent);
            break;
        case SVt_IV:
        case SVt_PVIV:
        case SVt_PVNV:
        case SVt_NV:
        case SVt_PV:
            /* integer, double, scalar */
            XMLHash_write_tag(ctx, TAG_OPEN, name, ctx->opts.indent, 0);
            str = SvPV(value, str_len);
            if (raw) {
                BUFFER_WRITE_STRING(str, str_len);
            }
            else {
                BUFFER_WRITE_ESCAPE(str, str_len);
            }
            XMLHash_write_tag(ctx, TAG_CLOSE, name, 0, ctx->opts.indent);
            break;
        case SVt_PVAV:
            /* array */
            len = av_len((AV *) value);
            for (i = 0; i <= len; i++) {
                XMLHash_write_item_no_attr(ctx, name, *av_fetch((AV *) value, i, 0));
            }
            break;
        case SVt_PVHV:
            /* hash */
            XMLHash_write_hash_no_attr(ctx, name, value_ref);
            break;
        case SVt_PVMG:
            /* blessed */
            if (SvOK(value)) {
                str = SvPV(value, str_len);
                XMLHash_write_tag(ctx, TAG_OPEN, name, ctx->opts.indent, 0);
                if (raw) {
                    BUFFER_WRITE_STRING(str, str_len);
                }
                else {
                    BUFFER_WRITE_ESCAPE(str, str_len);
                }
                XMLHash_write_tag(ctx, TAG_CLOSE, name, 0, ctx->opts.indent);
                break;
            }
        default:
            XMLHash_write_tag(ctx, TAG_EMPTY, name, ctx->opts.indent, ctx->opts.indent);
    }

    ctx->recursion_depth--;
}

void
XMLHash_write_hash_no_attr2doc(convert_ctx_t *ctx, char *name, SV *hash, xmlNodePtr rootNode)
{
    SV   *value;
    HV   *hv;
    char *key;
    I32   keylen;
    int   i, len;

    if (!SvROK(hash)) {
        warn("parameter is not reference\n");
        return;
    }

    hv  = (HV *) SvRV(hash);
    len = HvUSEDKEYS(hv);

    rootNode = XMLHash_write_tag2doc(name, NULL, rootNode);

    if (len == 0) {
        return;
    }

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

        qsort(&a, len, sizeof(hash_entity_t), cmpstringp);

        for (i = 0; i < len; i++) {
            key   = a[i].key;
            value = a[i].value;
            XMLHash_write_item_no_attr2doc(ctx, key, value, rootNode);
        }
    }
    else {
        while ((value = hv_iternextsv(hv, &key, &keylen))) {
            XMLHash_write_item_no_attr2doc(ctx, key, value, rootNode);
        }
    }
}

void
XMLHash_write_item_no_attr2doc(convert_ctx_t *ctx, char *name, SV *value, xmlNodePtr rootNode)
{
    I32        i, len;
    int        raw;
    SV        *value_ref = NULL;
    char      *str;
    STRLEN     str_len;

    XMLHash_resolve_value(ctx, &value, &value_ref, &raw);

    switch (SvTYPE(value)) {
        case SVt_NULL:
            (void) XMLHash_write_tag2doc(name, NULL, rootNode);
            break;
        case SVt_IV:
        case SVt_PVIV:
        case SVt_PVNV:
        case SVt_NV:
        case SVt_PV:
            /* integer, double, scalar */
            str = SvPV(value, str_len);
            if (raw) {
                (void) XMLHash_write_tag2doc(name, str, rootNode);
            }
            else {
                (void) XMLHash_write_tag2doc_escaped(name, str, rootNode);
            }
            break;
        case SVt_PVAV:
            /* array */
            len = av_len((AV *) value);
            for (i = 0; i <= len; i++) {
                XMLHash_write_item_no_attr2doc(ctx, name, *av_fetch((AV *) value, i, 0), rootNode);
            }
            break;
        case SVt_PVHV:
            /* hash */
            XMLHash_write_hash_no_attr2doc(ctx, name, value_ref, rootNode);
            break;
        case SVt_PVMG:
            /* blessed */
            if (SvOK(value)) {
                str = SvPV(value, str_len);
                if (raw) {
                    (void) XMLHash_write_tag2doc(name, str, rootNode);
                }
                else {
                    (void) XMLHash_write_tag2doc_escaped(name, str, rootNode);
                }
                break;
            }
        default:
            (void) XMLHash_write_tag2doc(name, NULL, rootNode);
    }

    ctx->recursion_depth--;
}

int
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

void
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

        qsort(&a, len, sizeof(hash_entity_t), cmpstringp);

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

        qsort(&a, len, sizeof(hash_entity_t), cmpstringp);

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

void
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
                                XMLHash_write_attribute_element(ctx, key, (char *) "");
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

void
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

void
XMLHash_conv_destroy(conv_opts_t *conv_opts)
{
    if (conv_opts != NULL) {
        free(conv_opts);
    }
}

bool_t
XMLHash_conv_init_options(conv_opts_t *opts)
{
    char   method[CONV_STR_PARAM_LEN];
    bool_t use_attr;

    CONV_READ_PARAM_INIT

    /* native options */
    CONV_READ_STRING_PARAM(opts->root,      "XML::Hash::XS::root",      CONV_DEF_ROOT);
    CONV_READ_STRING_PARAM(opts->version,   "XML::Hash::XS::version",   CONV_DEF_VERSION);
    CONV_READ_STRING_PARAM(opts->encoding,  "XML::Hash::XS::encoding",  CONV_DEF_ENCODING);
    CONV_READ_INT_PARAM   (opts->indent,    "XML::Hash::XS::indent",    CONV_DEF_INDENT);
    CONV_READ_BOOL_PARAM  (opts->canonical, "XML::Hash::XS::canonical", CONV_DEF_CANONICAL);
    CONV_READ_STRING_PARAM(opts->content,   "XML::Hash::XS::content",   CONV_DEF_CONTENT);
    CONV_READ_BOOL_PARAM  (opts->xml_decl,  "XML::Hash::XS::xml_decl",  CONV_DEF_XML_DECL);
    CONV_READ_BOOL_PARAM  (opts->doc,       "XML::Hash::XS::doc",       CONV_DEF_DOC);
    CONV_READ_BOOL_PARAM  (use_attr,        "XML::Hash::XS::use_attr",  CONV_DEF_USE_ATTR);

    /* XML::Hash::LX options */
    CONV_READ_STRING_PARAM(opts->attr,      "XML::Hash::XS::attr",      CONV_DEF_ATTR);
    opts->attr_len = strlen(opts->attr);
    CONV_READ_STRING_PARAM(opts->text,      "XML::Hash::XS::text",      CONV_DEF_TEXT);
    CONV_READ_BOOL_PARAM  (opts->trim,      "XML::Hash::XS::trim",      CONV_DEF_TRIM);
    CONV_READ_STRING_PARAM(opts->cdata,     "XML::Hash::XS::cdata",     CONV_DEF_CDATA);
    CONV_READ_STRING_PARAM(opts->comm,      "XML::Hash::XS::comm",      CONV_DEF_COMM);

    /* method */
    CONV_READ_STRING_PARAM(method,          "XML::Hash::XS::method",    CONV_DEF_METHOD);
    if (strcmp(method, "LX") == 0) {
        opts->method = CONV_METHOD_LX;
    }
    else if (use_attr) {
        opts->method = CONV_METHOD_NATIVE_ATTR_MODE;
    }
    else {
        opts->method = CONV_METHOD_NATIVE;
    }

    /* output, NULL - to string */
    CONV_READ_REF_PARAM   (opts->output,    "XML::Hash::XS::output",    CONV_DEF_OUTPUT);

    return TRUE;
}

conv_opts_t *
XMLHash_conv_create(void)
{
    conv_opts_t *conv_opts;

    if ((conv_opts = malloc(sizeof(conv_opts_t))) == NULL) {
        return NULL;
    }
    memset(conv_opts, 0, sizeof(conv_opts_t));

    if (! XMLHash_conv_init_options(conv_opts)) {
        XMLHash_conv_destroy(conv_opts);
        return NULL;
    }

    return conv_opts;
}

void
XMLHash_conv_assign_string_param(char param[], SV *value)
{
    char *str;

    if ( SvOK(value) ) {
        str = (char *) SvPV_nolen(value);
        strncpy(param, str, CONV_STR_PARAM_LEN);
    }
    else {
        *param = 0;
    }
}

void
XMLHash_conv_assign_int_param(char *name, int *param, SV *value)
{
    if ( !SvOK(value) ) {
        croak("Parameter '%s' is undefined", name);
    }
    *param = SvIV(value);
}

bool_t
XMLHash_conv_assign_bool_param(SV *value)
{
    if ( SvTRUE(value) ) {
        return TRUE;
    }
    return FALSE;
}

void
XMLHash_conv_parse_param(conv_opts_t *opts, int first, I32 ax, I32 items)
{
    if ((items - first) % 2 != 0) {
        croak("Odd number of parameters in new()");
    }

    int      i;
    char    *p, *cv;
    SV      *v;
    STRLEN   len;
    bool_t   use_attr = -1;

    for (i = first; i < items; i = i + 2) {
        v = ST(i);
        if (!SvOK(v)) {
            croak("Parameter name is undefined");
        }

        p = (char *) SvPV(v, len);
        v = ST(i + 1);

        switch (len) {
            case 3:
                if (str3cmp(p, 'd', 'o', 'c')) {
                    opts->doc = XMLHash_conv_assign_bool_param(v);
                    break;
                }
                goto error;
            case 4:
                if (str4cmp(p, 'a', 't', 't', 'r')) {
                    XMLHash_conv_assign_string_param(opts->attr, v);
                    if (opts->attr[0] == '\0') {
                        opts->attr_len = 0;
                    }
                    else {
                        opts->attr_len = strlen(opts->attr);
                    }
                    break;
                }
                if (str4cmp(p, 'c', 'o', 'm', 'm')) {
                    XMLHash_conv_assign_string_param(opts->comm, v);
                    break;
                }
                if (str4cmp(p, 'r', 'o', 'o', 't')) {
                    XMLHash_conv_assign_string_param(opts->root, v);
                    break;
                }
                if (str4cmp(p, 't', 'r', 'i', 'm')) {
                    opts->trim = XMLHash_conv_assign_bool_param(v);
                    break;
                }
                if (str4cmp(p, 't', 'e', 'x', 't')) {
                    XMLHash_conv_assign_string_param(opts->text, v);
                    break;
                }
                goto error;
            case 5:
                if (str5cmp(p, 'c', 'd', 'a', 't', 'a')) {
                    XMLHash_conv_assign_string_param(opts->cdata, v);
                    break;
                }
                goto error;
            case 6:
                if (str6cmp(p, 'i', 'n', 'd', 'e', 'n', 't')) {
                    XMLHash_conv_assign_int_param(p, &opts->indent, v);
                    break;
                }
                if (str6cmp(p, 'm', 'e', 't', 'h', 'o', 'd')) {
                    if (!SvOK(v)) {
                        croak("Parameter '%s' is undefined", p);
                    }
                    cv = SvPV(v, len);
                    switch  (len) {
                        case 6:
                            if (str6cmp(cv, 'N', 'A', 'T', 'I', 'V', 'E')) {
                                opts->method = CONV_METHOD_NATIVE;
                                break;
                            }
                            goto error_value;
                        case 2:
                            if (cv[0] == 'L' && cv[1] == 'X') {
                                opts->method = CONV_METHOD_LX;
                                break;
                            }
                            goto error_value;
                        default:
                            goto error_value;
                    }
                    break;
                }
                if (str6cmp(p, 'o', 'u', 't', 'p', 'u', 't')) {
                    if ( SvOK(v) && SvROK(v) ) {
                        opts->output = SvRV(v);
                    }
                    else {
                        opts->output = NULL;
                    }
                    break;
                }
                goto error;
            case 7:
                if (str7cmp(p, 'c', 'o', 'n', 't', 'e', 'n', 't')) {
                    XMLHash_conv_assign_string_param(opts->content, v);
                    break;
                }
                if (str7cmp(p, 'v', 'e', 'r', 's', 'i', 'o', 'n')) {
                    XMLHash_conv_assign_string_param(opts->version, v);
                    break;
                }
                goto error;
            case 8:
                if (str8cmp(p, 'e', 'n', 'c', 'o', 'd', 'i', 'n', 'g')) {
                    XMLHash_conv_assign_string_param(opts->encoding, v);
                    break;
                }
                if (str8cmp(p, 'u', 's', 'e', '_', 'a', 't', 't', 'r')) {
                    use_attr = XMLHash_conv_assign_bool_param(v);
                    break;
                }
                if (str8cmp(p, 'x', 'm', 'l', '_', 'd', 'e', 'c', 'l')) {
                    opts->xml_decl = XMLHash_conv_assign_bool_param(v);
                    break;
                }
                goto error;
            case 9:
                if (str9cmp(p, 'c', 'a', 'n', 'o', 'n', 'i', 'c', 'a', 'l')) {
                    opts->canonical = XMLHash_conv_assign_bool_param(v);
                    break;
                }
                goto error;
            default:
                goto error;
        }
    }

    if (use_attr != -1 && (opts->method == CONV_METHOD_NATIVE || opts->method == CONV_METHOD_NATIVE_ATTR_MODE)) {
        if (use_attr == TRUE) {
            opts->method = CONV_METHOD_NATIVE_ATTR_MODE;
        }
        else {
            opts->method = CONV_METHOD_NATIVE;
        }
    }

    return;

error_value:
    croak("Invalid parameter value for '%s': %s", p, cv);
    return;

error:
    croak("Invalid parameter '%s'", p);
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
        ctx->writer = writer = XMLHash_writer_create(&ctx->opts, 16384);

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

MODULE = XML::Hash::XS PACKAGE = XML::Hash::XS

PROTOTYPES: DISABLE

conv_opts_t *
new(CLASS,...)
    PREINIT:
        conv_opts_t  *conv_opts;
    CODE:
        if ((conv_opts = XMLHash_conv_create()) == NULL) {
            croak("Malloc error in new()");
        }

        dXCPT;
        XCPT_TRY_START
        {
            XMLHash_conv_parse_param(conv_opts, 1, ax, items);
        } XCPT_TRY_END

        XCPT_CATCH
        {
            XMLHash_conv_destroy(conv_opts);
            XCPT_RETHROW;
        }

        RETVAL = conv_opts;
    OUTPUT:
        RETVAL

SV *
hash2xml(...)
    PREINIT:
        conv_opts_t   *conv_opts = NULL;
        convert_ctx_t  ctx;
        SV            *p, *hash, *result;
        int            nparam    = 0;
    CODE:
        /* get object reference */
        if (nparam >= items)
            croak("Invalid parameters");

        p = ST(nparam);
        if ( sv_isa(p, "XML::Hash::XS") ) {
            /* reference to object */
            IV tmp = SvIV((SV *) SvRV(p));
            conv_opts = INT2PTR(conv_opts_t *, tmp);
            nparam++;
        }
        else if ( SvTYPE(p) == SVt_PV ) {
            /* class name */
            nparam++;
        }

        /* get hash reference */
        if (nparam >= items)
            croak("Invalid parameters");

        p = ST(nparam);
        if (SvROK(p) && SvTYPE(SvRV(p)) == SVt_PVHV) {
            hash = p;
            nparam++;
        }
        else {
            croak("Parameter is not hash reference");
        }

        /* set options */
        memset(&ctx, 0, sizeof(convert_ctx_t));
        if (conv_opts == NULL) {
            /* read global options */
            XMLHash_conv_init_options(&ctx.opts);
        }
        else {
            /* read options from object */
            memcpy(&ctx.opts, conv_opts, sizeof(conv_opts_t));
        }
        if (nparam < items) {
            XMLHash_conv_parse_param(&ctx.opts, nparam, ax, items);
        }

        /* run */
        if (ctx.opts.doc) {
            result = XMLHash_hash2dom(&ctx, hash);
        }
        else {
            result = XMLHash_hash2xml(&ctx, hash);
        }

        if (ctx.opts.output != NULL) {
            XSRETURN_UNDEF;
        }

        if (result == NULL) {
            warn("Failed to convert");
            XSRETURN_UNDEF;
        }

        RETVAL = result;

    OUTPUT:
        RETVAL

void
DESTROY(conv)
        conv_opts_t *conv;
    CODE:
        XMLHash_conv_destroy(conv);
