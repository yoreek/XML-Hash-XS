#include "xh_config.h"
#include "xh_core.h"

static const char CONTENT_KEY[] = "content";

#define NEW_STRING(s, l)                                                \
    newSVpvn_utf8((const char *) (s), (l), ctx->opts.utf8)

#define SET_STRING(v, s, l)                                             \
    sv_setpvn((v), (const char *) (s), (l));                            \
    if (ctx->opts.utf8) SvUTF8_on(v);

#define CAT_STRING(v, s, l)                                             \
    sv_catpvn((v), (const char *) (s), (l));                            \
    if (ctx->opts.utf8) SvUTF8_on(v);

#define SAVE_VALUE(lv, v , s, l)                                        \
    if ( SvOK(v) ) {                                                    \
        /* get array if value is reference to array */                  \
        if ( SvROK(v) && SvTYPE(SvRV(v)) == SVt_PVAV) {                 \
            av = (AV *) SvRV(v);                                        \
        }                                                               \
        /* create a new array and move value to array */                \
        else {                                                          \
            av = newAV();                                               \
            *(lv) = newRV_noinc((SV *) av);                             \
            av_store(av, 0, v);                                         \
        }                                                               \
        /* add value to array */                                        \
        (lv) = av_store(av, av_len(av) + 1, NEW_STRING((s), (l)));      \
    }                                                                   \
    else {                                                              \
        SET_STRING((v), (s), (l));                                      \
    }                                                                   \

#define OPEN_TAG(s, l)                                                  \
    if (depth == 0 && nodes[1] != NULL) goto INVALID_XML;               \
    val = *lval;                                                        \
    /* if content exists that move to hash with 'content' key */        \
    if ( !SvROK(val) ) {                                                \
        *lval = newRV_noinc((SV *) newHV());                            \
        if (SvOK(val) && SvCUR(val)) {                                  \
            (void) hv_store((HV *) SvRV(*lval), CONTENT_KEY, sizeof(CONTENT_KEY) - 1, val, 0);\
        }                                                               \
        else {                                                          \
            SvREFCNT_dec(val);                                          \
        }                                                               \
        val = *lval;                                                    \
    }                                                                   \
    /* fetch existen or create empty hash entry */                      \
    lval = hv_fetch((HV *) SvRV(val), (const char *) (s), ctx->opts.utf8 ? -(l) : (l), 1);\
    /* save as empty string */                                          \
    val = *lval;                                                        \
    SAVE_VALUE(lval, val, "", 0)                                        \
    if (++depth >= ctx->opts.max_depth) goto MAX_DEPTH_EXCEEDED;        \
    nodes[depth] = lval;                                                \
    (s) = NULL;

#define CLOSE_TAG                                                       \
    if (depth-- == 0) goto INVALID_XML;                                 \
    lval = nodes[depth];

#define NEW_NODE_ATTRIBUTE(k, kl, v, vl)                                \
    xh_log_trace4("new attr name: [%.*s] value: [%.*s]", kl, k, vl, v); \
    /* create hash if not created already */                            \
    if ( !SvROK(*lval) ) {                                              \
        /* destroy empty old scalar (empty string) */                   \
        SvREFCNT_dec(*lval);                                            \
        *lval = newRV_noinc((SV *) newHV());                            \
    }                                                                   \
    /* save key/value */                                                \
    (void) hv_store((HV *) SvRV(*lval), (const char *) (k), ctx->opts.utf8 ? -(kl) : (kl),\
        NEW_STRING(v, vl), 0);                                          \
    (k) = (v) = NULL;

#define NEW_XML_DECL_ATTRIBUTE(k, kl, v, vl)                            \
    xh_log_trace4("new xml decl attr name: [%.*s] value: [%.*s]", kl, k, vl, v);\
    /* save encoding parameter to converter context if param found */   \
    if ((kl) == (sizeof("encoding") - 1) &&                             \
        xh_strncmp((k), XH_CHAR_CAST "encoding", sizeof("encoding") - 1) == 0) {\
        xh_str_range_copy(ctx->encoding, XH_CHAR_CAST (v), vl, XH_PARAM_LEN);\
    }                                                                   \
    (k) = (v) = NULL;

#define NEW_ATTRIBUTE(k, kl, v, vl) NEW_NODE_ATTRIBUTE(k, kl, v, vl)

#define NEW_TEXT(s, l)                                                  \
    if (depth == 0) goto INVALID_XML;                                   \
    val = *lval;                                                        \
    if ( SvROK(val) ) {                                                 \
        /* add content to array*/                                       \
        if (SvTYPE(SvRV(val)) == SVt_PVAV) {                            \
            av = (AV *) SvRV(val);                                      \
            av_store(av, av_len(av) + 1, NEW_STRING(s, l));             \
        }                                                               \
        /* save content to hash with "content" key */                   \
        else {                                                          \
            lval = hv_fetch((HV *) SvRV(val), CONTENT_KEY, sizeof(CONTENT_KEY) - 1, 1);\
            val = *lval;                                                \
            SAVE_VALUE(lval, val, s, l)                                 \
            lval = nodes[depth];                                        \
        }                                                               \
    }                                                                   \
    else if (SvCUR(val)) {                                              \
        /* content already exists, create a new array and move*/        \
        /* old and new content to array */                              \
        av = newAV();                                                   \
        *lval = newRV_noinc((SV *) av);                                 \
        av_store(av, 0, val);                                           \
        av_store(av, av_len(av) + 1, NEW_STRING(s, l));                 \
    }                                                                   \
    else {                                                              \
        /* add content to empty string */                               \
        CAT_STRING(val, s, l)                                           \
    }                                                                   \

#define NEW_COMMENT(s, l) (s) = NULL;

#define NEW_CDATA(s, l) NEW_TEXT(s, l)

#define CHECK_EOF_WITH_CHUNK(loop)                                      \
    if (cur >= eof) {                                                   \
        if (terminate) goto PPCAT(loop, _FINISH);                       \
        ctx->state = PPCAT(loop, _START);                               \
        goto CHUNK_FINISH;                                              \
    }                                                                   \

#define CHECK_EOF_WITHOUT_CHUNK(loop)                                   \
    if (cur >= eof) goto PPCAT(loop, _FINISH);                          \

#define CHECK_EOF(loop) CHECK_EOF_WITH_CHUNK(loop)

#define DO(loop)                                                        \
PPCAT(loop, _START):                                                    \
    CHECK_EOF(loop)                                                     \
    c = *cur++;                                                         \
    xh_log_trace3("'%c'=[0x%X] %s start", c, c, STRINGIZE(loop));       \
    switch (c) { case '\0': goto PPCAT(loop, _FINISH);

#define _DO(loop)                                                       \
PPCAT(loop, _START):                                                    \
    CHECK_EOF_WITHOUT_CHUNK(loop)                                       \
    c = *cur++;                                                         \
    xh_log_trace3("'%c'=[0x%X] %s start", c, c, STRINGIZE(loop));       \
    switch (c) { case '\0': goto PPCAT(loop, _FINISH);

#define END(loop)                                                       \
    }                                                                   \
    xh_log_trace1("           %s end", STRINGIZE(loop));                \
    goto PPCAT(loop, _START);                                           \
PPCAT(loop, _FINISH):

#define EXPECT_ANY(desc)                                                \
    default: xh_log_trace3("'%c'=[0x%X] - %s expected", c, c, desc);

#define EXPECT_CHAR(desc, c1)                                           \
    case c1: xh_log_trace3("'%c'=[0x%X] - %s expected", c, c, desc);

#define EXPECT_BLANK_WO_CR(desc)                                        \
    case ' ': case '\t': case '\n':                                     \
        xh_log_trace3("'%c'=[0x%X] - %s expected", c, c, desc);

#define EXPECT_BLANK(desc)                                              \
    case ' ': case '\t': case '\n': case '\r':                          \
        xh_log_trace3("'%c'=[0x%X] - %s expected", c, c, desc);

#define EXPECT_DIGIT(desc)                                              \
    case '0': case '1': case '2': case '3': case '4':                   \
    case '5': case '6': case '7': case '8': case '9':                   \
        xh_log_trace3("'%c'=[0x%X] - %s expected", c, c, desc);

#define EXPECT_HEX_CHAR_LC(desc)                                        \
    case 'a': case 'b': case 'c': case 'd': case 'e': case 'f':         \
        xh_log_trace3("'%c'=[0x%X] - %s expected", c, c, desc);

#define EXPECT_HEX_CHAR_UC(desc)                                        \
    case 'A': case 'B': case 'C': case 'D': case 'E': case 'F':         \
        xh_log_trace3("'%c'=[0x%X] - %s expected", c, c, desc);

#define SKIP_BLANK                                                      \
    EXPECT_BLANK("skip blank") break;

#define SCAN2(loop, c1, c2)                                             \
    DO(PPCAT(loop, _1)) EXPECT_CHAR(STRINGIZE(c1), c1)                  \
    DO(PPCAT(loop, _2)) EXPECT_CHAR(STRINGIZE(c2), c2)

#define END2(loop, stop)                                                \
    EXPECT_ANY("wrong character") goto stop;                            \
    END(PPCAT(loop, _2))          goto stop;                            \
    EXPECT_ANY("wrong character") goto stop;                            \
    END(PPCAT(loop, _1))

#define SCAN3(loop, c1, c2, c3)                                         \
    DO(PPCAT(loop, _1)) EXPECT_CHAR(STRINGIZE(c1), c1)                  \
    DO(PPCAT(loop, _2)) EXPECT_CHAR(STRINGIZE(c2), c2)                  \
    DO(PPCAT(loop, _3)) EXPECT_CHAR(STRINGIZE(c3), c3)

#define END3(loop, stop)                                                \
    EXPECT_ANY("wrong character") goto stop;                            \
    END(PPCAT(loop, _3))          goto stop;                            \
    EXPECT_ANY("wrong character") goto stop;                            \
    END(PPCAT(loop, _2))          goto stop;                            \
    EXPECT_ANY("wrong character") goto stop;                            \
    END(PPCAT(loop, _1))

#define SCAN5(loop, c1, c2, c3, c4, c5)                                 \
    SCAN3(PPCAT(loop, _1), c1, c2, c3)                                  \
    SCAN2(PPCAT(loop, _2), c4, c5)

#define END5(loop, stop)                                                \
    END2(PPCAT(loop, _2), stop)                                         \
    END3(PPCAT(loop, _1), stop)

#define SCAN6(loop, c1, c2, c3, c4, c5, c6)                             \
    SCAN3(PPCAT(loop, _1), c1, c2, c3)                                  \
    SCAN3(PPCAT(loop, _2), c4, c5, c6)

#define END6(loop, stop)                                                \
    END3(PPCAT(loop, _2), stop)                                         \
    END3(PPCAT(loop, _1), stop)

#define SEARCH_END_TAG                                                  \
    EXPECT_CHAR("end tag", '>')                                         \
        goto PARSE_CONTENT;                                             \
    EXPECT_CHAR("self closing tag", '/')                                \
        CLOSE_TAG                                                       \
        DO(SEARCH_END_TAG)                                              \
            EXPECT_CHAR("end tag", '>')                                 \
                goto PARSE_CONTENT;                                     \
            EXPECT_ANY("wrong character")                               \
                goto INVALID_XML;                                       \
        END(SEARCH_END_TAG)                                             \
        goto INVALID_XML;

#define SEARCH_NODE_ATTRIBUTE_VALUE(loop, top_loop, quot)               \
    EXPECT_CHAR("start attr value", quot)                               \
        content = cur;                                                  \
        need_normalize = 0;                                             \
        DO(PPCAT(loop, _END_ATTR_VALUE))                                \
            EXPECT_CHAR("attr value end", quot)                         \
                if (need_normalize) {                                   \
                    NORMALIZE_TEXT(loop, content, cur - content - 1)    \
                    NEW_ATTRIBUTE(node, end - node, enc, enc_len)       \
                }                                                       \
                else {                                                  \
                    NEW_ATTRIBUTE(node, end - node, content, cur - content - 1)\
                }                                                       \
                goto top_loop;                                          \
            EXPECT_CHAR("CR", '\r')                                     \
                need_normalize |= XH_X2H_NORMALIZE_LINE_FEED;           \
                break;                                                  \
            EXPECT_CHAR("reference", '&')                               \
                need_normalize |= XH_X2H_NORMALIZE_REF;                 \
                break;                                                  \
        END(PPCAT(loop, _END_ATTR_VALUE))                               \
        goto INVALID_XML;

#define SEARCH_XML_DECL_ATTRIBUTE_VALUE(loop, top_loop, quot)           \
    EXPECT_CHAR("start attr value", quot)                               \
        content = cur;                                                  \
        DO(PPCAT(loop, _END_ATTR_VALUE))                                \
            EXPECT_CHAR("attr value end", quot)                         \
                NEW_ATTRIBUTE(node, end - node, content, cur - content - 1)\
                goto top_loop;                                          \
        END(PPCAT(loop, _END_ATTR_VALUE))                               \
        goto INVALID_XML;

#define SEARCH_ATTRIBUTE_VALUE(loop, top_loop, quot) SEARCH_NODE_ATTRIBUTE_VALUE(loop, top_loop, quot)

#define SEARCH_ATTRIBUTES(loop, search_end_tag)                         \
PPCAT(loop, _SEARCH_ATTRIBUTES_LOOP):                                   \
    DO(PPCAT(loop, _SEARCH_ATTR))                                       \
        search_end_tag                                                  \
                                                                        \
        SKIP_BLANK                                                      \
                                                                        \
        EXPECT_ANY("start attr name")                                   \
            node = cur - 1;                                             \
                                                                        \
            DO(PPCAT(loop, _PARSE_ATTR_NAME))                           \
                EXPECT_BLANK("end attr name")                           \
                    end = cur - 1;                                      \
                    xh_log_trace2("attr name: [%.*s]", end - node, node);\
                                                                        \
                    DO(PPCAT(loop, _ATTR_SKIP_BLANK))                   \
                        EXPECT_CHAR("search attr value", '=')           \
                            goto PPCAT(loop, _SEARCH_ATTRIBUTE_VALUE);  \
                        SKIP_BLANK                                      \
                        EXPECT_ANY("wrong character")                   \
                            goto INVALID_XML;                           \
                    END(PPCAT(loop, _ATTR_SKIP_BLANK))                  \
                    goto INVALID_XML;                                   \
                EXPECT_CHAR("end attr name", '=')                       \
                    end = cur - 1;                                      \
                    xh_log_trace2("attr name: [%.*s]", end - node, node);\
                                                                        \
PPCAT(loop, _SEARCH_ATTRIBUTE_VALUE):                                   \
                    DO(PPCAT(loop, _PARSE_ATTR_VALUE))                  \
                        SEARCH_ATTRIBUTE_VALUE(PPCAT(loop, _1), PPCAT(loop, _SEARCH_ATTRIBUTES_LOOP), '"')\
                        SEARCH_ATTRIBUTE_VALUE(PPCAT(loop, _2), PPCAT(loop, _SEARCH_ATTRIBUTES_LOOP), '\'')\
                        SKIP_BLANK                                      \
                        EXPECT_ANY("wrong character")                   \
                            goto INVALID_XML;                           \
                    END(PPCAT(loop, _PARSE_ATTR_VALUE))                 \
                    goto INVALID_XML;                                   \
            END(PPCAT(loop, _PARSE_ATTR_NAME))                          \
            goto INVALID_XML;                                           \
    END(PPCAT(loop, _SEARCH_ATTR))                                      \
    goto INVALID_XML;

#define PARSE_XML_DECLARATION                                           \
    SCAN3(XML_DECL, 'x', 'm', 'l')                                      \
        DO(XML_DECL_ATTR)                                               \
            EXPECT_BLANK("blank")                                       \
                SEARCH_ATTRIBUTES(XML_DECL_ATTR, SEARCH_END_XML_DECLARATION)\
                goto INVALID_XML;                                       \
            EXPECT_ANY("wrong character")                               \
                goto INVALID_XML;                                       \
        END(XML_DECL_ATTR)                                              \
        goto INVALID_XML;                                               \
    END3(XML_DECL, INVALID_XML)                                         \
    goto INVALID_XML;

#define SEARCH_END_XML_DECLARATION                                      \
    EXPECT_CHAR("end tag", '?')                                         \
        DO(XML_DECL_SEARCH_END_TAG2)                                    \
            EXPECT_CHAR("end tag", '>')                                 \
                goto XML_DECL_FOUND;                                    \
            EXPECT_ANY("wrong character")                               \
                goto INVALID_XML;                                       \
        END(XML_DECL_SEARCH_END_TAG2)                                   \
        goto INVALID_XML;

#define PARSE_COMMENT                                                   \
    DO(COMMENT1)                                                        \
        EXPECT_CHAR("-", '-')                                           \
            content = NULL;                                             \
            DO(END_COMMENT1)                                            \
                SKIP_BLANK                                              \
                EXPECT_CHAR("1st -", '-')                               \
                    if (content == NULL) content = end = cur - 1;       \
                    DO(END_COMMENT2)                                    \
                        EXPECT_CHAR("2nd -", '-')                       \
                            DO(END_COMMENT3)                            \
                                EXPECT_CHAR(">", '>')                   \
                                    NEW_COMMENT(content, end - content) \
                                    goto PARSE_CONTENT;                 \
                                EXPECT_CHAR("2nd -", '-')               \
                                    end = cur - 2;                      \
                                    goto END_COMMENT3_START;            \
                                EXPECT_ANY("any character")             \
                                    end = cur - 1;                      \
                                    goto END_COMMENT1_START;            \
                            END(END_COMMENT3)                           \
                        EXPECT_BLANK("skip blank")                      \
                            end = cur - 1;                              \
                            goto END_COMMENT1_START;                    \
                        EXPECT_ANY("any character")                     \
                            end = cur;                                  \
                            goto END_COMMENT1_START;                    \
                    END(END_COMMENT2)                                   \
                EXPECT_ANY("any char")                                  \
                    if (content == NULL) content = cur - 1;             \
                    end = cur;                                          \
            END(END_COMMENT1)                                           \
            goto INVALID_XML;                                           \
                                                                        \
        EXPECT_ANY("wrong character")                                   \
            goto INVALID_XML;                                           \
                                                                        \
    END(COMMENT1)                                                       \
    goto INVALID_XML;

#define PARSE_CDATA                                                     \
    SCAN6(CDATA, 'C', 'D', 'A', 'T', 'A', '[')                          \
        content = NULL;                                                 \
        DO(END_CDATA1)                                                  \
            SKIP_BLANK                                                  \
            EXPECT_CHAR("1st ]", ']')                                   \
                if (content == NULL) content = end = cur - 1;           \
                DO(END_CDATA2)                                          \
                    EXPECT_CHAR("2nd ]", ']')                           \
                        DO(END_CDATA3)                                  \
                            EXPECT_CHAR(">", '>')                       \
                                NEW_CDATA(content, end - content)       \
                                goto PARSE_CONTENT;                     \
                            EXPECT_CHAR("2nd ]", ']')                   \
                                end = cur - 2;                          \
                                goto END_CDATA3_START;                  \
                            EXPECT_ANY("any character")                 \
                                end = cur - 1;                          \
                                goto END_CDATA1_START;                  \
                        END(END_CDATA3)                                 \
                    EXPECT_BLANK("skip blank")                          \
                        end = cur - 1;                                  \
                        goto END_CDATA1_START;                          \
                    EXPECT_ANY("any character")                         \
                        end = cur;                                      \
                        goto END_CDATA1_START;                          \
                END(END_CDATA2)                                         \
            EXPECT_ANY("any char")                                      \
                if (content == NULL) content = cur - 1;                 \
                end = cur;                                              \
        END(END_CDATA1)                                                 \
        goto INVALID_XML;                                               \
    END6(CDATA, INVALID_XML)

#define NORMALIZE_REFERENCE(loop)                                       \
    _DO(PPCAT(loop, _REFERENCE))                                        \
        EXPECT_CHAR("char reference", '#')                              \
            _DO(PPCAT(loop, _CHAR_REFERENCE))                           \
                EXPECT_CHAR("hex", 'x')                                 \
                    code = 0;                                           \
                    _DO(PPCAT(loop, _HEX_CHAR_REFERENCE_LOOP))          \
                        EXPECT_DIGIT("hex digit")                       \
                            code = code * 16 + (c - '0');               \
                            break;                                      \
                        EXPECT_HEX_CHAR_LC("hex a-f")                   \
                            code = code * 16 + (c - 'a') + 10;          \
                            break;                                      \
                        EXPECT_HEX_CHAR_UC("hex A-F")                   \
                            code = code * 16 + (c - 'A') + 10;          \
                            break;                                      \
                        EXPECT_CHAR("reference end", ';')               \
                            goto PPCAT(loop, _REFEFENCE_VALUE);         \
                    END(PPCAT(loop, _HEX_CHAR_REFERENCE_LOOP))          \
                    goto INVALID_REF;                                   \
                EXPECT_DIGIT("digit")                                   \
                    code = (c - '0');                                   \
                    _DO(PPCAT(loop, _CHAR_REFERENCE_LOOP))              \
                        EXPECT_DIGIT("digit")                           \
                            code = code * 10 + (c - '0');               \
                            break;                                      \
                        EXPECT_CHAR("reference end", ';')               \
                            goto PPCAT(loop, _REFEFENCE_VALUE);         \
                    END(PPCAT(loop, _CHAR_REFERENCE_LOOP))              \
                    goto INVALID_REF;                                   \
                EXPECT_ANY("any char")                                  \
                    goto INVALID_REF;                                   \
            END(PPCAT(loop, _CHAR_REFERENCE))                           \
            goto INVALID_REF;                                           \
        EXPECT_CHAR("amp or apos", 'a')                                 \
            if (xh_str_equal3(cur, 'm', 'p', ';')) {                    \
                code = '&';                                             \
                cur += 3;                                               \
                goto PPCAT(loop, _REFEFENCE_VALUE);                     \
            }                                                           \
            if (xh_str_equal4(cur, 'p', 'o', 's', ';')) {               \
                code = '\'';                                            \
                cur += 4;                                               \
                goto PPCAT(loop, _REFEFENCE_VALUE);                     \
            }                                                           \
            goto INVALID_REF;                                           \
        EXPECT_CHAR("lt", 'l')                                          \
            if (xh_str_equal2(cur, 't', ';')) {                         \
                code = '<';                                             \
                cur += 2;                                               \
                goto PPCAT(loop, _REFEFENCE_VALUE);                     \
            }                                                           \
            goto INVALID_REF;                                           \
        EXPECT_CHAR("gt", 'g')                                          \
            if (xh_str_equal2(cur, 't', ';')) {                         \
                code = '>';                                             \
                cur += 2;                                               \
                goto PPCAT(loop, _REFEFENCE_VALUE);                     \
            }                                                           \
            goto INVALID_REF;                                           \
        EXPECT_CHAR("quot", 'q')                                        \
            if (xh_str_equal4(cur, 'u', 'o', 't', ';')) {               \
                code = '"';                                             \
                cur += 4;                                               \
                goto PPCAT(loop, _REFEFENCE_VALUE);                     \
            }                                                           \
            goto INVALID_REF;                                           \
        EXPECT_ANY("any char")                                          \
            goto INVALID_REF;                                           \
    END(PPCAT(loop, _REFERENCE))                                        \
    goto INVALID_REF;                                                   \
PPCAT(loop, _REFEFENCE_VALUE):                                          \
    xh_log_trace1("parse reference value: %lu", code);                  \
    if (code == 0 || code > 0x10FFFF) goto INVALID_REF;                 \
    if (code >= 0x80) {                                                 \
        if (code < 0x800) {                                             \
            *enc_cur++ = (code >>  6) | 0xC0;  bits =  0;               \
        }                                                               \
        else if (code < 0x10000) {                                      \
            *enc_cur++ = (code >> 12) | 0xE0;  bits =  6;               \
        }                                                               \
        else if (code < 0x110000) {                                     \
            *enc_cur++ = (code >> 18) | 0xF0;  bits =  12;              \
        }                                                               \
        else {                                                          \
            goto INVALID_REF;                                           \
        }                                                               \
        for (; bits >= 0; bits-= 6) {                                   \
            *enc_cur++ = ((code >> bits) & 0x3F) | 0x80;                \
        }                                                               \
    }                                                                   \
    else {                                                              \
        *enc_cur++ = (xh_char_t) code;                                  \
    }

#define NORMALIZE_LINE_FEED(loop)                                       \
    _DO(PPCAT(loop, _NORMALIZE_LINE_FEED))                              \
        EXPECT_CHAR("LF", '\n')                                         \
            goto PPCAT(loop, _NORMALIZE_LINE_FEED_END);                 \
        EXPECT_ANY("any char")                                          \
            cur--;                                                      \
            goto PPCAT(loop, _NORMALIZE_LINE_FEED_END);                 \
    END(PPCAT(loop, _NORMALIZE_LINE_FEED))                              \
PPCAT(loop, _NORMALIZE_LINE_FEED_END):                                  \
    *enc_cur++ = '\n';

#define NORMALIZE_TEXT(loop, s, l)                                      \
    enc_len = l;                                                        \
    if (enc_len) {                                                      \
        old_cur = cur;                                                  \
        old_eof = eof;                                                  \
        cur     = s;                                                    \
        eof     = cur + enc_len;                                        \
        if (ctx->tmp != NULL && enc_len > ctx->tmp_size) free(ctx->tmp);\
        if (ctx->tmp == NULL) {                                         \
            xh_log_trace1("malloc() %lu", enc_len);                     \
            if ((ctx->tmp = malloc(enc_len)) == NULL) goto MALLOC;      \
            ctx->tmp_size = enc_len;                                    \
        }                                                               \
        enc = enc_cur = ctx->tmp;                                       \
        memcpy(enc, cur, enc_len);                                      \
        _DO(PPCAT(loop, _NORMALIZE_TEXT))                               \
            EXPECT_CHAR("reference", '&')                               \
                NORMALIZE_REFERENCE(loop)                               \
                break;                                                  \
            EXPECT_CHAR("CR", '\r')                                     \
                NORMALIZE_LINE_FEED(loop)                               \
                break;                                                  \
            EXPECT_ANY("any char")                                      \
                *enc_cur++ = c;                                         \
        END(PPCAT(loop, _NORMALIZE_TEXT))                               \
        enc_len = enc_cur - enc;                                        \
        cur = old_cur;                                                  \
        eof = old_eof;                                                  \
    }                                                                   \
    else {                                                              \
        enc = s;                                                        \
    }

static void
xh_x2h_parse_chunk(xh_x2h_ctx_t *ctx, xh_char_t **buf, size_t *bytesleft, xh_bool_t terminate)
{
    xh_char_t         c, *cur, *node, *end, *content, *eof, *enc, *enc_cur, *old_cur, *old_eof;
    unsigned int   depth, code, need_normalize;
    int            bits;
    SV          ***nodes, **lval, *val;
    AV            *av;
    size_t         enc_len;

    cur            = *buf;
    eof            = cur + *bytesleft;
    nodes          = ctx->nodes;
    depth          = ctx->depth;
    need_normalize = ctx->need_normalize;
    node           = ctx->node;
    end            = ctx->end;
    content        = ctx->content;
    code           = ctx->code;
    lval           = ctx->lval;
    enc            = enc_cur = old_eof = old_cur = NULL;
    c              = '\0';

#define XH_X2H_PROCESS_STATE(st) case st: goto st;
    switch (ctx->state) {
        case PARSER_ST_NONE: break;
        XH_X2H_PARSER_STATE_LIST
        case XML_DECL_FOUND: break;
        case PARSER_ST_DONE: goto DONE;
    }
#undef XH_X2H_PROCESS_STATE

PARSE_CONTENT:
    content = NULL;
    need_normalize = 0;
    DO(CONTENT)
        EXPECT_CHAR("new element", '<')
            if (content != NULL) {
                if (need_normalize) {
                    NORMALIZE_TEXT(TEXT1, content, end - content)
                    NEW_TEXT(enc, enc_len)
                }
                else {
                    NEW_TEXT(content, end - content)
                }
                content = NULL;
            }
            DO(PARSE_ELEMENT)
                EXPECT_CHAR("xml declaration", '?')
                    if (depth != 0) goto INVALID_XML;
#undef  NEW_ATTRIBUTE
#define NEW_ATTRIBUTE(k, kl, v, vl) NEW_XML_DECL_ATTRIBUTE(k, kl, v, vl)
#undef  SEARCH_ATTRIBUTE_VALUE
#define SEARCH_ATTRIBUTE_VALUE(loop, top_loop, quot) SEARCH_XML_DECL_ATTRIBUTE_VALUE(loop, top_loop, quot)
                    PARSE_XML_DECLARATION
#undef  NEW_ATTRIBUTE
#define NEW_ATTRIBUTE(k, kl, v, vl) NEW_NODE_ATTRIBUTE(k, kl, v, vl)
#undef  SEARCH_ATTRIBUTE_VALUE
#define SEARCH_ATTRIBUTE_VALUE(loop, top_loop, quot) SEARCH_NODE_ATTRIBUTE_VALUE(loop, top_loop, quot)
                EXPECT_CHAR("comment", '!')
                    DO(XML_COMMENT_NODE_OR_CDATA)
                        EXPECT_CHAR("comment", '-')
                            PARSE_COMMENT
                        EXPECT_CHAR("cdata", '[')
                            PARSE_CDATA
                        EXPECT_ANY("wrong character")
                            goto INVALID_XML;
                    END(XML_COMMENT_NODE_OR_CDATA)
                    goto INVALID_XML;
                EXPECT_CHAR("closing tag", '/')
                    //node = cur;
                    DO(PARSE_CLOSING_TAG)
                        EXPECT_CHAR("end tag name", '>')
                            CLOSE_TAG
                            goto PARSE_CONTENT;
                        EXPECT_BLANK("end tag name")
                            DO(SEARCH_CLOSING_END_TAG)
                                EXPECT_CHAR("end tag", '>')
                                    CLOSE_TAG
                                    goto PARSE_CONTENT;
                                SKIP_BLANK
                                EXPECT_ANY("wrong character")
                                    goto INVALID_XML;
                            END(SEARCH_CLOSING_END_TAG)
                            goto INVALID_XML;
                    END(PARSE_CLOSING_TAG)
                    goto INVALID_XML;
                EXPECT_ANY("opening tag")
                    node = cur - 1;
                    DO(PARSE_OPENING_TAG)
                        EXPECT_CHAR("end tag", '>')
                            OPEN_TAG(node, cur - node - 1)
                            goto PARSE_CONTENT;
                        EXPECT_CHAR("self closing tag", '/')
                            OPEN_TAG(node, cur - node - 1)
                            CLOSE_TAG

                            DO(SEARCH_OPENING_END_TAG)
                                EXPECT_CHAR("end tag", '>')
                                    goto PARSE_CONTENT;
                                EXPECT_ANY("wrong character")
                                    goto INVALID_XML;
                            END(SEARCH_OPENING_END_TAG)
                            goto INVALID_XML;
                        EXPECT_BLANK("end tag name")
                            OPEN_TAG(node, cur - node - 1)

                            SEARCH_ATTRIBUTES(NODE, SEARCH_END_TAG)

                            goto PARSE_CONTENT;
                    END(PARSE_OPENING_TAG);
                    goto INVALID_XML;
            END(PARSE_ELEMENT)

        EXPECT_CHAR("wrong symbol", '>')
            goto INVALID_XML;
        EXPECT_BLANK_WO_CR("blank")
            break;
        EXPECT_CHAR("reference", '&')
            need_normalize |= XH_X2H_NORMALIZE_REF;
        EXPECT_CHAR("CR", '\r')
            if (content != NULL) {
                need_normalize |= XH_X2H_NORMALIZE_LINE_FEED;
            }
            break;
        EXPECT_ANY("any char")
            if (content == NULL) content = cur - 1;
            end = cur;
    END(CONTENT)

    if (content != NULL) {
        if (need_normalize) {
            NORMALIZE_TEXT(TEXT2, content, end - content)
            NEW_TEXT(enc, enc_len)
        }
        else {
            NEW_TEXT(content, end - content)
        }
        content = NULL;
    }

    if (depth != 0 || nodes[1] == NULL) goto INVALID_XML;

    ctx->state          = PARSER_ST_DONE;
    *bytesleft          = eof - cur;
    *buf                = cur;
    return;

XML_DECL_FOUND:
    ctx->state          = XML_DECL_FOUND;
CHUNK_FINISH:
    ctx->content        = content;
    ctx->node           = node;
    ctx->end            = end;
    ctx->depth          = depth;
    ctx->need_normalize = need_normalize;
    ctx->code           = code;
    ctx->lval           = lval;
    *bytesleft          = eof - cur;
    *buf                = cur;
    return;

MAX_DEPTH_EXCEEDED:
    croak("Maximum depth exceeded");
INVALID_XML:
    croak("Invalid XML");
INVALID_REF:
    croak("Invalid reference");
MALLOC:
    croak("Memory allocation error");
DONE:
    croak("Parsing is done");
}

static void
xh_x2h_parse(xh_x2h_ctx_t *ctx, xh_reader_t *reader)
{
    xh_char_t  *buf, *preserve;
    size_t     len, off;
    xh_bool_t  eof;

    do {
        preserve = ctx->node != NULL ? ctx->node : ctx->content;

        len = reader->read(reader, &buf, preserve, &off);
        eof = (len == 0);
        if (off) {
            if (ctx->node    != NULL) ctx->node    -= off;
            if (ctx->content != NULL) ctx->content -= off;
            if (ctx->end     != NULL) ctx->end     -= off;
        }

        xh_log_trace2("read buf: %.*s", len, buf);

        do {
            xh_log_trace2("parse buf: %.*s", len, buf);

            xh_x2h_parse_chunk(ctx, &buf, &len, eof);

            if (ctx->state == XML_DECL_FOUND && ctx->opts.encoding[0] == '\0' && ctx->encoding[0] != '\0') {
                reader->switch_encoding(reader, ctx->encoding, &buf, &len);
            }
        } while (len > 0);
    } while (!eof);

    if (ctx->state != PARSER_ST_DONE)
        croak("Invalid XML");
}

SV *
xh_x2h(xh_x2h_ctx_t *ctx, SV *input)
{
    HV *hv = newHV();
    SV *result;

    dXCPT;
    XCPT_TRY_START
    {
        result = ctx->hash = newRV_noinc( (SV *) hv );
        ctx->nodes[0] = ctx->lval = &ctx->hash;

        xh_reader_init(&ctx->reader, input, ctx->opts.encoding, ctx->opts.buf_size);

        xh_x2h_parse(ctx, &ctx->reader);
    } XCPT_TRY_END

    XCPT_CATCH
    {
        xh_reader_destroy(&ctx->reader);
        XCPT_RETHROW;
    }

    xh_reader_destroy(&ctx->reader);

    if (!ctx->opts.keep_root) {
        hv_iterinit(hv);
        result = hv_iterval(hv, hv_iternext(hv));
        SvREFCNT_inc(result);
        SvREFCNT_dec(ctx->hash);
    }

    return result;
}
