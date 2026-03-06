#ifndef ACODE_THEME_H
#define ACODE_THEME_H

#include <windows.h>
#include <stdbool.h>
#include <dwmapi.h>

/* Color palette for dark and light modes */
typedef struct {
    COLORREF background;
    COLORREF surface;
    COLORREF surfaceAlt;
    COLORREF border;
    COLORREF text;
    COLORREF textSecondary;
    COLORREF accent;
    COLORREF accentHover;

    /* Syntax highlighting colors */
    COLORREF synKeyword;
    COLORREF synType;
    COLORREF synString;
    COLORREF synNumber;
    COLORREF synComment;
    COLORREF synFunction;

    /* Terminal colors (ANSI 16) */
    COLORREF termColors[16];
} ThemeColors;

bool theme_system_is_dark(void);
void theme_apply_to_window(HWND hwnd, bool dark);
void theme_enable_mica(HWND hwnd, bool enable);
const ThemeColors *theme_get_colors(bool dark);

HBRUSH theme_create_bg_brush(bool dark);

#endif /* ACODE_THEME_H */
