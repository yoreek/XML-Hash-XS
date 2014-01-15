#include "xh_config.h"
#include "xh_core.h"

void
xh_param_assign_string(char param[], SV *value)
{
    char *str;

    if ( SvOK(value) ) {
        str = (char *) SvPV_nolen(value);
        strncpy(param, str, XH_PARAM_LEN);
    }
    else {
        *param = 0;
    }
}

void
xh_param_assign_int(char *name, xh_int_t *param, SV *value)
{
    if ( !SvOK(value) ) {
        croak("Parameter '%s' is undefined", name);
    }
    *param = SvIV(value);
}

xh_bool_t
xh_param_assign_bool(SV *value)
{
    if ( SvTRUE(value) ) {
        return TRUE;
    }
    return FALSE;
}
