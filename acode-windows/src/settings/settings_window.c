#include "settings_window.h"
#include "provider_ui.h"
#include "mcp_ui.h"
#include "skills_ui.h"
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

/* Thread-safe update check result notification */
#define WM_SW_UPDATE_RESULT (WM_USER + 200)
/* wParam: 1=hasUpdate, 0=upToDate; lParam: pointer to version string (heap, receiver frees) */

static HWND s_hwnd      = NULL;
static HWND s_hwndTabList = NULL;
static HWND s_hwndContent = NULL;

/* Cached GDI fonts for settings window (avoid per-paint creation) */
static HFONT s_swGroupFont   = NULL;  /* sidebar group header */
static HFONT s_swTabFont     = NULL;  /* sidebar tab item */
static HFONT s_swTitleFont   = NULL;  /* about page app title */
static HFONT s_swNormalFont  = NULL;  /* about/usage body text */
static HFONT s_swUsageTitleFont = NULL; /* usage section title */
static HFONT s_swContentTitleFont = NULL; /* content area title (18pt semibold) */

static void ensure_sw_fonts(void) {
    if (!s_swGroupFont)
        s_swGroupFont = CreateFontW(10, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    if (!s_swTabFont)
        s_swTabFont = CreateFontW(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    if (!s_swTitleFont)
        s_swTitleFont = CreateFontW(26, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    if (!s_swNormalFont)
        s_swNormalFont = CreateFontW(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    if (!s_swUsageTitleFont)
        s_swUsageTitleFont = CreateFontW(15, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    if (!s_swContentTitleFont)
        s_swContentTitleFont = CreateFontW(18, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
}

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
/* MCP / Skills sub-panel */
static HWND s_hwndMCPPanel    = NULL;
static HWND s_hwndSkillsPanel = NULL;
static SettingsTab s_prevValidTab = SETTINGS_TAB_GENERAL;  /* for group-skip */

/* ---- Sidebar grouped items (matches Mac InlineSettingsView) ---- */
typedef enum { SB_GROUP, SB_TAB } SBItemType;
typedef struct {
    SBItemType     type;
    const wchar_t *text;
    const wchar_t *icon;
    SettingsTab    tab;
    COLORREF       iconColor;  /* 0 = use theme secondary */
} SBItem;

#define SB_ITEM_COUNT 13
static const SBItem s_sbItems[SB_ITEM_COUNT] = {
    { SB_GROUP, L"\u57FA\u7840",         NULL,         0, 0 },
    { SB_TAB,   L"\u5E38\u89C4",         L"\u2699",   SETTINGS_TAB_GENERAL, 0 },
    { SB_GROUP, L"\u670D\u52A1\u5546",   NULL,         0, 0 },
    { SB_TAB,   L"Claude",               L"\u25CF",   SETTINGS_TAB_CLAUDE,  RGB(212,145,93) },
    { SB_TAB,   L"OpenAI",               L"\u25CF",   SETTINGS_TAB_OPENAI,  RGB(0,166,126) },
    { SB_TAB,   L"Gemini",               L"\u25CF",   SETTINGS_TAB_GEMINI,  RGB(66,133,244) },
    { SB_GROUP, L"\u5DE5\u5177",         NULL,         0, 0 },
    { SB_TAB,   L"MCP \u7BA1\u7406",     L"\u25A3",   SETTINGS_TAB_MCP,     0 },
    { SB_TAB,   L"Skills \u7BA1\u7406", L"\u2605",   SETTINGS_TAB_SKILLS,  0 },
    { SB_GROUP, L"\u9AD8\u7EA7",         NULL,         0, 0 },
    { SB_TAB,   L"\u7528\u91CF",         L"\u25CE",   SETTINGS_TAB_USAGE,   0 },
    { SB_GROUP, L"\u5176\u4ED6",         NULL,         0, 0 },
    { SB_TAB,   L"\u5173\u4E8E",         L"\u2139",   SETTINGS_TAB_ABOUT,   0 },
};

static int sb_find_index_for_tab(SettingsTab tab) {
    for (int i = 0; i < SB_ITEM_COUNT; i++)
        if (s_sbItems[i].type == SB_TAB && s_sbItems[i].tab == tab) return i;
    return 1;
}

static HWND s_hwndBackBtn     = NULL;
static HWND s_hwndContentTitle = NULL;
#define IDC_BACK_BTN 4020

/* ---- Draw one sidebar item (owner-drawn ListBox) ---- */
static void draw_sidebar_item(DRAWITEMSTRUCT *di) {
    if (di->itemID >= (UINT)SB_ITEM_COUNT) {
        const ThemeColors *c = theme_get_colors(g_app.isDarkMode);
        HBRUSH bg = CreateSolidBrush(c->surface);
        FillRect(di->hDC, &di->rcItem, bg);
        DeleteObject(bg);
        return;
    }
    const SBItem *item = &s_sbItems[di->itemID];
    const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);
    HDC hdc = di->hDC;
    RECT rc = di->rcItem;

    HBRUSH bgBrush = CreateSolidBrush(colors->surface);
    FillRect(hdc, &rc, bgBrush);
    DeleteObject(bgBrush);
    SetBkMode(hdc, TRANSPARENT);

    ensure_sw_fonts();

    if (item->type == SB_GROUP) {
        HFONT oldFont = SelectObject(hdc, s_swGroupFont);
        SetTextColor(hdc, g_app.isDarkMode ? RGB(120,120,130) : RGB(140,140,150));
        RECT tr = { rc.left + 16, rc.top, rc.right - 4, rc.bottom };
        DrawTextW(hdc, item->text, -1, &tr, DT_LEFT | DT_BOTTOM | DT_SINGLELINE);
        SelectObject(hdc, oldFont);
    } else {
        bool selected = (di->itemState & ODS_SELECTED) != 0;
        if (selected) {
            RECT hl = { rc.left + 6, rc.top + 1, rc.right - 6, rc.bottom - 1 };
            COLORREF hlClr = g_app.isDarkMode ? RGB(55,55,62) : RGB(215,215,222);
            HBRUSH hlBr = CreateSolidBrush(hlClr);
            HPEN hlPen = CreatePen(PS_SOLID, 1, hlClr);
            HPEN op = SelectObject(hdc, hlPen);
            HBRUSH ob = SelectObject(hdc, hlBr);
            RoundRect(hdc, hl.left, hl.top, hl.right, hl.bottom, 8, 8);
            SelectObject(hdc, op); SelectObject(hdc, ob);
            DeleteObject(hlPen); DeleteObject(hlBr);
        }

        HFONT oldFont = SelectObject(hdc, s_swTabFont);

        if (item->icon) {
            COLORREF ic = item->iconColor ? item->iconColor : colors->textSecondary;
            SetTextColor(hdc, ic);
            RECT ir = { rc.left + 14, rc.top, rc.left + 32, rc.bottom };
            DrawTextW(hdc, item->icon, -1, &ir, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
        }
        SetTextColor(hdc, selected ? colors->text : (g_app.isDarkMode ? RGB(185,185,190) : RGB(70,70,75)));
        RECT tr = { rc.left + 34, rc.top, rc.right - 4, rc.bottom };
        DrawTextW(hdc, item->text, -1, &tr, DT_LEFT | DT_VCENTER | DT_SINGLELINE);

        SelectObject(hdc, oldFont);
    }
}

/* ---------------------------------------------------------------
 * 常规设置控件第一次创建
 * --------------------------------------------------------------- */
static void create_general_controls(HWND parent) {
    HINSTANCE hInst = g_app.hInstance;
    ensure_sw_fonts();
    HFONT font = s_swNormalFont;  /* reuse cached font, no leak */

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
    HWND contentWnd = (HWND)param;
    if (!contentWnd) return 0;
    UpdateCheckResult result;
    if (update_check(&result)) {
        if (result.hasUpdate) {
            /* Allocate version string on heap; UI thread will free it */
            wchar_t *ver = (wchar_t *)malloc(256 * sizeof(wchar_t));
            if (ver) {
                _snwprintf(ver, 256, L"%s", result.latestVersion);
                PostMessageW(contentWnd, WM_SW_UPDATE_RESULT, 1, (LPARAM)ver);
            }
        } else {
            PostMessageW(contentWnd, WM_SW_UPDATE_RESULT, 0, 0);
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

    /* 隐藏/销毁 MCP 面板 */
    if (s_hwndMCPPanel) {
        DestroyWindow(s_hwndMCPPanel);
        s_hwndMCPPanel = NULL;
    }

    /* 隐藏/销毁 Skills 面板 */
    if (s_hwndSkillsPanel) {
        DestroyWindow(s_hwndSkillsPanel);
        s_hwndSkillsPanel = NULL;
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

    /* MCP tab: 创建 MCP 管理面板 */
    if (tab == SETTINGS_TAB_MCP) {
        RECT rc;
        GetClientRect(s_hwndContent, &rc);
        s_hwndMCPPanel = mcp_ui_create(
            s_hwndContent, g_app.hInstance,
            0, 0, rc.right, rc.bottom);
    }

    /* Skills tab: 创建技能管理面板 */
    if (tab == SETTINGS_TAB_SKILLS) {
        RECT rc;
        GetClientRect(s_hwndContent, &rc);
        s_hwndSkillsPanel = skills_ui_create(
            s_hwndContent, g_app.hInstance,
            0, 0, rc.right, rc.bottom);
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
                                      (LPVOID)s_hwndContent, 0, NULL);
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
    ensure_sw_fonts();
    HFONT origFont = SelectObject(hdc, s_swTitleFont);
    SetTextColor(hdc, colors->text);

    RECT r = { 0, 88, rc->right, 118 };
    DrawTextW(hdc, L"ACode", -1, &r, DT_CENTER | DT_SINGLELINE);

    SelectObject(hdc, s_swNormalFont);
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
}

static void draw_usage_content(HDC hdc, RECT *rc, const ThemeColors *colors) {
    UsageStats stats;
    usage_tracker_get(&stats);

    ensure_sw_fonts();
    HFONT origFont = SelectObject(hdc, s_swNormalFont);
    SetBkMode(hdc, TRANSPARENT);

    /* Title */
    SelectObject(hdc, s_swUsageTitleFont);
    SetTextColor(hdc, colors->text);
    RECT r = { 16, 16, rc->right - 16, 36 };
    DrawTextW(hdc, L"\u672C\u6B21\u4F1A\u8BDD\u7528\u91CF", -1, &r, DT_LEFT | DT_SINGLELINE);

    SelectObject(hdc, s_swNormalFont);

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
                    _snwprintf(msg, 256, L"\u53D1\u73B0\u65B0\u7248\u672C v%s",
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
        RECT rc;
        GetClientRect(hwnd, &rc);
        /* 调整 Provider 面板大小 */
        if (s_hwndProviderPanel)
            MoveWindow(s_hwndProviderPanel, 0, 0, rc.right, rc.bottom, TRUE);
        /* 调整 MCP 面板大小 */
        if (s_hwndMCPPanel)
            MoveWindow(s_hwndMCPPanel, 0, 0, rc.right, rc.bottom, TRUE);
        /* 调整 Skills 面板大小 */
        if (s_hwndSkillsPanel)
            MoveWindow(s_hwndSkillsPanel, 0, 0, rc.right, rc.bottom, TRUE);
        return 0;
    }

    case WM_SW_UPDATE_RESULT: {
        /* Thread-safe: update label text on UI thread */
        if (s_hwndAboutUpdateLbl) {
            if (wParam == 1) {
                wchar_t *ver = (wchar_t *)lParam;
                if (ver) {
                    wchar_t msg[256];
                    _snwprintf(msg, 256, L"\u53D1\u73B0\u65B0\u7248\u672C v%s", ver);
                    SetWindowTextW(s_hwndAboutUpdateLbl, msg);
                    free(ver);
                }
            } else {
                SetWindowTextW(s_hwndAboutUpdateLbl, L"\u2713 \u5DF2\u662F\u6700\u65B0\u7248\u672C");
            }
        } else {
            /* Window destroyed before result arrived; free heap string */
            if (wParam == 1 && lParam) free((void *)lParam);
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
        HINSTANCE hInst = g_app.hInstance;
        int sideW = 190;

        /* ---- Owner-drawn sidebar (matches Mac InlineSettingsView) ---- */
        s_hwndTabList = CreateWindowExW(0, WC_LISTBOXW, NULL,
            WS_CHILD | WS_VISIBLE | LBS_OWNERDRAWVARIABLE | LBS_NOTIFY
            | LBS_NOINTEGRALHEIGHT,
            0, 0, sideW, 460, hwnd, (HMENU)1, hInst, NULL);
        for (int i = 0; i < SB_ITEM_COUNT; i++)
            SendMessageW(s_hwndTabList, LB_ADDSTRING, 0, (LPARAM)s_sbItems[i].text);
        int initSel = sb_find_index_for_tab(g_app.settingsTab);
        SendMessageW(s_hwndTabList, LB_SETCURSEL, initSel, 0);
        s_prevValidTab = g_app.settingsTab;

        /* "返回应用程序" button at sidebar bottom (matches Mac) */
        ensure_sw_fonts();
        s_hwndBackBtn = CreateWindowExW(0, L"BUTTON",
            L"\u276E  \u8FD4\u56DE\u5E94\u7528\u7A0B\u5E8F",
            WS_CHILD | WS_VISIBLE | BS_FLAT | BS_LEFT,
            0, 0, sideW, 36, hwnd, (HMENU)IDC_BACK_BTN, hInst, NULL);
        SendMessageW(s_hwndBackBtn, WM_SETFONT, (WPARAM)s_swNormalFont, FALSE);

        /* ---- Content area ---- */
        int titleH = 52;
        static bool s_contentClassRegistered = false;
        if (!s_contentClassRegistered) {
            WNDCLASSEXW wcc = {
                .cbSize        = sizeof(WNDCLASSEXW),
                .lpfnWndProc   = content_wnd_proc,
                .hInstance     = hInst,
                .hbrBackground = NULL,
                .lpszClassName = L"ACodeSettingsContent",
                .hCursor       = LoadCursor(NULL, IDC_ARROW),
            };
            RegisterClassExW(&wcc);
            s_contentClassRegistered = true;
        }

        /* Content title label — child of settings window, above content */
        int tabIdx = sb_find_index_for_tab(g_app.settingsTab);
        s_hwndContentTitle = CreateWindowExW(0, L"STATIC",
            s_sbItems[tabIdx].text,
            WS_CHILD | WS_VISIBLE | SS_LEFT | SS_CENTERIMAGE,
            sideW + 24, 8, 400, titleH - 8, hwnd, NULL, hInst, NULL);
        SendMessageW(s_hwndContentTitle, WM_SETFONT, (WPARAM)s_swContentTitleFont, FALSE);

        /* Content area — below title */
        s_hwndContent = CreateWindowExW(0, L"ACodeSettingsContent", NULL,
            WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN,
            sideW, titleH, SETTINGS_WIDTH - sideW, SETTINGS_HEIGHT - titleH,
            hwnd, NULL, hInst, NULL);

        /* 常规设置控件 */
        create_general_controls(s_hwndContent);
        if (g_app.settingsTab != SETTINGS_TAB_GENERAL)
            hide_general_controls();

        /* 关于页按钮 */
        HWND btnCopyQQ = CreateWindowExW(0, L"BUTTON", L"\u590D\u5236 QQ \u7FA4\u53F7",
            WS_CHILD | WS_TABSTOP | BS_PUSHBUTTON,
            (SETTINGS_WIDTH - sideW) / 2 - 100, 218, 120, 26,
            s_hwndContent, (HMENU)IDC_ABOUT_COPYQQ, hInst, NULL);
        SendMessageW(btnCopyQQ, WM_SETFONT, (WPARAM)s_swNormalFont, FALSE);
        HWND btnUpdate = CreateWindowExW(0, L"BUTTON", L"\u68C0\u67E5\u66F4\u65B0",
            WS_CHILD | WS_TABSTOP | BS_PUSHBUTTON,
            (SETTINGS_WIDTH - sideW) / 2 + 28, 218, 100, 26,
            s_hwndContent, (HMENU)IDC_ABOUT_UPDATE, hInst, NULL);
        SendMessageW(btnUpdate, WM_SETFONT, (WPARAM)s_swNormalFont, FALSE);
        s_hwndAboutUpdateLbl = CreateWindowExW(0, L"STATIC", NULL,
            WS_CHILD | SS_CENTER,
            0, 252, SETTINGS_WIDTH - sideW, 20,
            s_hwndContent, (HMENU)IDC_ABOUT_UPDATELBL, hInst, NULL);
        SendMessageW(s_hwndAboutUpdateLbl, WM_SETFONT, (WPARAM)s_swNormalFont, FALSE);

        switch_content_tab(g_app.settingsTab);
        if (g_app.settingsTab != SETTINGS_TAB_ABOUT) {
            ShowWindow(btnCopyQQ, SW_HIDE);
            ShowWindow(btnUpdate, SW_HIDE);
            ShowWindow(s_hwndAboutUpdateLbl, SW_HIDE);
        }
        return 0;
    }

    case WM_MEASUREITEM: {
        MEASUREITEMSTRUCT *mi = (MEASUREITEMSTRUCT *)lParam;
        if (mi->CtlID == 1 && mi->itemID < (UINT)SB_ITEM_COUNT) {
            mi->itemHeight = (s_sbItems[mi->itemID].type == SB_GROUP) ? 26 : 30;
        }
        return TRUE;
    }

    case WM_DRAWITEM: {
        DRAWITEMSTRUCT *di = (DRAWITEMSTRUCT *)lParam;
        if (di->CtlID == 1) {
            draw_sidebar_item(di);
            return TRUE;
        }
        break;
    }

    case WM_COMMAND:
        /* “返回” button */
        if (LOWORD(wParam) == IDC_BACK_BTN) {
            settings_hide();
            return 0;
        }
        /* 内容区控件命令转发 */
        if (s_hwndContent && LOWORD(wParam) != 1)
            SendMessageW(s_hwndContent, WM_COMMAND, wParam, lParam);

        if (LOWORD(wParam) == 1 && HIWORD(wParam) == LBN_SELCHANGE) {
            int sel = (int)SendMessageW(s_hwndTabList, LB_GETCURSEL, 0, 0);
            /* Skip group headers */
            if (sel >= 0 && sel < SB_ITEM_COUNT && s_sbItems[sel].type == SB_GROUP) {
                int revert = sb_find_index_for_tab(s_prevValidTab);
                SendMessageW(s_hwndTabList, LB_SETCURSEL, revert, 0);
                break;
            }
            if (sel >= 0 && sel < SB_ITEM_COUNT && s_sbItems[sel].type == SB_TAB) {
                SettingsTab tab = s_sbItems[sel].tab;
                s_prevValidTab = tab;
                g_app.settingsTab = tab;
                switch_content_tab(tab);

                /* Update content title */
                if (s_hwndContentTitle)
                    SetWindowTextW(s_hwndContentTitle, s_sbItems[sel].text);

                /* 关于页按钮显隐 */
                HWND btnCQ = GetDlgItem(s_hwndContent, IDC_ABOUT_COPYQQ);
                HWND btnUp = GetDlgItem(s_hwndContent, IDC_ABOUT_UPDATE);
                HWND lblUp = GetDlgItem(s_hwndContent, IDC_ABOUT_UPDATELBL);
                BOOL isAbout = (tab == SETTINGS_TAB_ABOUT);
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
        int sideW = 190, titleH = 52, backH = 36;
        int contentW = rc.right - sideW;
        if (s_hwndTabList)
            MoveWindow(s_hwndTabList, 0, 0, sideW, rc.bottom - backH, TRUE);
        if (s_hwndBackBtn)
            MoveWindow(s_hwndBackBtn, 0, rc.bottom - backH, sideW, backH, TRUE);
        if (s_hwndContentTitle)
            MoveWindow(s_hwndContentTitle, sideW + 24, 8, contentW - 48, titleH - 8, TRUE);
        if (s_hwndContent)
            MoveWindow(s_hwndContent, sideW, titleH, contentW, rc.bottom - titleH, TRUE);
        return 0;
    }

    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);
        const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);
        RECT rc;
        GetClientRect(hwnd, &rc);
        /* Sidebar background */
        RECT sideRc = { 0, 0, 190, rc.bottom };
        HBRUSH sideBg = CreateSolidBrush(colors->surface);
        FillRect(hdc, &sideRc, sideBg);
        DeleteObject(sideBg);
        /* Content title area background */
        RECT titleRc = { 191, 0, rc.right, 52 };
        HBRUSH titleBg = CreateSolidBrush(colors->background);
        FillRect(hdc, &titleRc, titleBg);
        DeleteObject(titleBg);
        /* Separator line between sidebar and content */
        HPEN sep = CreatePen(PS_SOLID, 1, colors->border);
        HPEN oldPen = SelectObject(hdc, sep);
        MoveToEx(hdc, 190, 0, NULL);
        LineTo(hdc, 190, rc.bottom);
        /* Divider below content title */
        MoveToEx(hdc, 190, 52, NULL);
        LineTo(hdc, rc.right, 52);
        SelectObject(hdc, oldPen);
        DeleteObject(sep);
        EndPaint(hwnd, &ps);
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
        s_hwndMCPPanel       = NULL;
        s_hwndSkillsPanel    = NULL;
        s_hwndBackBtn        = NULL;
        s_hwndContentTitle   = NULL;
        s_hwndGenEdFontSld   = NULL;
        s_hwndGenEdFontLbl   = NULL;
    }
    g_app.settingsOpen = false;
}

bool settings_is_visible(void) {
    return s_hwnd && IsWindowVisible(s_hwnd);
}
