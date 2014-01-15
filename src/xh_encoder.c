#include "xh_config.h"
#include "xh_core.h"

#ifdef XH_HAVE_ENCODER

#ifdef XH_HAVE_ICU
static void
xh_encoder_uconv_destroy(UConverter *uconv)
{
    if (uconv != NULL) {
        ucnv_close(uconv);
    }
}

static UConverter *
xh_encoder_uconv_create(char *encoding, xh_bool_t toUnicode)
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

void
xh_encoder_destroy(xh_encoder_t *encoder)
{
    if (encoder != NULL) {
#ifdef XH_HAVE_ICONV
        if (encoder->iconv != NULL) {
            iconv_close(encoder->iconv);
        }
#endif

#ifdef XH_HAVE_ICU
        xh_encoder_uconv_destroy(encoder->uconv);
        xh_encoder_uconv_destroy(encoder->utf8);
#endif
        free(encoder);
    }
}

xh_encoder_t *
xh_encoder_create(char *encoding)
{
    xh_encoder_t *encoder;

    encoder = malloc(sizeof(xh_encoder_t));
    if (encoder == NULL) {
        return NULL;
    }
    memset(encoder, 0, sizeof(xh_encoder_t));

#ifdef XH_HAVE_ICONV
    encoder->iconv = iconv_open(encoding, "UTF-8");
    if (encoder->iconv != (iconv_t) -1) {
        encoder->type = ENC_ICONV;
        return encoder;
    }
    iconv_close(encoder->iconv);
    encoder->iconv = NULL;
#endif

#ifdef XH_HAVE_ICU
    encoder->uconv = xh_encoder_uconv_create(encoding, 1);
    if (encoder->uconv != NULL) {
        encoder->utf8 = xh_encoder_uconv_create("UTF-8", 0);
        if (encoder->utf8 != NULL) {
            encoder->type = ENC_ICU;
            return encoder;
        }
    }
#endif

    xh_encoder_destroy(encoder);

    return NULL;
}

void
xh_encoder_encode(xh_encoder_t *encoder, xh_buffer_t *main_buf, xh_buffer_t *enc_buf)
{
    char   *src  = main_buf->start;

#ifdef XH_HAVE_ICONV
    if (encoder->type == ENC_ICONV) {
        size_t in_left  = main_buf->cur - main_buf->start;
        size_t out_left = enc_buf->end - enc_buf->cur;

        size_t converted = iconv(encoder->iconv, &src, &in_left, &enc_buf->cur, &out_left);
        if (converted == (size_t) -1) {
            croak("Convert error");
        }
        return;
    }
#endif

#ifdef XH_HAVE_ICU
    UErrorCode  err  = U_ZERO_ERROR;
    ucnv_convertEx(encoder->uconv, encoder->utf8, &enc_buf->cur, enc_buf->end,
                   (const char **) &src, main_buf->cur, NULL, NULL, NULL, NULL,
                   FALSE, TRUE, &err);

    if ( U_FAILURE(err) ) {
        croak("Convert error: %d", err);
    }
#endif
}

#endif /* XH_HAVE_ENCODER */
