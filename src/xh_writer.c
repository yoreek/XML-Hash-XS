#include "xh_config.h"
#include "xh_core.h"

void
xh_writer_resize_buffer(xh_writer_t *writer, size_t inc)
{
    (void) xh_writer_flush(writer);

    xh_buffer_resize(&writer->main_buf, inc);
}

SV *
xh_writer_flush_buffer(xh_writer_t *writer, xh_buffer_t *buf)
{
    if (writer->perl_obj != NULL) {
        xh_writer_write_to_perl_obj(buf, writer->perl_obj);
        return &PL_sv_undef;
    }
    else if (writer->perl_io != NULL) {
        xh_writer_write_to_perl_io(buf, writer->perl_io);
        return &PL_sv_undef;
    }

    return xh_writer_write_to_perl_scalar(buf);
}

#ifdef XH_HAVE_ENCODER
void
xh_writer_encode_buffer(xh_writer_t *writer, xh_buffer_t *main_buf, xh_buffer_t *enc_buf)
{
    size_t len;

    /* 1 char -> 4 chars and '\0' */
    len = (main_buf->cur - main_buf->start) * 4 + 1;

    if (len > (enc_buf->end - enc_buf->cur)) {
        xh_writer_flush_buffer(writer, enc_buf);

        xh_buffer_resize(enc_buf, len);
    }

    xh_encoder_encode(writer->encoder, main_buf, enc_buf);
}
#endif

SV *
xh_writer_flush(xh_writer_t *writer)
{
    xh_buffer_t *buf;

#ifdef XH_HAVE_ENCODER
    if (writer->encoder != NULL) {
        xh_writer_encode_buffer(writer, &writer->main_buf, &writer->enc_buf);
        buf = &writer->enc_buf;
    }
    else {
        buf = &writer->main_buf;
    }
#else
    buf = &writer->main_buf;
#endif

    return xh_writer_flush_buffer(writer, buf);
}

void
xh_writer_destroy(xh_writer_t *writer)
{
    if (writer != NULL) {
        if (writer->perl_obj != NULL || writer->perl_io != NULL) {
            SvREFCNT_dec(writer->main_buf.scalar);
#ifdef XH_HAVE_ENCODER
            SvREFCNT_dec(writer->enc_buf.scalar);
        }
        else if (writer->encoder != NULL) {
            SvREFCNT_dec(writer->main_buf.scalar);
#endif
        }

#ifdef XH_HAVE_ENCODER
        xh_encoder_destroy(writer->encoder);
#endif
        free(writer);
    }
}

xh_writer_t *
xh_writer_create(char *encoding, void *output, size_t size, xh_uint_t indent, xh_bool_t trim)
{
    xh_writer_t *writer;

    writer = malloc(sizeof(xh_writer_t));
    if (writer == NULL) {
        croak("Memory allocation error");
    }
    memset(writer, 0, sizeof(xh_writer_t));

    writer->indent = indent;
    writer->trim   = trim;

    xh_buffer_init(&writer->main_buf, size);

    if (strcasecmp(encoding, "UTF-8") != 0) {
#ifdef XH_HAVE_ENCODER
        writer->encoder = xh_encoder_create(encoding);
        if (writer->encoder == NULL) {
            croak("Can't create encoder for '%s'", encoding);
        }

        xh_buffer_init(&writer->enc_buf, size * 4);
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
