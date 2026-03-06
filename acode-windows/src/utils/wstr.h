#ifndef ACODE_WSTR_H
#define ACODE_WSTR_H

#include <windows.h>

/* UTF-16 (wchar_t) <-> UTF-8 conversion */
int wstr_to_utf8(const wchar_t *wstr, char *buf, int bufSize);
int wstr_from_utf8(const char *utf8, wchar_t *buf, int bufChars);

/* Allocating versions (caller must free) */
char *wstr_to_utf8_alloc(const wchar_t *wstr);
wchar_t *wstr_from_utf8_alloc(const char *utf8);

/* String duplication */
wchar_t *wstr_dup(const wchar_t *s);
char *str_dup(const char *s);

/* Safe string formatting */
int wstr_printf(wchar_t *buf, int bufChars, const wchar_t *fmt, ...);

#endif /* ACODE_WSTR_H */
