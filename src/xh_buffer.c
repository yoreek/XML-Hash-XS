#include "xh_config.h"
#include "xh_core.h"

void
xh_buffer_init(xh_buffer_t *buf, size_t size)
{
    buf->scalar = newSV(size);
    sv_setpv(buf->scalar, "");

    buf->start = buf->cur = SvPVX(buf->scalar);
    buf->end   = buf->start + size;
}

void
xh_buffer_resize(xh_buffer_t *buf, size_t inc)
{
    size_t size, use;

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
