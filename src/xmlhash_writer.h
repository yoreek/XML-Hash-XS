#ifndef _XMLHASH_WRITER_H_
#define _XMLHASH_WRITER_H_

#include "xmlhash_common.h"

#ifdef XMLHASH_HAVE_ICONV
#include <iconv.h>
#endif
#ifdef XMLHASH_HAVE_ICU
#include <unicode/utypes.h>
#include <unicode/ucnv.h>
#endif

#define BUFFER_WRITE(str, len)          XMLHash_writer_write(writer, str, len)
#define BUFFER_WRITE_CONSTANT(str)      XMLHash_writer_write(writer, str, sizeof(str) - 1)
#define BUFFER_WRITE_STRING(str,len)    XMLHash_writer_write(writer, str, len)
#define BUFFER_WRITE_ESCAPE(str, len)   XMLHash_writer_escape_content(writer, str, len)
#define BUFFER_WRITE_ESCAPE_ATTR(str)   XMLHash_writer_escape_attr(writer, str)
#define BUFFER_WRITE_QUOTED(str)        XMLHash_writer_write_quoted_string(writer, str)

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

#if defined(XMLHASH_HAVE_ICONV) || defined(XMLHASH_HAVE_ICU)
void XMLHash_encoder_destroy(conv_encoder_t *encoder);
conv_encoder_t *XMLHash_encoder_create(char *encoding);
#endif
void XMLHash_writer_buffer_init(conv_buffer_t *buf, int size);
void XMLHash_writer_buffer_resize(conv_buffer_t *buf, int inc);
SV *XMLHash_writer_flush_buffer(conv_writer_t *writer, conv_buffer_t *buf);
SV *XMLHash_writer_flush(conv_writer_t *writer);
void XMLHash_writer_resize_buffer(conv_writer_t *writer, int inc);

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
XMLHash_writer_create(char *encoding, void *output, int size)
{
    conv_writer_t *writer;

    writer = malloc(sizeof(conv_writer_t));
    if (writer == NULL) {
        croak("Memory allocation error");
    }
    memset(writer, 0, sizeof(conv_writer_t));

    XMLHash_writer_buffer_init(&writer->main_buf, size);

    if (strcasecmp(encoding, "UTF-8") != 0) {
#if defined(XMLHASH_HAVE_ICONV) || defined(XMLHASH_HAVE_ICU)
        writer->encoder = XMLHash_encoder_create(encoding);
        if (writer->encoder == NULL) {
            croak("Can't create encoder for '%s'", encoding);
        }

        XMLHash_writer_buffer_init(&writer->enc_buf, size * 4);
#else
        croak("Can't create encoder for '%s'", encoding);
#endif
    }

    if (output != NULL) {
        MAGIC  *mg;
        GV     *gv = (GV *) output;
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

#endif
