#include "main_window.h"
#include "split_view.h"
#include "tab_bar.h"
#include "status_bar.h"
#include "../app.h"
#include "../utils/theme.h"
#include "../terminal/terminal_mgr.h"
#include "../explorer/file_tree.h"
#include "../editor/editor_tabs.h"
#include <commctrl.h>
#include <windowsx.h>

#pragma comment(lib, "comctl32.lib")

static HWND s_hwndSidebar;
static HWND s_hwndEditor;
static HWND s_hwndTerminal;
static HWND s_hwndStatusBar;
static HWND s_hwndSplitterL;
static HWND s_hwndSplitterR;

/* Splitter dragging state */
static bool s_draggingLeft = false;
static bool s_draggingRight = false;
static int  s_dragStartX;
static float s_dragStartRatio;

static void create_child_windows(HWND hwnd) {
    HINSTANCE hInst = g_app.hInstance;

    s_hwndSidebar  = file_tree_create(hwnd, hInst);
    s_hwndEditor   = editor_tabs_create(hwnd, hInst);
    s_hwndTerminal = terminal_mgr_create(hwnd, hInst);
    s_hwndStatusBar = status_bar_create(hwnd, hInst);

    /* Splitter handles (thin invisible windows for drag detection) */
    s_hwndSplitterL = CreateWindowExW(0, L"STATIC", NULL,
        WS_CHILD | WS_VISIBLE | SS_NOTIFY,
        0, 0, 4, 100, hwnd, (HMENU)IDC_SPLITTER_L, hInst, NULL);

    s_hwndSplitterR = CreateWindowExW(0, L"STATIC", NULL,
        WS_CHILD | WS_VISIBLE | SS_NOTIFY,
        0, 0, 4, 100, hwnd, (HMENU)IDC_SPLITTER_R, hInst, NULL);
}

void main_window_layout(HWND hwnd) {
    RECT rc;
    GetClientRect(hwnd, &rc);

    int totalW = rc.right - rc.left;
    int totalH = rc.bottom - rc.top;
    int statusH = 28;
    int contentH = totalH - statusH;

    if (contentH < 1) contentH = 1;
    if (totalW < 1) totalW = 1;

    int splitterW = 4;
    int sidebarW = 0, terminalW = 0;
    int editorX, editorW;

    /* Sidebar */
    if (g_app.sidebarVisible) {
        sidebarW = (int)(totalW * g_app.sidebarRatio);
        if (sidebarW < 140) sidebarW = 140;
        if (sidebarW > totalW / 2) sidebarW = totalW / 2;
    }

    /* Terminal */
    if (g_app.terminalVisible) {
        terminalW = (int)(totalW * (1.0f - g_app.terminalRatio));
        if (terminalW < 200) terminalW = 200;
        if (terminalW > totalW / 2) terminalW = totalW / 2;
    }

    /* Editor gets remaining space */
    editorX = sidebarW + (sidebarW > 0 ? splitterW : 0);
    int rightEdge = totalW - terminalW - (terminalW > 0 ? splitterW : 0);
    editorW = rightEdge - editorX;
    if (editorW < 100) editorW = 100;

    /* Position sidebar */
    if (s_hwndSidebar) {
        ShowWindow(s_hwndSidebar, g_app.sidebarVisible ? SW_SHOW : SW_HIDE);
        if (g_app.sidebarVisible) {
            MoveWindow(s_hwndSidebar, 0, 0, sidebarW, contentH, TRUE);
        }
    }

    /* Position left splitter */
    if (s_hwndSplitterL) {
        ShowWindow(s_hwndSplitterL, g_app.sidebarVisible ? SW_SHOW : SW_HIDE);
        if (g_app.sidebarVisible) {
            MoveWindow(s_hwndSplitterL, sidebarW, 0, splitterW, contentH, TRUE);
        }
    }

    /* Position editor */
    if (s_hwndEditor) {
        MoveWindow(s_hwndEditor, editorX, 0, editorW, contentH, TRUE);
    }

    /* Position right splitter */
    if (s_hwndSplitterR) {
        ShowWindow(s_hwndSplitterR, g_app.terminalVisible ? SW_SHOW : SW_HIDE);
        if (g_app.terminalVisible) {
            MoveWindow(s_hwndSplitterR, rightEdge, 0, splitterW, contentH, TRUE);
        }
    }

    /* Position terminal */
    if (s_hwndTerminal) {
        ShowWindow(s_hwndTerminal, g_app.terminalVisible ? SW_SHOW : SW_HIDE);
        if (g_app.terminalVisible) {
            int termX = rightEdge + splitterW;
            MoveWindow(s_hwndTerminal, termX, 0, totalW - termX, contentH, TRUE);
        }
    }

    /* Status bar at bottom */
    if (s_hwndStatusBar) {
        MoveWindow(s_hwndStatusBar, 0, contentH, totalW, statusH, TRUE);
    }
}

static void on_paint(HWND hwnd) {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(hwnd, &ps);

    const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);
    HBRUSH bg = CreateSolidBrush(colors->background);
    FillRect(hdc, &ps.rcPaint, bg);
    DeleteObject(bg);

    /* Draw splitter lines */
    HPEN pen = CreatePen(PS_SOLID, 1, colors->border);
    HPEN oldPen = SelectObject(hdc, pen);

    if (s_hwndSplitterL && g_app.sidebarVisible) {
        RECT r;
        GetWindowRect(s_hwndSplitterL, &r);
        MapWindowPoints(HWND_DESKTOP, hwnd, (POINT *)&r, 2);
        MoveToEx(hdc, r.left + 1, r.top, NULL);
        LineTo(hdc, r.left + 1, r.bottom);
    }

    if (s_hwndSplitterR && g_app.terminalVisible) {
        RECT r;
        GetWindowRect(s_hwndSplitterR, &r);
        MapWindowPoints(HWND_DESKTOP, hwnd, (POINT *)&r, 2);
        MoveToEx(hdc, r.left + 1, r.top, NULL);
        LineTo(hdc, r.left + 1, r.bottom);
    }

    SelectObject(hdc, oldPen);
    DeleteObject(pen);
    EndPaint(hwnd, &ps);
}

static bool handle_splitter_hit(HWND hwnd, int x, int y) {
    RECT rL, rR;

    if (s_hwndSplitterL && g_app.sidebarVisible) {
        GetWindowRect(s_hwndSplitterL, &rL);
        MapWindowPoints(HWND_DESKTOP, hwnd, (POINT *)&rL, 2);
        InflateRect(&rL, 2, 0);
        POINT pt = { x, y };
        if (PtInRect(&rL, pt)) {
            SetCapture(hwnd);
            s_draggingLeft = true;
            s_dragStartX = x;
            s_dragStartRatio = g_app.sidebarRatio;
            SetCursor(LoadCursor(NULL, IDC_SIZEWE));
            return true;
        }
    }

    if (s_hwndSplitterR && g_app.terminalVisible) {
        GetWindowRect(s_hwndSplitterR, &rR);
        MapWindowPoints(HWND_DESKTOP, hwnd, (POINT *)&rR, 2);
        InflateRect(&rR, 2, 0);
        POINT pt = { x, y };
        if (PtInRect(&rR, pt)) {
            SetCapture(hwnd);
            s_draggingRight = true;
            s_dragStartX = x;
            s_dragStartRatio = g_app.terminalRatio;
            SetCursor(LoadCursor(NULL, IDC_SIZEWE));
            return true;
        }
    }

    return false;
}

static void handle_splitter_move(HWND hwnd, int x) {
    RECT rc;
    GetClientRect(hwnd, &rc);
    int totalW = rc.right;
    if (totalW < 1) return;

    if (s_draggingLeft) {
        int dx = x - s_dragStartX;
        float newRatio = s_dragStartRatio + (float)dx / totalW;
        if (newRatio < 0.10f) newRatio = 0.10f;
        if (newRatio > 0.40f) newRatio = 0.40f;
        g_app.sidebarRatio = newRatio;
        main_window_layout(hwnd);
        InvalidateRect(hwnd, NULL, TRUE);
    }

    if (s_draggingRight) {
        int dx = x - s_dragStartX;
        float newRatio = s_dragStartRatio + (float)dx / totalW;
        if (newRatio < 0.30f) newRatio = 0.30f;
        if (newRatio > 0.90f) newRatio = 0.90f;
        g_app.terminalRatio = newRatio;
        main_window_layout(hwnd);
        InvalidateRect(hwnd, NULL, TRUE);
    }
}

static void handle_splitter_end(void) {
    if (s_draggingLeft || s_draggingRight) {
        ReleaseCapture();
        s_draggingLeft = false;
        s_draggingRight = false;
    }
}

static void handle_set_cursor(HWND hwnd, LPARAM lParam) {
    POINT pt;
    GetCursorPos(&pt);
    ScreenToClient(hwnd, &pt);

    RECT rL, rR;
    if (s_hwndSplitterL && g_app.sidebarVisible) {
        GetWindowRect(s_hwndSplitterL, &rL);
        MapWindowPoints(HWND_DESKTOP, hwnd, (POINT *)&rL, 2);
        InflateRect(&rL, 2, 0);
        if (PtInRect(&rL, pt)) {
            SetCursor(LoadCursor(NULL, IDC_SIZEWE));
            return;
        }
    }
    if (s_hwndSplitterR && g_app.terminalVisible) {
        GetWindowRect(s_hwndSplitterR, &rR);
        MapWindowPoints(HWND_DESKTOP, hwnd, (POINT *)&rR, 2);
        InflateRect(&rR, 2, 0);
        if (PtInRect(&rR, pt)) {
            SetCursor(LoadCursor(NULL, IDC_SIZEWE));
            return;
        }
    }
}

HACCEL main_window_create_accel(void) {
    ACCEL accelTable[] = {
        { FCONTROL | FVIRTKEY, 'T', WM_ACODE_TERMINAL_NEW },
        { FCONTROL | FVIRTKEY, 'D', WM_ACODE_SPLIT_V },
        { FCONTROL | FSHIFT | FVIRTKEY, 'D', WM_ACODE_SPLIT_H },
    };
    return CreateAcceleratorTableW(accelTable, _countof(accelTable));
}

static LRESULT CALLBACK main_wnd_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_CREATE:
        create_child_windows(hwnd);
        /* Restore extra terminals from last session */
        for (int i = 1; i < g_app.lastTerminalCount && i < MAX_TERMINALS; i++)
            terminal_mgr_new_tab();
        theme_apply_to_window(hwnd, g_app.isDarkMode);
        theme_enable_mica(hwnd, true);
        return 0;

    case WM_SIZE:
        main_window_layout(hwnd);
        return 0;

    case WM_PAINT:
        on_paint(hwnd);
        return 0;

    case WM_ERASEBKGND:
        return 1;

    case WM_LBUTTONDOWN:
        if (handle_splitter_hit(hwnd, GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam)))
            return 0;
        break;

    case WM_MOUSEMOVE:
        if (s_draggingLeft || s_draggingRight) {
            handle_splitter_move(hwnd, GET_X_LPARAM(lParam));
            return 0;
        }
        break;

    case WM_LBUTTONUP:
        handle_splitter_end();
        return 0;

    case WM_SETCURSOR:
        if (LOWORD(lParam) == HTCLIENT) {
            handle_set_cursor(hwnd, lParam);
        }
        break;

    case WM_GETMINMAXINFO: {
        MINMAXINFO *mmi = (MINMAXINFO *)lParam;
        mmi->ptMinTrackSize.x = ACODE_MIN_WIDTH;
        mmi->ptMinTrackSize.y = ACODE_MIN_HEIGHT;
        return 0;
    }

    case WM_ACODE_THEME_MANUAL:
        /* User manually changed theme in settings */
        theme_apply_to_window(hwnd, g_app.isDarkMode);
        theme_enable_mica(hwnd, true);
        InvalidateRect(hwnd, NULL, TRUE);
        /* Propagate to child windows */
        if (s_hwndSidebar)    InvalidateRect(s_hwndSidebar,    NULL, TRUE);
        if (s_hwndEditor)     InvalidateRect(s_hwndEditor,     NULL, TRUE);
        if (s_hwndTerminal)   InvalidateRect(s_hwndTerminal,   NULL, TRUE);
        if (s_hwndStatusBar)  InvalidateRect(s_hwndStatusBar,  NULL, TRUE);
        return 0;

    case WM_ACODE_FONT_CHANGE:
        terminal_mgr_update_all_fonts();
        return 0;

    case WM_ACODE_EDITOR_FONT:
        editor_tabs_update_all_fonts();
        return 0;

    case WM_SETTINGCHANGE:
        if (lParam && wcscmp((LPCWSTR)lParam, L"ImmersiveColorSet") == 0) {
            bool wasDark = g_app.isDarkMode;
            g_app.isDarkMode = app_is_dark_mode();
            if (wasDark != g_app.isDarkMode) {
                theme_apply_to_window(hwnd, g_app.isDarkMode);
                InvalidateRect(hwnd, NULL, TRUE);
                /* Notify children */
                SendMessage(hwnd, WM_ACODE_THEME_CHANGE, 0, 0);
            }
        }
        break;

    case WM_COMMAND:
        switch (LOWORD(wParam)) {
        case WM_ACODE_TERMINAL_NEW:
            terminal_mgr_new_tab();
            return 0;
        case WM_ACODE_SPLIT_V:
            terminal_mgr_split_vertical();
            return 0;
        case WM_ACODE_SPLIT_H:
            terminal_mgr_split_horizontal();
            return 0;
        }
        break;

    case WM_CLOSE:
        g_app.lastTerminalCount = terminal_mgr_count();
        app_shutdown();
        DestroyWindow(hwnd);
        return 0;

    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

bool main_window_register(HINSTANCE hInstance) {
    WNDCLASSEXW wc = {
        .cbSize = sizeof(WNDCLASSEXW),
        .style = CS_HREDRAW | CS_VREDRAW,
        .lpfnWndProc = main_wnd_proc,
        .hInstance = hInstance,
        .hCursor = LoadCursor(NULL, IDC_ARROW),
        .hbrBackground = NULL,
        .lpszClassName = L"ACodeMainWindow",
        .hIcon = LoadIconW(hInstance, MAKEINTRESOURCEW(101)),
        .hIconSm = LoadIconW(hInstance, MAKEINTRESOURCEW(101)),
    };

    return RegisterClassExW(&wc) != 0;
}

HWND main_window_create(HINSTANCE hInstance) {
    int screenW = GetSystemMetrics(SM_CXSCREEN);
    int screenH = GetSystemMetrics(SM_CYSCREEN);
    int x = (screenW - ACODE_DEFAULT_WIDTH) / 2;
    int y = (screenH - ACODE_DEFAULT_HEIGHT) / 2;

    HWND hwnd = CreateWindowExW(
        WS_EX_APPWINDOW,
        L"ACodeMainWindow",
        ACODE_APP_NAME,
        WS_OVERLAPPEDWINDOW,
        x, y, ACODE_DEFAULT_WIDTH, ACODE_DEFAULT_HEIGHT,
        NULL, NULL, hInstance, NULL
    );

    return hwnd;
}
