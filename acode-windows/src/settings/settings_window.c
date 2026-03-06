#include "settings_window.h"
#include "provider_ui.h"
#include "../app.h"
#include "../utils/theme.h"
#include "../utils/wstr.h"
#include "../services/update_checker.h"
#include "../services/usage_tracker.h"
#include "../window/main_window.h"
#include <commctrl.h>
#include <shellapi.h>
#include <stdio.h>
#include <windowsx.h>

#define SETTINGS_CLASS L"ACodeSettings"
#define SETTINGS_WIDTH  740
#define SETTINGS_HEIGHT 520

static HWND s_hwnd      = NULL;
static HWND s_hwndTabList = NULL;
static HWND s_hwndContent = NULL;

/* General settings controls */
#define IDC_GEN_RADIO_SYS    4001
#define IDC_GEN_RADIO_LIGHT  4002
#define IDC_GEN_RADIO_DARK   4003
#define IDC_GEN_FONTSLIDER   4004
#define IDC_GEN_FONTLABEL    4005
#define IDC_GEN_SHELLEDIT    4006
#define IDC_GEN_EDFONTSLD    4007
#define IDC_GEN_EDFONTLBL    4008
/* About controls */
#define IDC_ABOUT_COPYQQ     4010
#define IDC_ABOUT_UPDATE     4011
#define IDC_ABOUT_UPDATELBL  4012

static HWND s_hwndGenRadioSys   = NULL;
static HWND s_hwndGenRadioLight = NULL;
static HWND s_hwndGenRadioDark  = NULL;
static HWND s_hwndGenFontSlider = NULL;
static HWND s_hwndGenFontLabel  = NULL;
static HWND s_hwndGenEdFontSld  = NULL;
static HWND s_hwndGenEdFontLbl  = NULL;
static HWND s_hwndGenShell      = NULL;
static HWND s_hwndAboutUpdateLbl= NULL;
/* Provider sub-panel (one at a time) */
static HWND s_hwndProviderPanel = NULL;
static SettingsTab s_providerPanelTab = (SettingsTab)-1;

static const wchar_t *s_tabNames[] = {
    L"\u5E38\u89C4",       /* 常规 */
    L"Claude",
    L"OpenAI",
    L"Gemini",
    L"\u7528\u91CF",       /* 用量 */
    L"\u5173\u4E8E",       /* 关于 */
};

/* ---------------------------------------------------------------
 * 常规设置控件第一次创建
 * --------------------------------------------------------------- */
static void create_general_controls(HWND parent) {
    HINSTANCE hInst = g_app.hInstance;
    HFONT font = CreateFontW(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");

    /* 主题标题 */
    HWND lbl = CreateWindowExW(0, L"STATIC", L"\u4E3B\u9898",
        WS_CHILD | SS_LEFT, 16, 16, 200, 18, parent, NULL, hInst, NULL);
    SendMessageW(lbl, WM_SETFONT, (WPARAM)font, FALSE);

    /* RadioButton组 */
    s_hwndGenRadioSys = CreateWindowExW(0, L"BUTTON", L"\u8DDF\u968F\u7CFB\u7EDF",
        WS_CHILD | WS_TABSTOP | BS_AUTORADIOBUTTON | WS_GROUP,
        16, 38, 110, 22, parent, (HMENU)IDC_GEN_RADIO_SYS, hInst, NULL);
    SendMessageW(s_hwndGenRadioSys, WM_SETFONT, (WPARAM)font, FALSE);

    s_hwndGenRadioLight = CreateWindowExW(0, L"BUTTON", L"\u6D45\u8272",
        WS_CHILD | WS_TABSTOP | BS_AUTORADIOBUTTON,
        136, 38, 80, 22, parent, (HMENU)IDC_GEN_RADIO_LIGHT, hInst, NULL);
    SendMessageW(s_hwndGenRadioLight, WM_SETFONT, (WPARAM)font, FALSE);

    s_hwndGenRadioDark = CreateWindowExW(0, L"BUTTON", L"\u6DF1\u8272",
        WS_CHILD | WS_TABSTOP | BS_AUTORADIOBUTTON,
        226, 38, 80, 22, parent, (HMENU)IDC_GEN_RADIO_DARK, hInst, NULL);
    SendMessageW(s_hwndGenRadioDark, WM_SETFONT, (WPARAM)font, FALSE);

    /* 选中当前主题 */
    HWND *radios[] = { &s_hwndGenRadioSys, &s_hwndGenRadioLight, &s_hwndGenRadioDark };
    SendMessageW(*radios[g_app.theme], BM_SETCHECK, BST_CHECKED, 0);

    /* 字体大小标题 */
    HWND lblFont = CreateWindowExW(0, L"STATIC", L"\u7EC8\u7AEF\u5B57\u4F53\u5927\u5C0F",
        WS_CHILD | SS_LEFT, 16, 76, 200, 18, parent, NULL, hInst, NULL);
    SendMessageW(lblFont, WM_SETFONT, (WPARAM)font, FALSE);

    /* TrackBar */
    s_hwndGenFontSlider = CreateWindowExW(0, TRACKBAR_CLASS, NULL,
        WS_CHILD | WS_TABSTOP | TBS_HORZ | TBS_AUTOTICKS | TBS_TOOLTIPS,
        16, 96, 300, 32, parent, (HMENU)IDC_GEN_FONTSLIDER, hInst, NULL);
    SendMessageW(s_hwndGenFontSlider, TBM_SETRANGE,  TRUE, MAKELPARAM(10, 24));
    SendMessageW(s_hwndGenFontSlider, TBM_SETPOS,    TRUE, g_app.terminalFontSize);
    SendMessageW(s_hwndGenFontSlider, TBM_SETTICFREQ, 2,   0);

    /* 字体大小数字标签 */
    wchar_t fontBuf[32];
    _snwprintf(fontBuf, 32, L"%d pt", g_app.terminalFontSize);
    s_hwndGenFontLabel = CreateWindowExW(0, L"STATIC", fontBuf,
        WS_CHILD | SS_LEFT, 324, 102, 60, 18, parent, (HMENU)IDC_GEN_FONTLABEL, hInst, NULL);
    SendMessageW(s_hwndGenFontLabel, WM_SETFONT, (WPARAM)font, FALSE);

    /* 编辑器字体大小标题 */
    HWND lblEdFont = CreateWindowExW(0, L"STATIC", L"\u7F16\u8F91\u5668\u5B57\u4F53\u5927\u5C0F",
        WS_CHILD | SS_LEFT, 16, 146, 200, 18, parent, NULL, hInst, NULL);
    SendMessageW(lblEdFont, WM_SETFONT, (WPARAM)font, FALSE);

    /* 编辑器字体 TrackBar */
    s_hwndGenEdFontSld = CreateWindowExW(0, TRACKBAR_CLASS, NULL,
        WS_CHILD | WS_TABSTOP | TBS_HORZ | TBS_AUTOTICKS | TBS_TOOLTIPS,
        16, 166, 300, 32, parent, (HMENU)IDC_GEN_EDFONTSLD, hInst, NULL);
    SendMessageW(s_hwndGenEdFontSld, TBM_SETRANGE,  TRUE, MAKELPARAM(10, 28));
    SendMessageW(s_hwndGenEdFontSld, TBM_SETPOS,    TRUE, g_app.editorFontSize);
    SendMessageW(s_hwndGenEdFontSld, TBM_SETTICFREQ, 2,   0);

    /* 编辑器字体大小数字标签 */
    wchar_t edFontBuf[32];
    _snwprintf(edFontBuf, 32, L"%d pt", g_app.editorFontSize);
    s_hwndGenEdFontLbl = CreateWindowExW(0, L"STATIC", edFontBuf,
        WS_CHILD | SS_LEFT, 324, 172, 60, 18, parent, (HMENU)IDC_GEN_EDFONTLBL, hInst, NULL);
    SendMessageW(s_hwndGenEdFontLbl, WM_SETFONT, (WPARAM)font, FALSE);

    /* Shell 标题 */
    HWND lblShell = CreateWindowExW(0, L"STATIC", L"\u9ED8\u8BA4 Shell",
        WS_CHILD | SS_LEFT, 16, 216, 200, 18, parent, NULL, hInst, NULL);
    SendMessageW(lblShell, WM_SETFONT, (WPARAM)font, FALSE);

    /* Shell 输入框 */
    s_hwndGenShell = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", g_app.defaultShell,
        WS_CHILD | WS_TABSTOP | ES_AUTOHSCROLL,
        16, 236, 380, 24, parent, (HMENU)IDC_GEN_SHELLEDIT, hInst, NULL);
    SendMessageW(s_hwndGenShell, WM_SETFONT, (WPARAM)font, FALSE);

    /* 显示所有控件 */
    HWND ctls[] = { lbl, s_hwndGenRadioSys, s_hwndGenRadioLight, s_hwndGenRadioDark,
                    lblFont, s_hwndGenFontSlider, s_hwndGenFontLabel,
                    lblEdFont, s_hwndGenEdFontSld, s_hwndGenEdFontLbl,
                    lblShell, s_hwndGenShell };
    for (int i = 0; i < 12; i++) ShowWindow(ctls[i], SW_SHOW);
}

static void hide_general_controls(void) {
    HWND ctls[] = { s_hwndGenRadioSys, s_hwndGenRadioLight, s_hwndGenRadioDark,
                    s_hwndGenFontSlider, s_hwndGenFontLabel,
                    s_hwndGenEdFontSld, s_hwndGenEdFontLbl,
                    s_hwndGenShell };
    for (int i = 0; i < 8; i++) if (ctls[i]) ShowWindow(ctls[i], SW_HIDE);
}

static void apply_general_controls(void) {
    if (!s_hwndGenShell) return;
    /* Shell 路径 */
    GetWindowTextW(s_hwndGenShell, g_app.defaultShell, MAX_PATH);
    app_save_settings();
}

/* ---------------------------------------------------------------
 * 内容区切换逻辑
 * --------------------------------------------------------------- */
/* Background thread for auto update check (matches Mac onAppear) */
static DWORD WINAPI auto_update_check_thread(LPVOID param) {
    HWND lbl = (HWND)param;
    if (!lbl) return 0;
    UpdateCheckResult result;
    if (update_check(&result)) {
        if (result.hasUpdate) {
            wchar_t msg[256];
            _snwprintf(msg, 256, L"\u53D1\u73B0\u65B0\u7248\u672C v%s", result.latestVersion);
            SetWindowTextW(lbl, msg);
        } else {
            SetWindowTextW(lbl, L"\u2713 \u5DF2\u662F\u6700\u65B0\u7248\u672C");
        }
    }
    return 0;
}

static void switch_content_tab(SettingsTab tab) {
    /* 隐藏/销毁 Provider 面板 */
    if (s_hwndProviderPanel) {
        DestroyWindow(s_hwndProviderPanel);
        s_hwndProviderPanel = NULL;
        s_providerPanelTab = (SettingsTab)-1;
    }

    /* 隐藏常规设置控件 */
    if (tab != SETTINGS_TAB_GENERAL) hide_general_controls();
    else apply_general_controls();

    /* Provider tabs: 创建新面板 */
    if (tab == SETTINGS_TAB_CLAUDE || tab == SETTINGS_TAB_OPENAI || tab == SETTINGS_TAB_GEMINI) {
        RECT rc;
        GetClientRect(s_hwndContent, &rc);
        s_hwndProviderPanel = provider_ui_create(
            s_hwndContent, g_app.hInstance, tab,
            0, 0, rc.right, rc.bottom);
        s_providerPanelTab = tab;
    }

    /* 常规设置显示控件 */
    if (tab == SETTINGS_TAB_GENERAL) {
        HWND ctls[] = { s_hwndGenRadioSys, s_hwndGenRadioLight, s_hwndGenRadioDark,
                        s_hwndGenFontSlider, s_hwndGenFontLabel,
                        s_hwndGenEdFontSld, s_hwndGenEdFontLbl,
                        s_hwndGenShell };
        for (int i = 0; i < 8; i++) if (ctls[i]) ShowWindow(ctls[i], SW_SHOW);
    }

    /* Auto-check update when switching to About tab (matches Mac onAppear) */
    if (tab == SETTINGS_TAB_ABOUT && s_hwndAboutUpdateLbl) {
        SetWindowTextW(s_hwndAboutUpdateLbl, L"\u6B63\u5728\u68C0\u67E5\u66F4\u65B0...");
        HANDLE hThread = CreateThread(NULL, 0, auto_update_check_thread,
                                      (LPVOID)s_hwndAboutUpdateLbl, 0, NULL);
        if (hThread) CloseHandle(hThread);
    }

    InvalidateRect(s_hwndContent, NULL, TRUE);
}

/* ---------------------------------------------------------------
 * 内容区绿制
 * --------------------------------------------------------------- */
static void draw_about_content(HDC hdc, RECT *rc, const ThemeColors *colors) {
    /* App icon (64x64, centered) */
    HICON hIcon = LoadImageW(g_app.hInstance, L"IDI_APPICON", IMAGE_ICON, 64, 64, LR_DEFAULTCOLOR);
    if (hIcon) {
        int iconX = (rc->right - 64) / 2;
        DrawIconEx(hdc, iconX, 16, hIcon, 64, 64, 0, NULL, DI_NORMAL);
        DestroyIcon(hIcon);
    }

    /* App name */
    HFONT titleFont = CreateFontW(26, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    HFONT origFont = SelectObject(hdc, titleFont);
    SetTextColor(hdc, colors->text);

    RECT r = { 0, 88, rc->right, 118 };
    DrawTextW(hdc, L"ACode", -1, &r, DT_CENTER | DT_SINGLELINE);

    HFONT normalFont = CreateFontW(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    SelectObject(hdc, normalFont);
    DeleteObject(titleFont);
    SetBkMode(hdc, TRANSPARENT);

    r.top = 124; r.bottom = 144;
    SetTextColor(hdc, colors->textSecondary);
    DrawTextW(hdc, L"\u7248\u672C " ACODE_VERSION L" (Build " ACODE_BUILD L")",
              -1, &r, DT_CENTER | DT_SINGLELINE);

    r.top = 158; r.bottom = 218;
    DrawTextW(hdc,
        L"\u4E00\u7AD9\u5F0F AI \u7F16\u7A0B\u7EC8\u7AEF\uFF0C\u96C6\u6210\u591A\u5BB6\u5927\u6A21\u578B"
        L"\uFF0C\u8BA9\u4F60\u5728\u4E00\u4E2A\u7A97\u53E3\u5185\u5B8C\u6210\u4EE3\u7801\u7F16\u5199\u3001\u8C03\u8BD5\u4E0E\u90E8\u7F72",
        -1, &r, DT_CENTER | DT_WORDBREAK);

    r.top = 228; r.bottom = 246;
    SetTextColor(hdc, colors->textSecondary);
    DrawTextW(hdc, L"\u5B98\u65B9 QQ \u7FA4", -1, &r, DT_CENTER | DT_SINGLELINE);

    r.top = 250; r.bottom = 270;
    SetTextColor(hdc, colors->accent);
    DrawTextW(hdc, ACODE_QQ_GROUP L"  (\u70B9\u51FB\u590D\u5236)", -1, &r, DT_CENTER | DT_SINGLELINE);

    r.top = 290; r.bottom = 310;
    SetTextColor(hdc, colors->textSecondary);
    DrawTextW(hdc, L"Copyright \u00A9 2025 ACode. All rights reserved.",
              -1, &r, DT_CENTER | DT_SINGLELINE);

    SelectObject(hdc, origFont);
    DeleteObject(normalFont);
}

static void draw_usage_content(HDC hdc, RECT *rc, const ThemeColors *colors) {
    UsageStats stats;
    usage_tracker_get(&stats);

    HFONT font = CreateFontW(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    HFONT origFont = SelectObject(hdc, font);
    SetBkMode(hdc, TRANSPARENT);

    HFONT titleFont = CreateFontW(15, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");

    /* Title */
    SelectObject(hdc, titleFont);
    SetTextColor(hdc, colors->text);
    RECT r = { 16, 16, rc->right - 16, 36 };
    DrawTextW(hdc, L"\u672C\u6B21\u4F1A\u8BDD\u7528\u91CF", -1, &r, DT_LEFT | DT_SINGLELINE);

    SelectObject(hdc, font);

    /* Rows */
    struct { const wchar_t *label; long long val; bool isCost; } rows[] = {
        { L"\u8F93\u5165 Tokens",  stats.inputTokens,      false },
        { L"\u8F93\u51FA Tokens",  stats.outputTokens,     false },
        { L"\u7F13\u5B58\u8BFB\u53D6", stats.cacheReadTokens, false },
        { L"\u8BF7\u6C42\u6B21\u6570", stats.requestCount,   false },
    };

    int y = 48;
    for (int i = 0; i < 4; i++) {
        SetTextColor(hdc, colors->textSecondary);
        RECT lr = { 16, y, 200, y + 20 };
        DrawTextW(hdc, rows[i].label, -1, &lr, DT_LEFT | DT_SINGLELINE);

        wchar_t valBuf[64];
        if (rows[i].val >= 1000000)
            _snwprintf(valBuf, 64, L"%.1fM", (double)rows[i].val / 1000000.0);
        else if (rows[i].val >= 1000)
            _snwprintf(valBuf, 64, L"%.1fK", (double)rows[i].val / 1000.0);
        else
            _snwprintf(valBuf, 64, L"%lld", rows[i].val);

        SetTextColor(hdc, colors->text);
        RECT vr = { 200, y, rc->right - 16, y + 20 };
        DrawTextW(hdc, valBuf, -1, &vr, DT_RIGHT | DT_SINGLELINE);
        y += 28;
    }

    /* Cost row (highlighted) */
    SetTextColor(hdc, colors->textSecondary);
    RECT lr = { 16, y + 8, 200, y + 28 };
    DrawTextW(hdc, L"\u9884\u4F30\u8D39\u7528", -1, &lr, DT_LEFT | DT_SINGLELINE);

    wchar_t costBuf[32];
    if (stats.estimatedCost >= 1.0)
        _snwprintf(costBuf, 32, L"$%.2f", stats.estimatedCost);
    else if (stats.estimatedCost >= 0.01)
        _snwprintf(costBuf, 32, L"$%.3f", stats.estimatedCost);
    else
        _snwprintf(costBuf, 32, L"$%.4f", stats.estimatedCost);

    SetTextColor(hdc, RGB(52, 199, 89));
    RECT vr2 = { 200, y + 8, rc->right - 16, y + 28 };
    DrawTextW(hdc, costBuf, -1, &vr2, DT_RIGHT | DT_SINGLELINE);

    SelectObject(hdc, origFont);
    DeleteObject(font);
    DeleteObject(titleFont);
}

static LRESULT CALLBACK content_wnd_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {

    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);
        const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);

        RECT rc;
        GetClientRect(hwnd, &rc);
        HBRUSH bg = CreateSolidBrush(colors->background);
        FillRect(hdc, &rc, bg);
        DeleteObject(bg);

        SetBkMode(hdc, TRANSPARENT);

        switch (g_app.settingsTab) {
        case SETTINGS_TAB_ABOUT:
            draw_about_content(hdc, &rc, colors);
            break;
        case SETTINGS_TAB_USAGE:
            draw_usage_content(hdc, &rc, colors);
            break;
        case SETTINGS_TAB_GENERAL:
            /* 常规设置由 Win32 控件负责，仅绘小标题 */
            break;
        default:
            /* Provider tabs 由 provider_ui_create 窗口负责 */
            break;
        }

        EndPaint(hwnd, &ps);
        return 0;
    }

    case WM_LBUTTONDOWN: {
        /* 关于页点击 QQ 群号复制 */
        if (g_app.settingsTab == SETTINGS_TAB_ABOUT) {
            int x = GET_X_LPARAM(lParam);
            int y = GET_Y_LPARAM(lParam);
            RECT rc;
            GetClientRect(hwnd, &rc);
            /* QQ 群号在 y=250..270 行 (adjusted for app icon) */
            if (y >= 250 && y <= 270) {
                if (OpenClipboard(hwnd)) {
                    EmptyClipboard();
                    HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, (wcslen(ACODE_QQ_GROUP) + 1) * sizeof(wchar_t));
                    if (hMem) {
                        wchar_t *pMem = (wchar_t *)GlobalLock(hMem);
                        wcscpy(pMem, ACODE_QQ_GROUP);
                        GlobalUnlock(hMem);
                        SetClipboardData(CF_UNICODETEXT, hMem);
                    }
                    CloseClipboard();
                    SetWindowTextW(s_hwndAboutUpdateLbl, L"\u7FA4\u53F7\u5DF2\u590D\u5236\u5230\u526A\u8D34\u677F");
                }
            }
        }
        return 0;
    }

    case WM_COMMAND: {
        int id = LOWORD(wParam);
        int code = HIWORD(wParam);

        /* 主题 RadioButton */
        if (id == IDC_GEN_RADIO_SYS && code == BN_CLICKED) {
            g_app.theme = THEME_SYSTEM;
            g_app.isDarkMode = app_is_dark_mode();
            app_save_settings();
            PostMessageW(g_app.hMainWnd, WM_ACODE_THEME_MANUAL, 0, 0);
        } else if (id == IDC_GEN_RADIO_LIGHT && code == BN_CLICKED) {
            g_app.theme = THEME_LIGHT;
            g_app.isDarkMode = false;
            app_save_settings();
            PostMessageW(g_app.hMainWnd, WM_ACODE_THEME_MANUAL, 0, 0);
        } else if (id == IDC_GEN_RADIO_DARK && code == BN_CLICKED) {
            g_app.theme = THEME_DARK;
            g_app.isDarkMode = true;
            app_save_settings();
            PostMessageW(g_app.hMainWnd, WM_ACODE_THEME_MANUAL, 0, 0);
        }

        /* Shell 路径编辑完毕 */
        if (id == IDC_GEN_SHELLEDIT && code == EN_KILLFOCUS) {
            GetWindowTextW(s_hwndGenShell, g_app.defaultShell, MAX_PATH);
            app_save_settings();
        }

        /* 关于页按鈕 */
        if (id == IDC_ABOUT_COPYQQ) {
            if (OpenClipboard(hwnd)) {
                EmptyClipboard();
                HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, (wcslen(ACODE_QQ_GROUP) + 1) * sizeof(wchar_t));
                if (hMem) {
                    wchar_t *pMem = (wchar_t *)GlobalLock(hMem);
                    wcscpy(pMem, ACODE_QQ_GROUP);
                    GlobalUnlock(hMem);
                    SetClipboardData(CF_UNICODETEXT, hMem);
                }
                CloseClipboard();
                if (s_hwndAboutUpdateLbl)
                    SetWindowTextW(s_hwndAboutUpdateLbl, L"\u7FA4\u53F7\u5DF2\u590D\u5236\u5230\u526A\u8D34\u677F");
            }
        }
        if (id == IDC_ABOUT_UPDATE) {
            if (s_hwndAboutUpdateLbl)
                SetWindowTextW(s_hwndAboutUpdateLbl, L"\u6B63\u5728\u68C0\u67E5\u66F4\u65B0...");
            UpdateCheckResult result;
            if (update_check(&result)) {
                if (result.hasUpdate) {
                    wchar_t msg[256];
                    _snwprintf(msg, 256, L"\u53D1\u73B0\u65B0\u7248\u672C v%s\uFF0C\u8BF7\u524D\u5F80 GitHub \u4E0B\u8F7D",
                               result.latestVersion);
                    if (s_hwndAboutUpdateLbl) SetWindowTextW(s_hwndAboutUpdateLbl, msg);
                    if (result.downloadUrl[0]) ShellExecuteW(NULL, L"open", result.downloadUrl, NULL, NULL, SW_SHOW);
                } else {
                    if (s_hwndAboutUpdateLbl) SetWindowTextW(s_hwndAboutUpdateLbl, L"\u5DF2\u662F\u6700\u65B0\u7248\u672C");
                }
            } else {
                if (s_hwndAboutUpdateLbl) SetWindowTextW(s_hwndAboutUpdateLbl, L"\u68C0\u67E5\u5931\u8D25\uFF0C\u8BF7\u68C0\u67E5\u7F51\u7EDC");
            }
        }
        return 0;
    }

    case WM_HSCROLL: {
        /* TrackBar 终端字体大小 */
        if ((HWND)lParam == s_hwndGenFontSlider) {
            int pos = (int)SendMessageW(s_hwndGenFontSlider, TBM_GETPOS, 0, 0);
            g_app.terminalFontSize = pos;
            wchar_t buf[32];
            _snwprintf(buf, 32, L"%d pt", pos);
            if (s_hwndGenFontLabel) SetWindowTextW(s_hwndGenFontLabel, buf);
            app_save_settings();
            /* Notify main window to update terminal font */
            PostMessageW(g_app.hMainWnd, WM_ACODE_FONT_CHANGE, (WPARAM)pos, 0);
        }
        /* TrackBar 编辑器字体大小 */
        if ((HWND)lParam == s_hwndGenEdFontSld) {
            int pos = (int)SendMessageW(s_hwndGenEdFontSld, TBM_GETPOS, 0, 0);
            g_app.editorFontSize = pos;
            wchar_t buf[32];
            _snwprintf(buf, 32, L"%d pt", pos);
            if (s_hwndGenEdFontLbl) SetWindowTextW(s_hwndGenEdFontLbl, buf);
            app_save_settings();
            /* Notify main window to update open editors (matches Mac real-time update) */
            PostMessageW(g_app.hMainWnd, WM_ACODE_EDITOR_FONT, (WPARAM)pos, 0);
        }
        return 0;
    }

    case WM_SIZE: {
        /* 调整 Provider 面板大小 */
        if (s_hwndProviderPanel) {
            RECT rc;
            GetClientRect(hwnd, &rc);
            MoveWindow(s_hwndProviderPanel, 0, 0, rc.right, rc.bottom, TRUE);
        }
        return 0;
    }

    case WM_ERASEBKGND:
        return 1;
    }
    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

static LRESULT CALLBACK settings_wnd_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_CREATE: {
        /* Sidebar tab list */
        s_hwndTabList = CreateWindowExW(0, WC_LISTBOXW, NULL,
            WS_CHILD | WS_VISIBLE | LBS_NOTIFY | LBS_NOINTEGRALHEIGHT,
            0, 40, 160, 460, hwnd, (HMENU)1, g_app.hInstance, NULL);

        HFONT tabFont = CreateFontW(14, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
        SendMessageW(s_hwndTabList, WM_SETFONT, (WPARAM)tabFont, TRUE);
        SendMessageW(s_hwndTabList, LB_SETITEMHEIGHT, 0, 32);

        for (int i = 0; i < SETTINGS_TAB_COUNT; i++)
            SendMessageW(s_hwndTabList, LB_ADDSTRING, 0, (LPARAM)s_tabNames[i]);
        SendMessageW(s_hwndTabList, LB_SETCURSEL, g_app.settingsTab, 0);

        /* Content area */
        static bool s_contentClassRegistered = false;
        if (!s_contentClassRegistered) {
            WNDCLASSEXW wcc = {
                .cbSize        = sizeof(WNDCLASSEXW),
                .lpfnWndProc   = content_wnd_proc,
                .hInstance     = g_app.hInstance,
                .hbrBackground = NULL,
                .lpszClassName = L"ACodeSettingsContent",
                .hCursor       = LoadCursor(NULL, IDC_ARROW),
            };
            RegisterClassExW(&wcc);
            s_contentClassRegistered = true;
        }

        s_hwndContent = CreateWindowExW(0, L"ACodeSettingsContent", NULL,
            WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN,
            160, 40, SETTINGS_WIDTH - 160, SETTINGS_HEIGHT - 40,
            hwnd, NULL, g_app.hInstance, NULL);

        /* 创建常规设置控件（初始隐藏，切换到该 tab 时才显示） */
        create_general_controls(s_hwndContent);
        /* 如果当前 tab 不是常规，先隐藏 */
        if (g_app.settingsTab != SETTINGS_TAB_GENERAL)
            hide_general_controls();

        /* 关于页按鈕 */
        HFONT btnFont = CreateFontW(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");

        HWND btnCopyQQ = CreateWindowExW(0, L"BUTTON", L"\u590D\u5236 QQ \u7FA4\u53F7",
            WS_CHILD | WS_TABSTOP | BS_PUSHBUTTON,
            (SETTINGS_WIDTH - 160) / 2 - 100, 218, 120, 26,
            s_hwndContent, (HMENU)IDC_ABOUT_COPYQQ, g_app.hInstance, NULL);
        SendMessageW(btnCopyQQ, WM_SETFONT, (WPARAM)btnFont, FALSE);

        HWND btnUpdate = CreateWindowExW(0, L"BUTTON", L"\u68C0\u67E5\u66F4\u65B0",
            WS_CHILD | WS_TABSTOP | BS_PUSHBUTTON,
            (SETTINGS_WIDTH - 160) / 2 + 28, 218, 100, 26,
            s_hwndContent, (HMENU)IDC_ABOUT_UPDATE, g_app.hInstance, NULL);
        SendMessageW(btnUpdate, WM_SETFONT, (WPARAM)btnFont, FALSE);

        /* 更新状态标签 */
        s_hwndAboutUpdateLbl = CreateWindowExW(0, L"STATIC", NULL,
            WS_CHILD | SS_CENTER,
            0, 252, SETTINGS_WIDTH - 160, 20,
            s_hwndContent, (HMENU)IDC_ABOUT_UPDATELBL, g_app.hInstance, NULL);
        SendMessageW(s_hwndAboutUpdateLbl, WM_SETFONT, (WPARAM)btnFont, FALSE);

        /* 按内容 tab 初始化面板 */
        switch_content_tab(g_app.settingsTab);

        /* 隐藏关于页按鈕（仅关于页显示） */
        if (g_app.settingsTab != SETTINGS_TAB_ABOUT) {
            ShowWindow(btnCopyQQ, SW_HIDE);
            ShowWindow(btnUpdate, SW_HIDE);
            ShowWindow(s_hwndAboutUpdateLbl, SW_HIDE);
        }

        return 0;
    }

    case WM_COMMAND:
        /* 内容区控件命令转发到 content 窗口 */
        if (s_hwndContent && LOWORD(wParam) != 1)
            SendMessageW(s_hwndContent, WM_COMMAND, wParam, lParam);

        if (LOWORD(wParam) == 1 && HIWORD(wParam) == LBN_SELCHANGE) {
            int sel = (int)SendMessageW(s_hwndTabList, LB_GETCURSEL, 0, 0);
            if (sel >= 0 && sel < SETTINGS_TAB_COUNT) {
                g_app.settingsTab = (SettingsTab)sel;
                switch_content_tab((SettingsTab)sel);

                /* 关于页按鈕显隐 */
                HWND btnCQ = GetDlgItem(s_hwndContent, IDC_ABOUT_COPYQQ);
                HWND btnUp = GetDlgItem(s_hwndContent, IDC_ABOUT_UPDATE);
                HWND lblUp = GetDlgItem(s_hwndContent, IDC_ABOUT_UPDATELBL);
                BOOL isAbout = (sel == SETTINGS_TAB_ABOUT);
                if (btnCQ) ShowWindow(btnCQ, isAbout ? SW_SHOW : SW_HIDE);
                if (btnUp) ShowWindow(btnUp, isAbout ? SW_SHOW : SW_HIDE);
                if (lblUp) ShowWindow(lblUp, isAbout ? SW_SHOW : SW_HIDE);
            }
        }
        break;

    case WM_KEYDOWN:
        if (wParam == VK_ESCAPE) {
            settings_hide();
            return 0;
        }
        break;

    case WM_SIZE: {
        RECT rc;
        GetClientRect(hwnd, &rc);
        int listW = 160;
        if (s_hwndTabList)
            MoveWindow(s_hwndTabList, 0, 40, listW, rc.bottom - 40, TRUE);
        if (s_hwndContent)
            MoveWindow(s_hwndContent, listW, 40, rc.right - listW, rc.bottom - 40, TRUE);
        return 0;
    }

    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);
        const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);

        RECT rc;
        GetClientRect(hwnd, &rc);
        HBRUSH bg = CreateSolidBrush(colors->surface);
        FillRect(hdc, &rc, bg);
        DeleteObject(bg);

        /* Title bar area */
        HFONT titleFont = CreateFontW(16, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
        HFONT origFont = SelectObject(hdc, titleFont);
        SetBkMode(hdc, TRANSPARENT);
        SetTextColor(hdc, colors->text);

        RECT titleRect = { 12, 8, rc.right - 100, 36 };
        DrawTextW(hdc, L"\u8BBE\u7F6E", -1, &titleRect, DT_LEFT | DT_VCENTER | DT_SINGLELINE);

        /* "Return to app" button area */
        HFONT btnFont = CreateFontW(12, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
        SelectObject(hdc, btnFont);
        DeleteObject(titleFont);
        SetTextColor(hdc, colors->accent);

        RECT btnRect = { rc.right - 140, 8, rc.right - 8, 36 };
        DrawTextW(hdc, L"\u8FD4\u56DE\u5E94\u7528\u7A0B\u5E8F", -1, &btnRect,
                  DT_RIGHT | DT_VCENTER | DT_SINGLELINE);
        SelectObject(hdc, origFont);
        DeleteObject(btnFont);

        EndPaint(hwnd, &ps);
        return 0;
    }

    case WM_LBUTTONDOWN: {
        RECT rc;
        GetClientRect(hwnd, &rc);
        int x = GET_X_LPARAM(lParam);
        int y = GET_Y_LPARAM(lParam);
        /* Check "return to app" click area */
        if (x > rc.right - 150 && y < 36) {
            settings_hide();
        }
        return 0;
    }

    case WM_ERASEBKGND:
        return 1;

    case WM_CLOSE:
        settings_hide();
        return 0;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

void settings_show(HWND parent) {
    if (s_hwnd && IsWindowVisible(s_hwnd)) {
        SetFocus(s_hwnd);
        return;
    }

    static bool s_classRegistered = false;
    if (!s_classRegistered) {
        WNDCLASSEXW wc = {
            .cbSize = sizeof(WNDCLASSEXW),
            .lpfnWndProc = settings_wnd_proc,
            .hInstance = g_app.hInstance,
            .hbrBackground = NULL,
            .lpszClassName = SETTINGS_CLASS,
            .hCursor = LoadCursor(NULL, IDC_ARROW),
        };
        RegisterClassExW(&wc);
        s_classRegistered = true;
    }

    RECT parentRect;
    GetClientRect(parent, &parentRect);

    s_hwnd = CreateWindowExW(
        0,
        SETTINGS_CLASS, NULL,
        WS_CHILD | WS_CLIPCHILDREN,
        0, 0, parentRect.right, parentRect.bottom,
        parent, NULL, g_app.hInstance, NULL
    );

    ShowWindow(s_hwnd, SW_SHOW);
    SetFocus(s_hwnd);
    UpdateWindow(s_hwnd);
    g_app.settingsOpen = true;
}

void settings_hide(void) {
    if (s_hwnd) {
        DestroyWindow(s_hwnd);
        s_hwnd             = NULL;
        s_hwndTabList      = NULL;
        s_hwndContent      = NULL;
        s_hwndGenRadioSys  = NULL;
        s_hwndGenRadioLight= NULL;
        s_hwndGenRadioDark = NULL;
        s_hwndGenFontSlider= NULL;
        s_hwndGenFontLabel = NULL;
        s_hwndGenShell     = NULL;
        s_hwndAboutUpdateLbl = NULL;
        s_hwndProviderPanel  = NULL;
        s_providerPanelTab   = (SettingsTab)-1;
    }
    g_app.settingsOpen = false;
}

bool settings_is_visible(void) {
    return s_hwnd && IsWindowVisible(s_hwnd);
}
