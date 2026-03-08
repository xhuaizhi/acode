#include "theme.h"
#include <dwmapi.h>

#pragma comment(lib, "dwmapi.lib")

#ifndef DWMWA_USE_IMMERSIVE_DARK_MODE
#define DWMWA_USE_IMMERSIVE_DARK_MODE 20
#endif
#ifndef DWMWA_SYSTEMBACKDROP_TYPE
#define DWMWA_SYSTEMBACKDROP_TYPE 38
#endif

typedef enum {
    DWMSBT_AUTO = 0,
    DWMSBT_NONE = 1,
    DWMSBT_MAINWINDOW = 2,   /* Mica */
    DWMSBT_TRANSIENTWINDOW = 3,
    DWMSBT_TABBEDWINDOW = 4  /* Mica Alt */
} DWM_SYSTEMBACKDROP_TYPE;

static const ThemeColors s_darkTheme = {
    .background     = RGB(30, 30, 30),
    .surface        = RGB(37, 37, 38),
    .surfaceAlt     = RGB(45, 45, 48),
    .border         = RGB(60, 60, 60),
    .text           = RGB(212, 212, 212),
    .textSecondary  = RGB(128, 128, 128),
    .accent         = RGB(0, 120, 212),
    .accentHover    = RGB(28, 145, 232),

    .synKeyword     = RGB(86, 156, 214),    /* #569CD6 钢蓝 */
    .synType        = RGB(78, 201, 176),   /* #4EC9B0 青绿 */
    .synString      = RGB(206, 145, 120),  /* #CE9178 暖棕 */
    .synNumber      = RGB(181, 206, 168),  /* #B5CEA8 浅绿 */
    .synComment     = RGB(106, 153, 85),   /* #6A9955 绿色 */
    .synFunction    = RGB(220, 220, 170),  /* #DCDCAA 淡黄 */

    .termColors = {
        RGB(0, 0, 0),         RGB(205, 49, 49),
        RGB(13, 188, 121),    RGB(229, 229, 16),
        RGB(36, 114, 200),    RGB(188, 63, 188),
        RGB(17, 168, 205),    RGB(204, 204, 204),
        RGB(102, 102, 102),   RGB(241, 76, 76),
        RGB(35, 209, 139),    RGB(245, 245, 67),
        RGB(59, 142, 234),    RGB(214, 112, 214),
        RGB(41, 184, 219),    RGB(242, 242, 242)
    }
};

static const ThemeColors s_lightTheme = {
    .background     = RGB(255, 255, 255),
    .surface        = RGB(243, 243, 243),
    .surfaceAlt     = RGB(233, 233, 233),
    .border         = RGB(206, 206, 206),
    .text           = RGB(30, 30, 30),
    .textSecondary  = RGB(100, 100, 100),
    .accent         = RGB(0, 95, 184),
    .accentHover    = RGB(0, 120, 212),

    .synKeyword     = RGB(0, 0, 255),      /* #0000FF 蓝 */
    .synType        = RGB(38, 127, 153),  /* #267F99 青 */
    .synString      = RGB(163, 21, 21),   /* #A31515 暗红 */
    .synNumber      = RGB(9, 134, 88),    /* #098658 暗青 */
    .synComment     = RGB(0, 128, 0),     /* #008000 绿 */
    .synFunction    = RGB(121, 94, 38),   /* #795E26 棕 */

    .termColors = {
        RGB(0, 0, 0),         RGB(205, 49, 49),
        RGB(0, 170, 0),       RGB(229, 229, 16),
        RGB(0, 0, 170),       RGB(188, 63, 188),
        RGB(0, 170, 170),     RGB(204, 204, 204),
        RGB(102, 102, 102),   RGB(241, 76, 76),
        RGB(35, 209, 139),    RGB(245, 245, 67),
        RGB(59, 142, 234),    RGB(214, 112, 214),
        RGB(41, 184, 219),    RGB(242, 242, 242)
    }
};

bool theme_system_is_dark(void) {
    DWORD value = 0;
    DWORD size = sizeof(value);
    LSTATUS status = RegGetValueW(
        HKEY_CURRENT_USER,
        L"Software\\Microsoft\\Windows\\CurrentVersion\\Themes\\Personalize",
        L"AppsUseLightTheme",
        RRF_RT_DWORD, NULL, &value, &size
    );
    if (status == ERROR_SUCCESS)
        return value == 0;
    return false;
}

void theme_apply_to_window(HWND hwnd, bool dark) {
    BOOL useDark = dark ? TRUE : FALSE;
    DwmSetWindowAttribute(hwnd, DWMWA_USE_IMMERSIVE_DARK_MODE, &useDark, sizeof(useDark));
}

void theme_enable_mica(HWND hwnd, bool enable) {
    DWM_SYSTEMBACKDROP_TYPE backdrop = enable ? DWMSBT_MAINWINDOW : DWMSBT_NONE;
    DwmSetWindowAttribute(hwnd, DWMWA_SYSTEMBACKDROP_TYPE, &backdrop, sizeof(backdrop));

    /* Extend frame into client area for Mica to work */
    if (enable) {
        MARGINS margins = { -1, -1, -1, -1 };
        DwmExtendFrameIntoClientArea(hwnd, &margins);
    }
}

const ThemeColors *theme_get_colors(bool dark) {
    return dark ? &s_darkTheme : &s_lightTheme;
}

HBRUSH theme_create_bg_brush(bool dark) {
    const ThemeColors *colors = theme_get_colors(dark);
    return CreateSolidBrush(colors->background);
}
