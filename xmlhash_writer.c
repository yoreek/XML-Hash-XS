#include "xmlhash_common.h"
#include "xmlhash_writer.h"

void
XMLHash_writer_resize_buffer(conv_writer_t *writer, int inc)
{
    (void) XMLHash_writer_flush(writer);

    XMLHash_writer_buffer_resize(&writer->main_buf, inc);
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
    int size, use;

    if (inc <= (buf->end - buf->cur)) {
        return;
    }

    size = buf->end - buf->start;
    use  = buf->cur - buf->start;

    size += inc < size ? size : inc;

    SvCUR_set(buf->scalar, use);
    SvGROW(buf->scalar, size);

    buf->start = SvPVX(buf->scalar);
    buf->cur   = buf->start + use;
    buf->end   = buf->start + size;
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
