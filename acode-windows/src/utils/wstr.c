#include "wstr.h"
#include <stdlib.h>
#include <string.h>
#include <stdarg.h>
#include <stdio.h>

int wstr_to_utf8(const wchar_t *wstr, char *buf, int bufSize) {
    if (!wstr || !buf || bufSize <= 0) return 0;
    int len = WideCharToMultiByte(CP_UTF8, 0, wstr, -1, buf, bufSize, NULL, NULL);
    if (len == 0) buf[0] = '\0';
    return len;
}

int wstr_from_utf8(const char *utf8, wchar_t *buf, int bufChars) {
    if (!utf8 || !buf || bufChars <= 0) return 0;
    int len = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, buf, bufChars);
    if (len == 0) buf[0] = L'\0';
    return len;
}

char *wstr_to_utf8_alloc(const wchar_t *wstr) {
    if (!wstr) return NULL;
    int needed = WideCharToMultiByte(CP_UTF8, 0, wstr, -1, NULL, 0, NULL, NULL);
    if (needed <= 0) return NULL;
    char *buf = (char *)malloc(needed);
    if (!buf) return NULL;
    WideCharToMultiByte(CP_UTF8, 0, wstr, -1, buf, needed, NULL, NULL);
    return buf;
}

wchar_t *wstr_from_utf8_alloc(const char *utf8) {
    if (!utf8) return NULL;
    int needed = MultiByteToWideChar(CP_UTF8, 0, utf8, -1, NULL, 0);
    if (needed <= 0) return NULL;
    wchar_t *buf = (wchar_t *)malloc(needed * sizeof(wchar_t));
    if (!buf) return NULL;
    MultiByteToWideChar(CP_UTF8, 0, utf8, -1, buf, needed);
    return buf;
}

wchar_t *wstr_dup(const wchar_t *s) {
    if (!s) return NULL;
    size_t len = wcslen(s) + 1;
    wchar_t *d = (wchar_t *)malloc(len * sizeof(wchar_t));
    if (d) memcpy(d, s, len * sizeof(wchar_t));
    return d;
}

char *str_dup(const char *s) {
    if (!s) return NULL;
    size_t len = strlen(s) + 1;
    char *d = (char *)malloc(len);
    if (d) memcpy(d, s, len);
    return d;
}

int wstr_printf(wchar_t *buf, int bufChars, const wchar_t *fmt, ...) {
    va_list args;
    va_start(args, fmt);
    int result = _vsnwprintf(buf, bufChars, fmt, args);
    va_end(args);
    if (result < 0 || result >= bufChars) {
        buf[bufChars - 1] = L'\0';
    }
    return result;
}
