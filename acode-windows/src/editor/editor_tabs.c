#include "editor_tabs.h"
#include "editor_view.h"
#include "image_view.h"
#include "../app.h"
#include "../utils/theme.h"
#include "../utils/wstr.h"
#include <commctrl.h>
#include <shlwapi.h>
#include <windowsx.h>
#include <stdio.h>

#define EDITORTABS_CLASS  L"ACodeEditorTabs"
#define TABBAR_CLASS      L"ACodeEditorTabBar"
#define TAB_HEIGHT        26
#define TAB_PAD_H         8
#define TAB_ICON_SIZE     8
#define TAB_CLOSE_SIZE    14
#define TAB_CLOSE_PAD     4
#define TAB_GAP           0
#define MENU_BTN_WIDTH    20

static struct {
    HWND    container;
    HWND    tabBar;
    HWND    editors[MAX_EDITOR_TABS];
    wchar_t paths[MAX_EDITOR_TABS][MAX_PATH];
    bool    isImage[MAX_EDITOR_TABS];   /* true if tab shows image preview */
    int     count;
    int     active;
    int     hoverTab;       /* tab index under mouse, -1 = none */
    int     hoverClose;     /* tab index whose close btn is hovered, -1 = none */
    bool    hoverMenuBtn;   /* menu button hovered */
} s_tabs = { .hoverTab = -1, .hoverClose = -1, .hoverMenuBtn = false };

/* Cached GDI fonts to avoid per-paint allocation */
static HFONT s_etFont      = NULL;  /* main tab label font */
static HFONT s_etCloseFont = NULL;  /* close button (x) font */
static HFONT s_etMenuFont  = NULL;  /* menu button font */

static void ensure_et_fonts(void) {
    if (!s_etFont)
        s_etFont = CreateFontW(11, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    if (!s_etCloseFont)
        s_etCloseFont = CreateFontW(9, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    if (!s_etMenuFont)
        s_etMenuFont = CreateFontW(13, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
}

/* ---- File extension -> icon color (matches Mac EditorTabBar) ---- */
static COLORREF icon_color_for_ext(const wchar_t *ext) {
    if (!ext || !*ext) return RGB(128, 128, 128);
    if (_wcsicmp(ext, L"swift") == 0) return RGB(240, 81, 56);
    if (_wcsicmp(ext, L"js") == 0 || _wcsicmp(ext, L"jsx") == 0) return RGB(247, 223, 30);
    if (_wcsicmp(ext, L"ts") == 0 || _wcsicmp(ext, L"tsx") == 0) return RGB(49, 120, 198);
    if (_wcsicmp(ext, L"py") == 0) return RGB(55, 118, 171);
    if (_wcsicmp(ext, L"rs") == 0) return RGB(222, 165, 132);
    if (_wcsicmp(ext, L"html") == 0) return RGB(227, 79, 38);
    if (_wcsicmp(ext, L"css") == 0) return RGB(21, 114, 182);
    if (_wcsicmp(ext, L"c") == 0 || _wcsicmp(ext, L"h") == 0) return RGB(85, 85, 255);
    if (_wcsicmp(ext, L"go") == 0) return RGB(0, 173, 216);
    if (_wcsicmp(ext, L"java") == 0) return RGB(176, 114, 25);
    if (_wcsicmp(ext, L"json") == 0) return RGB(128, 128, 128);
    return RGB(128, 128, 128);
}

/* ---- Measure a single tab width ---- */
static int measure_tab_width(HDC hdc, int idx) {
    const wchar_t *name = PathFindFileNameW(s_tabs.paths[idx]);
    SIZE sz;
    GetTextExtentPoint32W(hdc, name, (int)wcslen(name), &sz);
    /* icon_dot + gap + text + gap + close_btn + pad */
    return TAB_PAD_H + TAB_ICON_SIZE + 4 + sz.cx + TAB_CLOSE_PAD + TAB_CLOSE_SIZE + TAB_PAD_H;
}

/* ---- Get tab rect (0-indexed from left) ---- */
static RECT get_tab_rect(HDC hdc, int idx) {
    RECT r = {0, 0, 0, TAB_HEIGHT};
    ensure_et_fonts();
    HFONT old = SelectObject(hdc, s_etFont);
    int x = 0;
    for (int i = 0; i <= idx; i++) {
        int w = measure_tab_width(hdc, i);
        if (i == idx) { r.left = x; r.right = x + w; }
        x += w + TAB_GAP;
    }
    SelectObject(hdc, old);
    return r;
}

/* ---- Get close button rect within a tab ---- */
static RECT get_close_rect(RECT tabRect) {
    RECT r;
    r.right = tabRect.right - TAB_PAD_H;
    r.left = r.right - TAB_CLOSE_SIZE;
    r.top = (TAB_HEIGHT - TAB_CLOSE_SIZE) / 2;
    r.bottom = r.top + TAB_CLOSE_SIZE;
    return r;
}

/* ---- Hit test: returns tab index at point, -1 if none ---- */
static int hit_test_tab(POINT pt) {
    if (s_tabs.count == 0) return -1;
    HDC hdc = GetDC(s_tabs.tabBar);
    ensure_et_fonts();
    HFONT old = SelectObject(hdc, s_etFont);
    int x = 0;
    int result = -1;
    for (int i = 0; i < s_tabs.count; i++) {
        int w = measure_tab_width(hdc, i);
        if (pt.x >= x && pt.x < x + w && pt.y >= 0 && pt.y < TAB_HEIGHT) {
            result = i;
            break;
        }
        x += w + TAB_GAP;
    }
    SelectObject(hdc, old);
    ReleaseDC(s_tabs.tabBar, hdc);
    return result;
}

/* ---- Check if point is on close button of given tab ---- */
static bool hit_test_close(POINT pt, int tabIdx) {
    if (tabIdx < 0 || tabIdx >= s_tabs.count) return false;
    HDC hdc = GetDC(s_tabs.tabBar);
    RECT tr = get_tab_rect(hdc, tabIdx);
    ReleaseDC(s_tabs.tabBar, hdc);
    RECT cr = get_close_rect(tr);
    return (pt.x >= cr.left && pt.x <= cr.right && pt.y >= cr.top && pt.y <= cr.bottom);
}

/* ---- Check if point is on menu button ---- */
static bool hit_test_menu_btn(POINT pt) {
    RECT rc;
    GetClientRect(s_tabs.tabBar, &rc);
    return (pt.x >= rc.right - MENU_BTN_WIDTH && pt.y >= 0 && pt.y < TAB_HEIGHT);
}

static void close_tab(int idx);

static void layout_editor_tabs(void) {
    RECT rc;
    GetClientRect(s_tabs.container, &rc);

    int tabH = (s_tabs.count > 0) ? TAB_HEIGHT : 0;
    if (s_tabs.tabBar) {
        ShowWindow(s_tabs.tabBar, s_tabs.count > 0 ? SW_SHOW : SW_HIDE);
        MoveWindow(s_tabs.tabBar, 0, 0, rc.right, tabH, TRUE);
    }

    for (int i = 0; i < s_tabs.count; i++) {
        if (s_tabs.editors[i]) {
            if (i == s_tabs.active) {
                MoveWindow(s_tabs.editors[i], 0, tabH, rc.right, rc.bottom - tabH, TRUE);
                ShowWindow(s_tabs.editors[i], SW_SHOW);
            } else {
                ShowWindow(s_tabs.editors[i], SW_HIDE);
            }
        }
    }
}

static void update_tab_labels(void) {
    /* Custom tab bar just needs a repaint */
    if (s_tabs.tabBar) InvalidateRect(s_tabs.tabBar, NULL, FALSE);
}

static int find_open_tab(const wchar_t *path) {
    for (int i = 0; i < s_tabs.count; i++) {
        if (_wcsicmp(s_tabs.paths[i], path) == 0) return i;
    }
    return -1;
}

/* ---- Custom tab bar painting ---- */
static void paint_tab_bar(HWND hwnd, HDC hdc) {
    const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);
    RECT rc;
    GetClientRect(hwnd, &rc);

    /* Background */
    HBRUSH bg = CreateSolidBrush(colors->surface);
    FillRect(hdc, &rc, bg);
    DeleteObject(bg);

    /* Bottom border */
    HPEN borderPen = CreatePen(PS_SOLID, 1, colors->border);
    HPEN origPen = SelectObject(hdc, borderPen);
    MoveToEx(hdc, 0, rc.bottom - 1, NULL);
    LineTo(hdc, rc.right, rc.bottom - 1);
    SelectObject(hdc, origPen);
    DeleteObject(borderPen);

    SetBkMode(hdc, TRANSPARENT);
    ensure_et_fonts();
    HFONT oldFont = SelectObject(hdc, s_etFont);

    int x = 0;
    for (int i = 0; i < s_tabs.count; i++) {
        int tabW = measure_tab_width(hdc, i);
        RECT tabRect = { x, 0, x + tabW, TAB_HEIGHT - 1 };
        bool isActive = (i == s_tabs.active);
        bool isHover  = (i == s_tabs.hoverTab);

        /* Tab background */
        if (isActive) {
            HBRUSH abg = CreateSolidBrush(colors->background);
            FillRect(hdc, &tabRect, abg);
            DeleteObject(abg);
        } else if (isHover) {
            HBRUSH hbg = CreateSolidBrush(colors->surfaceAlt);
            FillRect(hdc, &tabRect, hbg);
            DeleteObject(hbg);
        }

        /* Right separator */
        HPEN sepPen = CreatePen(PS_SOLID, 1, colors->border);
        HPEN oldSepPen = SelectObject(hdc, sepPen);
        MoveToEx(hdc, tabRect.right, 2, NULL);
        LineTo(hdc, tabRect.right, TAB_HEIGHT - 3);
        SelectObject(hdc, oldSepPen);
        DeleteObject(sepPen);

        /* Icon color dot */
        const wchar_t *ext = PathFindExtensionW(s_tabs.paths[i]);
        if (ext && *ext == L'.') ext++;
        COLORREF iconClr = icon_color_for_ext(ext);
        int dotX = x + TAB_PAD_H;
        int dotY = (TAB_HEIGHT - TAB_ICON_SIZE) / 2;
        HBRUSH dotBrush = CreateSolidBrush(iconClr);
        RECT dotRect = { dotX, dotY, dotX + TAB_ICON_SIZE, dotY + TAB_ICON_SIZE };
        FillRect(hdc, &dotRect, dotBrush);
        DeleteObject(dotBrush);

        /* File name */
        const wchar_t *name = PathFindFileNameW(s_tabs.paths[i]);
        bool isModified = false;
        if (!s_tabs.isImage[i]) {
            EditorView *ev = editor_view_from_hwnd(s_tabs.editors[i]);
            if (ev) isModified = ev->modified;
        }
        wchar_t label[MAX_PATH];
        if (isModified)
            _snwprintf(label, MAX_PATH, L"\u25CF %s", name);
        else
            wcsncpy(label, name, MAX_PATH);

        SetTextColor(hdc, isActive ? colors->text : colors->textSecondary);
        RECT textRect = { dotX + TAB_ICON_SIZE + 4, 0, tabRect.right - TAB_CLOSE_SIZE - TAB_CLOSE_PAD - TAB_PAD_H, TAB_HEIGHT - 1 };
        DrawTextW(hdc, label, -1, &textRect, DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);

        /* Close button (×) — visible on hover or active */
        if (isActive || isHover) {
            RECT cr = get_close_rect(tabRect);
            bool closeHover = (i == s_tabs.hoverClose);

            if (closeHover) {
                HBRUSH closeBg = CreateSolidBrush(colors->surfaceAlt);
                FillRect(hdc, &cr, closeBg);
                DeleteObject(closeBg);
            }

            SelectObject(hdc, s_etCloseFont);
            SetTextColor(hdc, closeHover ? colors->text : colors->textSecondary);
            DrawTextW(hdc, L"\u00D7", -1, &cr, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
            SelectObject(hdc, s_etFont); /* restore main font */
        }

        x += tabW + TAB_GAP;
    }

    /* Menu button (⋮) at far right */
    if (s_tabs.count > 0) {
        RECT menuRect = { rc.right - MENU_BTN_WIDTH, 0, rc.right, TAB_HEIGHT - 1 };
        if (s_tabs.hoverMenuBtn) {
            HBRUSH mbg = CreateSolidBrush(colors->surfaceAlt);
            FillRect(hdc, &menuRect, mbg);
            DeleteObject(mbg);
        }
        SelectObject(hdc, s_etMenuFont);
        SetTextColor(hdc, colors->textSecondary);
        DrawTextW(hdc, L"\u22EE", -1, &menuRect, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
        SelectObject(hdc, s_etFont);
    }

    SelectObject(hdc, oldFont);
}

/* ---- Custom tab bar window proc ---- */
static LRESULT CALLBACK tabbar_wnd_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);
        paint_tab_bar(hwnd, hdc);
        EndPaint(hwnd, &ps);
        return 0;
    }
    case WM_ERASEBKGND:
        return 1;

    case WM_MOUSEMOVE: {
        POINT pt = { GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam) };
        int prevHover = s_tabs.hoverTab;
        int prevClose = s_tabs.hoverClose;
        bool prevMenu = s_tabs.hoverMenuBtn;

        s_tabs.hoverTab = hit_test_tab(pt);
        s_tabs.hoverClose = (s_tabs.hoverTab >= 0 && hit_test_close(pt, s_tabs.hoverTab)) ? s_tabs.hoverTab : -1;
        s_tabs.hoverMenuBtn = hit_test_menu_btn(pt);

        if (s_tabs.hoverTab != prevHover || s_tabs.hoverClose != prevClose || s_tabs.hoverMenuBtn != prevMenu)
            InvalidateRect(hwnd, NULL, FALSE);

        /* Track mouse leave */
        TRACKMOUSEEVENT tme = { sizeof(tme), TME_LEAVE, hwnd, 0 };
        TrackMouseEvent(&tme);
        return 0;
    }

    case WM_MOUSELEAVE:
        s_tabs.hoverTab = -1;
        s_tabs.hoverClose = -1;
        s_tabs.hoverMenuBtn = false;
        InvalidateRect(hwnd, NULL, FALSE);
        return 0;

    case WM_LBUTTONDOWN: {
        POINT pt = { GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam) };

        /* Menu button click */
        if (hit_test_menu_btn(pt) && s_tabs.count > 0) {
            HMENU hMenu = CreatePopupMenu();
            AppendMenuW(hMenu, MF_STRING, 1, L"\u5173\u95ED\u6240\u6709\u6587\u4EF6");
            POINT screenPt = pt;
            ClientToScreen(hwnd, &screenPt);
            int cmd = TrackPopupMenu(hMenu, TPM_RETURNCMD | TPM_NONOTIFY,
                screenPt.x, screenPt.y, 0, hwnd, NULL);
            DestroyMenu(hMenu);
            if (cmd == 1) editor_tabs_close_all();
            return 0;
        }

        int tabIdx = hit_test_tab(pt);
        if (tabIdx >= 0) {
            /* Close button click */
            if (hit_test_close(pt, tabIdx)) {
                close_tab(tabIdx);
                return 0;
            }
            /* Tab select */
            if (tabIdx != s_tabs.active) {
                s_tabs.active = tabIdx;
                layout_editor_tabs();
                InvalidateRect(hwnd, NULL, FALSE);
            }
        }
        return 0;
    }
    }
    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

/* ---- Close a specific tab by index ---- */
static void close_tab(int idx) {
    if (idx < 0 || idx >= s_tabs.count) return;

    DestroyWindow(s_tabs.editors[idx]);
    for (int i = idx; i < s_tabs.count - 1; i++) {
        s_tabs.editors[i] = s_tabs.editors[i + 1];
        wcscpy(s_tabs.paths[i], s_tabs.paths[i + 1]);
        s_tabs.isImage[i] = s_tabs.isImage[i + 1];
    }
    s_tabs.count--;

    if (s_tabs.count == 0) {
        s_tabs.active = 0;
    } else if (idx < s_tabs.active) {
        /* Closed a tab before active: shift active back by 1 */
        s_tabs.active--;
    } else if (idx == s_tabs.active) {
        /* Closed the active tab: clamp to valid range */
        if (s_tabs.active >= s_tabs.count)
            s_tabs.active = s_tabs.count - 1;
    }
    /* idx > s_tabs.active: active stays the same */

    s_tabs.hoverTab = -1;
    s_tabs.hoverClose = -1;

    update_tab_labels();
    layout_editor_tabs();
    if (s_tabs.count == 0)
        InvalidateRect(s_tabs.container, NULL, TRUE);
}

static LRESULT CALLBACK tabs_wnd_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_SIZE:
        layout_editor_tabs();
        return 0;

    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);
        const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);
        HBRUSH bg = CreateSolidBrush(colors->background);
        FillRect(hdc, &ps.rcPaint, bg);
        DeleteObject(bg);

        if (s_tabs.count == 0) {
            SetBkMode(hdc, TRANSPARENT);
            SetTextColor(hdc, colors->textSecondary);
            ensure_et_fonts();
            HFONT oldF = SelectObject(hdc, s_etFont);
            RECT rc;
            GetClientRect(hwnd, &rc);
            DrawTextW(hdc, L"Ctrl+O \u6253\u5F00\u6587\u4EF6\u5939", -1, &rc, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
            SelectObject(hdc, oldF);
        }

        EndPaint(hwnd, &ps);
        return 0;
    }

    case WM_ERASEBKGND:
        return 1;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

HWND editor_tabs_create(HWND parent, HINSTANCE hInstance) {
    WNDCLASSEXW wc = {
        .cbSize = sizeof(WNDCLASSEXW),
        .lpfnWndProc = tabs_wnd_proc,
        .hInstance = hInstance,
        .hbrBackground = NULL,
        .lpszClassName = EDITORTABS_CLASS,
        .hCursor = LoadCursor(NULL, IDC_ARROW),
    };
    RegisterClassExW(&wc);

    /* Register custom tab bar class */
    WNDCLASSEXW tbwc = {
        .cbSize = sizeof(WNDCLASSEXW),
        .lpfnWndProc = tabbar_wnd_proc,
        .hInstance = hInstance,
        .hbrBackground = NULL,
        .lpszClassName = TABBAR_CLASS,
        .hCursor = LoadCursor(NULL, IDC_ARROW),
    };
    RegisterClassExW(&tbwc);

    editor_view_register(hInstance);

    s_tabs.container = CreateWindowExW(
        0, EDITORTABS_CLASS, NULL,
        WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN,
        0, 0, 100, 100,
        parent, (HMENU)IDC_EDITOR, hInstance, NULL
    );

    s_tabs.tabBar = CreateWindowExW(
        0, TABBAR_CLASS, NULL,
        WS_CHILD | WS_CLIPCHILDREN,
        0, 0, 100, TAB_HEIGHT,
        s_tabs.container, NULL, hInstance, NULL
    );

    return s_tabs.container;
}

void editor_tabs_open_file(const wchar_t *path) {
    if (!path || !*path) return;

    int existing = find_open_tab(path);
    if (existing >= 0) {
        s_tabs.active = existing;
        layout_editor_tabs();
        InvalidateRect(s_tabs.tabBar, NULL, FALSE);
        return;
    }

    if (s_tabs.count >= MAX_EDITOR_TABS) return;

    bool isImg = image_view_is_image_file(path);
    HWND hwndView = NULL;

    if (isImg) {
        hwndView = image_view_create(s_tabs.container, g_app.hInstance);
        if (hwndView) image_view_load(hwndView, path);
    } else {
        hwndView = editor_view_create(s_tabs.container, g_app.hInstance);
        if (hwndView) {
            EditorView *ev = editor_view_from_hwnd(hwndView);
            editor_view_load_file(ev, path);
        }
    }

    if (!hwndView) return;

    s_tabs.editors[s_tabs.count] = hwndView;
    wcscpy(s_tabs.paths[s_tabs.count], path);
    s_tabs.isImage[s_tabs.count] = isImg;
    s_tabs.active = s_tabs.count;
    s_tabs.count++;

    update_tab_labels();
    layout_editor_tabs();
}

void editor_tabs_close_current(void) {
    if (s_tabs.count <= 0) return;
    close_tab(s_tabs.active);
}

void editor_tabs_close_all(void) {
    for (int i = 0; i < s_tabs.count; i++) {
        DestroyWindow(s_tabs.editors[i]);
    }
    s_tabs.count = 0;
    s_tabs.active = 0;
    s_tabs.hoverTab = -1;
    s_tabs.hoverClose = -1;
    update_tab_labels();
    layout_editor_tabs();
    InvalidateRect(s_tabs.container, NULL, TRUE);
}

void editor_tabs_save_current(void) {
    if (s_tabs.active >= 0 && s_tabs.active < s_tabs.count) {
        if (s_tabs.isImage[s_tabs.active]) return; /* images are read-only */
        EditorView *ev = editor_view_from_hwnd(s_tabs.editors[s_tabs.active]);
        if (ev) editor_view_save(ev);
    }
}

const wchar_t *editor_tabs_current_file(void) {
    if (s_tabs.active >= 0 && s_tabs.active < s_tabs.count)
        return s_tabs.paths[s_tabs.active];
    return NULL;
}

bool editor_tabs_is_modified(void) {
    if (s_tabs.active >= 0 && s_tabs.active < s_tabs.count) {
        if (s_tabs.isImage[s_tabs.active]) return false;
        EditorView *ev = editor_view_from_hwnd(s_tabs.editors[s_tabs.active]);
        return ev ? ev->modified : false;
    }
    return false;
}

int editor_tabs_get_line_count(void) {
    if (s_tabs.active >= 0 && s_tabs.active < s_tabs.count) {
        if (s_tabs.isImage[s_tabs.active]) return 0;
        EditorView *ev = editor_view_from_hwnd(s_tabs.editors[s_tabs.active]);
        return ev ? tb_line_count(&ev->buffer) : 0;
    }
    return 0;
}

void editor_tabs_update_all_fonts(void) {
    for (int i = 0; i < s_tabs.count; i++) {
        if (s_tabs.isImage[i]) continue;
        EditorView *ev = editor_view_from_hwnd(s_tabs.editors[i]);
        if (ev) {
            ev->fontSize = g_app.editorFontSize;
            InvalidateRect(s_tabs.editors[i], NULL, TRUE);
        }
    }
}
