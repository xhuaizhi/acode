#ifndef ACODE_MAIN_WINDOW_H
#define ACODE_MAIN_WINDOW_H

#include <windows.h>
#include <stdbool.h>

#define WM_ACODE_RELAYOUT      (WM_USER + 100)
#define WM_ACODE_THEME_CHANGE  (WM_USER + 101)
#define WM_ACODE_TERMINAL_NEW  (WM_USER + 102)
#define WM_ACODE_SPLIT_H       (WM_USER + 103)
#define WM_ACODE_SPLIT_V       (WM_USER + 104)
#define WM_ACODE_THEME_MANUAL  (WM_USER + 105)  /* sent by settings when user changes theme */
#define WM_ACODE_FONT_CHANGE   (WM_USER + 106)  /* wParam = new font size */
#define WM_ACODE_EDITOR_FONT   (WM_USER + 107)  /* wParam = new editor font size */

/* Child window IDs */
#define IDC_SIDEBAR    1001
#define IDC_EDITOR     1002
#define IDC_TERMINAL   1003
#define IDC_STATUSBAR  1004
#define IDC_TABBAR     1005
#define IDC_SPLITTER_L 1010
#define IDC_SPLITTER_R 1011

bool main_window_register(HINSTANCE hInstance);
HWND main_window_create(HINSTANCE hInstance);
void main_window_layout(HWND hwnd);

/* Keyboard accelerators */
HACCEL main_window_create_accel(void);

#endif /* ACODE_MAIN_WINDOW_H */
