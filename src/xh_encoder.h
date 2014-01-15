#ifndef _XH_ENCODER_H_
#define _XH_ENCODER_H_

#include "xh_config.h"
#include "xh_core.h"

#ifdef XH_HAVE_ENCODER

#ifdef XH_HAVE_ICONV
#include <iconv.h>
#endif
#ifdef XH_HAVE_ICU
#include <unicode/utypes.h>
#include <unicode/ucnv.h>
#endif

typedef enum {
    ENC_ICONV,
    ENC_ICU
} xh_encoder_type_t;

typedef struct _xh_encoder_t xh_encoder_t;
struct _xh_encoder_t {
    xh_encoder_type_t  type;
#ifdef XH_HAVE_ICONV
    iconv_t            iconv;
#endif
#ifdef XH_HAVE_ICU
    UConverter        *uconv; /* for conversion between an encoding and UTF-16 */
    UConverter        *utf8;  /* for conversion between UTF-8 and UTF-16 */
#endif
};

void xh_encoder_destroy(xh_encoder_t *encoder);
xh_encoder_t *xh_encoder_create(char *encoding);
void xh_encoder_encode(xh_encoder_t *encoder, xh_buffer_t *main_buf, xh_buffer_t *enc_buf);

#endif /* XH_HAVE_ENCODER */

#endif /* _XH_ENCODER_H_ */
