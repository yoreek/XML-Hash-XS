#ifndef _XH_PARAM_H_
#define _XH_PARAM_H_

#include "xh_config.h"
#include "xh_core.h"

#define XH_PARAM_LEN 32

#define XH_PARAM_READ_INIT                              \
    SV   *sv;                                           \
    char *str;
#define XH_PARAM_READ_STRING(var, name, def_value)      \
    if ( (sv = get_sv(name, 0)) != NULL ) {             \
        if ( SvOK(sv) ) {                               \
            str = (char *) SvPV_nolen(sv);              \
            strncpy(var, str, XH_PARAM_LEN);            \
        }                                               \
        else {                                          \
            var[0] = '\0';                              \
        }                                               \
    }                                                   \
    else {                                              \
        strncpy(var, def_value, XH_PARAM_LEN);          \
    }
#define XH_PARAM_READ_BOOL(var, name, def_value)        \
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
#define XH_PARAM_READ_INT(var, name, def_value)         \
    if ( (sv = get_sv(name, 0)) != NULL ) {             \
        var = SvIV(sv);                                 \
    }                                                   \
    else {                                              \
        var = def_value;                                \
    }
#define XH_PARAM_READ_REF(var, name, def_value)         \
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

void xh_param_assign_string(char param[], SV *value);
void xh_param_assign_int(char *name, xh_int_t *param, SV *value);
xh_bool_t xh_param_assign_bool(SV *value);

#endif /* _XH_PARAM_H_ */
