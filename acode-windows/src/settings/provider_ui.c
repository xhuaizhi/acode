#include "provider_ui.h"
#include "provider_form.h"
#include "../provider/provider.h"
#include "../provider/provider_service.h"
#include "../provider/config_writer.h"
#include "../utils/wstr.h"
#include "../app.h"
#include "../terminal/terminal_mgr.h"
#include <commctrl.h>
#include <windowsx.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

/* ---------------------------------------------------------------
 * 每个 Provider Tab 的子窗口
 * 结构：列表区 + 操作按鈕区（添加/预设/编辑/删除/切换）
 * --------------------------------------------------------------- */

#define PROVIDER_UI_CLASS   L"ACodeProviderPanel"

/* Control IDs within each provider panel */
#define IDC_PUI_LIST        3001
#define IDC_PUI_BTN_ADD     3002
#define IDC_PUI_BTN_PRESET  3003
#define IDC_PUI_BTN_EDIT    3004
#define IDC_PUI_BTN_DELETE  3005
#define IDC_PUI_BTN_SWITCH  3006

typedef struct {
    char        tool[32];
    SettingsTab tab;
    Provider   *providers;      /* cached list, reloaded on refresh */
    int         count;
    HWND        hwndList;       /* ListBox */
    HWND        hwndBtnAdd;
    HWND        hwndBtnPreset;
    HWND        hwndBtnEdit;
    HWND        hwndBtnDelete;
    HWND        hwndBtnSwitch;
} ProviderPanel;

/* ---- Helper: parse "#RRGGBB" hex → COLORREF ---- */
static COLORREF parse_hex_color(const char *hex) {
    if (!hex || !hex[0]) return 0;
    const char *p = (hex[0] == '#') ? hex + 1 : hex;
    unsigned r = 0, g = 0, b = 0;
    if (sscanf(p, "%02x%02x%02x", &r, &g, &b) == 3)
        return RGB(r, g, b);
    return 0;
}

static COLORREF provider_icon_color(const Provider *p) {
    if (p->iconColor[0]) {
        COLORREF c = parse_hex_color(p->iconColor);
        if (c) return c;
    }
    if (strcmp(p->tool, "claude_code") == 0) return RGB(212, 145, 93);
    if (strcmp(p->tool, "openai") == 0)      return RGB(0, 166, 126);
    if (strcmp(p->tool, "gemini") == 0)      return RGB(66, 133, 244);
    return RGB(128, 128, 128);
}

static void mask_api_key(const char *key, wchar_t *out, int outLen) {
    int len = (int)strlen(key);
    if (len == 0) { out[0] = 0; return; }
    if (len <= 4) { wstr_from_utf8("****", out, outLen); return; }
    char masked[32];
    _snprintf(masked, 32, "***%s", key + len - 4);
    wstr_from_utf8(masked, out, outLen);
}

/* Cached fonts for provider list drawing (avoids GDI leak) */
static HFONT s_puiNameFont     = NULL;
static HFONT s_puiNameBoldFont = NULL;
static HFONT s_puiSmallFont    = NULL;

static void ensure_pui_fonts(void) {
    if (!s_puiNameFont)
        s_puiNameFont = CreateFontW(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    if (!s_puiNameBoldFont)
        s_puiNameBoldFont = CreateFontW(13, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    if (!s_puiSmallFont)
        s_puiSmallFont = CreateFontW(11, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
}

/* ---- Draw one provider row (clean native style) ---- */
static void draw_provider_card(DRAWITEMSTRUCT *di, ProviderPanel *pp) {
    const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);
    HDC hdc = di->hDC;
    RECT rc = di->rcItem;

    if (!pp || di->itemID >= (UINT)pp->count) {
        HBRUSH bg = CreateSolidBrush(colors->background);
        FillRect(hdc, &rc, bg);
        DeleteObject(bg);
        return;
    }

    ensure_pui_fonts();
    Provider *p = &pp->providers[di->itemID];
    bool selected = (di->itemState & ODS_SELECTED) != 0;

    /* Row background */
    COLORREF rowBg = selected
        ? (g_app.isDarkMode ? RGB(45, 45, 50) : RGB(230, 235, 242))
        : colors->background;
    HBRUSH bgBr = CreateSolidBrush(rowBg);
    FillRect(hdc, &rc, bgBr);
    DeleteObject(bgBr);

    /* Bottom separator line */
    HPEN sepPen = CreatePen(PS_SOLID, 1, colors->border);
    HPEN oldPen = SelectObject(hdc, sepPen);
    MoveToEx(hdc, rc.left + 8, rc.bottom - 1, NULL);
    LineTo(hdc, rc.right - 8, rc.bottom - 1);
    SelectObject(hdc, oldPen);
    DeleteObject(sepPen);

    SetBkMode(hdc, TRANSPARENT);
    int cy = (rc.top + rc.bottom) / 2;

    /* Radio-style indicator: checkmark circle or empty circle */
    int circX = rc.left + 14, circY = cy - 7, circR = 14;
    if (p->isActive) {
        COLORREF green = RGB(72, 187, 120);
        HBRUSH gBr = CreateSolidBrush(green);
        HPEN gPen = CreatePen(PS_SOLID, 1, green);
        SelectObject(hdc, gPen); SelectObject(hdc, gBr);
        Ellipse(hdc, circX, circY, circX + circR, circY + circR);
        /* Draw checkmark */
        SetTextColor(hdc, RGB(255, 255, 255));
        SelectObject(hdc, s_puiSmallFont);
        RECT chkR = { circX, circY, circX + circR, circY + circR };
        DrawTextW(hdc, L"\u2713", 1, &chkR, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
        SelectObject(hdc, oldPen);
        DeleteObject(gPen); DeleteObject(gBr);
    } else {
        HPEN oPen = CreatePen(PS_SOLID, 1, colors->textSecondary);
        HBRUSH oBr = CreateSolidBrush(colors->background);
        SelectObject(hdc, oPen); SelectObject(hdc, oBr);
        Ellipse(hdc, circX, circY, circX + circR, circY + circR);
        SelectObject(hdc, oldPen);
        DeleteObject(oPen); DeleteObject(oBr);
    }

    int textX = circX + circR + 10;

    /* Line 1: Name + [使用中] badge */
    HFONT oldFont = SelectObject(hdc, p->isActive ? s_puiNameBoldFont : s_puiNameFont);
    wchar_t wName[256];
    wstr_from_utf8(p->name, wName, 256);
    SetTextColor(hdc, colors->text);
    RECT nameR = { textX, rc.top + 8, rc.right - 80, rc.top + 24 };
    DrawTextW(hdc, wName, -1, &nameR, DT_LEFT | DT_SINGLELINE | DT_END_ELLIPSIS);

    if (p->isActive) {
        /* "使用中" badge */
        SIZE nameSize;
        GetTextExtentPoint32W(hdc, wName, (int)wcslen(wName), &nameSize);
        int badgeX = textX + nameSize.cx + 6;
        SelectObject(hdc, s_puiSmallFont);
        SetTextColor(hdc, RGB(72, 187, 120));
        RECT badgeR = { badgeX, rc.top + 9, badgeX + 50, rc.top + 23 };
        DrawTextW(hdc, L"\u4F7F\u7528\u4E2D", -1, &badgeR, DT_LEFT | DT_SINGLELINE);
    }

    /* Line 2: model · masked key */
    SelectObject(hdc, s_puiSmallFont);
    wchar_t wModel[256], wMasked[64], line2[512];
    wstr_from_utf8(p->model, wModel, 256);
    mask_api_key(p->apiKey, wMasked, 64);
    if (wModel[0])
        _snwprintf(line2, 512, L"%s  \u00B7  %s", wModel, wMasked);
    else
        _snwprintf(line2, 512, L"%s", wMasked);
    SetTextColor(hdc, colors->textSecondary);
    RECT l2R = { textX, rc.top + 26, rc.right - 12, rc.top + 40 };
    DrawTextW(hdc, line2, -1, &l2R, DT_LEFT | DT_SINGLELINE | DT_END_ELLIPSIS);

    SelectObject(hdc, oldFont);
}

static const char *tool_for_tab(SettingsTab tab) {
    switch (tab) {
    case SETTINGS_TAB_CLAUDE: return "claude_code";
    case SETTINGS_TAB_OPENAI: return "openai";
    case SETTINGS_TAB_GEMINI: return "gemini";
    default: return NULL;
    }
}

static void panel_refresh(ProviderPanel *pp) {
    if (pp->providers) {
        provider_free_list(pp->providers);
        pp->providers = NULL;
        pp->count = 0;
    }
    provider_list(pp->tool, &pp->providers, &pp->count);

    /* Rebuild ListBox (owner-drawn: add empty strings, draw in WM_DRAWITEM) */
    SendMessageW(pp->hwndList, LB_RESETCONTENT, 0, 0);
    for (int i = 0; i < pp->count; i++)
        SendMessageW(pp->hwndList, LB_ADDSTRING, 0, (LPARAM)L"");

    /* Update button states: edit/delete/switch require selection */
    int sel = (int)SendMessageW(pp->hwndList, LB_GETCURSEL, 0, 0);
    BOOL hasSelection = (sel >= 0 && sel < pp->count);
    BOOL isActive     = hasSelection && pp->providers[sel].isActive;
    EnableWindow(pp->hwndBtnEdit,   hasSelection);
    EnableWindow(pp->hwndBtnDelete, hasSelection);
    EnableWindow(pp->hwndBtnSwitch, hasSelection && !isActive);

    /* Regenerate terminal env after any provider change (matches Mac dynamic env merge) */
    wchar_t envBlock[8192] = {0};
    provider_service_generate_env(envBlock, 8192);
    terminal_mgr_set_env(envBlock);
}

static LRESULT CALLBACK provider_panel_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    ProviderPanel *pp = (ProviderPanel *)GetWindowLongPtrW(hwnd, GWLP_USERDATA);

    switch (msg) {

    case WM_CREATE: {
        CREATESTRUCTW *cs = (CREATESTRUCTW *)lParam;
        pp = (ProviderPanel *)cs->lpCreateParams;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)pp);

        HINSTANCE hInst = g_app.hInstance;

        /* Owner-drawn ListBox with card-like items (matches Mac ProviderCard) */
        pp->hwndList = CreateWindowExW(0, WC_LISTBOXW, NULL,
            WS_CHILD | WS_VISIBLE | LBS_OWNERDRAWFIXED | LBS_NOTIFY
            | LBS_NOINTEGRALHEIGHT | WS_VSCROLL,
            8, 8, 400, 300, hwnd, (HMENU)IDC_PUI_LIST, hInst, NULL);
        SendMessageW(pp->hwndList, LB_SETITEMHEIGHT, 0, 48);

        /* Button row */
        HFONT fontBtn = CreateFontW(13, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");

        pp->hwndBtnAdd    = CreateWindowExW(0, L"BUTTON", L"\u6DFB\u52A0",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
            8, 320, 72, 28, hwnd, (HMENU)IDC_PUI_BTN_ADD, hInst, NULL);
        pp->hwndBtnPreset = CreateWindowExW(0, L"BUTTON", L"\u9884\u8BBE",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
            88, 320, 72, 28, hwnd, (HMENU)IDC_PUI_BTN_PRESET, hInst, NULL);
        pp->hwndBtnEdit   = CreateWindowExW(0, L"BUTTON", L"\u7F16\u8F91",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
            168, 320, 72, 28, hwnd, (HMENU)IDC_PUI_BTN_EDIT, hInst, NULL);
        pp->hwndBtnSwitch = CreateWindowExW(0, L"BUTTON", L"\u5207\u6362",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
            248, 320, 72, 28, hwnd, (HMENU)IDC_PUI_BTN_SWITCH, hInst, NULL);
        pp->hwndBtnDelete = CreateWindowExW(0, L"BUTTON", L"\u5220\u9664",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
            336, 320, 72, 28, hwnd, (HMENU)IDC_PUI_BTN_DELETE, hInst, NULL);

        HWND btns[] = { pp->hwndBtnAdd, pp->hwndBtnPreset, pp->hwndBtnEdit,
                        pp->hwndBtnSwitch, pp->hwndBtnDelete };
        for (int i = 0; i < 5; i++)
            SendMessageW(btns[i], WM_SETFONT, (WPARAM)fontBtn, FALSE);

        panel_refresh(pp);
        return 0;
    }

    case WM_SIZE: {
        int w = LOWORD(lParam);
        int h = HIWORD(lParam);
        if (pp && pp->hwndList) {
            MoveWindow(pp->hwndList, 8, 8, w - 16, h - 48, TRUE);
            /* Reposition buttons */
            int bw = 76, bh = 28, by = h - 36, bx = 8;
            HWND btns[] = { pp->hwndBtnAdd, pp->hwndBtnPreset, pp->hwndBtnEdit,
                            pp->hwndBtnSwitch, pp->hwndBtnDelete };
            for (int i = 0; i < 5; i++) {
                MoveWindow(btns[i], bx, by, bw, bh, TRUE);
                bx += bw + 8;
            }
        }
        return 0;
    }

    case WM_MEASUREITEM: {
        MEASUREITEMSTRUCT *mi = (MEASUREITEMSTRUCT *)lParam;
        if (mi->CtlID == IDC_PUI_LIST)
            mi->itemHeight = 48;
        return TRUE;
    }

    case WM_DRAWITEM: {
        DRAWITEMSTRUCT *di = (DRAWITEMSTRUCT *)lParam;
        if (di->CtlID == IDC_PUI_LIST && pp) {
            draw_provider_card(di, pp);
            return TRUE;
        }
        break;
    }

    case WM_COMMAND:
        if (!pp) return 0;
        switch (LOWORD(wParam)) {

        case IDC_PUI_LIST:
            if (HIWORD(wParam) == LBN_SELCHANGE) {
                int sel = (int)SendMessageW(pp->hwndList, LB_GETCURSEL, 0, 0);
                BOOL hasSelection = (sel >= 0 && sel < pp->count);
                BOOL isActive     = hasSelection && pp->providers[sel].isActive;
                EnableWindow(pp->hwndBtnEdit,   hasSelection);
                EnableWindow(pp->hwndBtnDelete, hasSelection);
                EnableWindow(pp->hwndBtnSwitch, hasSelection && !isActive);
            }
            break;

        case IDC_PUI_BTN_ADD:
            if (provider_form_show(hwnd, pp->tool, NULL))
                panel_refresh(pp);
            break;

        case IDC_PUI_BTN_PRESET:
            if (provider_preset_show(hwnd, pp->tool))
                panel_refresh(pp);
            break;

        case IDC_PUI_BTN_EDIT: {
            int sel = (int)SendMessageW(pp->hwndList, LB_GETCURSEL, 0, 0);
            if (sel >= 0 && sel < pp->count) {
                if (provider_form_show(hwnd, pp->tool, &pp->providers[sel]))
                    panel_refresh(pp);
            }
            break;
        }

        case IDC_PUI_BTN_SWITCH: {
            int sel = (int)SendMessageW(pp->hwndList, LB_GETCURSEL, 0, 0);
            if (sel >= 0 && sel < pp->count) {
                Provider *p = &pp->providers[sel];
                if (provider_switch(p->id)) {
                    provider_service_write_config(p);
                    panel_refresh(pp);
                }
            }
            break;
        }

        case IDC_PUI_BTN_DELETE: {
            int sel = (int)SendMessageW(pp->hwndList, LB_GETCURSEL, 0, 0);
            if (sel < 0 || sel >= pp->count) break;

            wchar_t wName[256];
            wstr_from_utf8(pp->providers[sel].name, wName, 256);
            wchar_t msg[512];
            _snwprintf(msg, 512, L"\u786E\u5B9A\u8981\u5220\u9664\u4F9B\u5E94\u5546 \"%s\" \u5417\uFF1F\u6B64\u64CD\u4F5C\u4E0D\u53EF\u64A4\u9500\u3002", wName);
            int ret = MessageBoxW(hwnd, msg, L"\u786E\u8BA4\u5220\u9664",
                MB_YESNO | MB_ICONWARNING | MB_DEFBUTTON2);
            if (ret == IDYES) {
                provider_delete(pp->providers[sel].id);
                /* If deleted was active, auto-switch to first remaining */
                if (pp->providers[sel].isActive) {
                    Provider *remaining = NULL;
                    int rc = 0;
                    provider_list(pp->tool, &remaining, &rc);
                    if (rc > 0) {
                        provider_switch(remaining[0].id);
                        provider_service_write_config(&remaining[0]);
                    }
                    provider_free_list(remaining);
                }
                panel_refresh(pp);
            }
            break;
        }
        }
        return 0;

    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);
        RECT rc;
        GetClientRect(hwnd, &rc);
        const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);
        HBRUSH bg = CreateSolidBrush(colors->background);
        FillRect(hdc, &rc, bg);
        DeleteObject(bg);
        EndPaint(hwnd, &ps);
        return 0;
    }

    case WM_ERASEBKGND:
        return 1;

    case WM_DESTROY:
        if (pp) {
            provider_free_list(pp->providers);
            free(pp);
        }
        return 0;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

/* ---------------------------------------------------------------
 * Public API
 * --------------------------------------------------------------- */

HWND provider_ui_create(HWND parent, HINSTANCE hInst, SettingsTab tab, int x, int y, int w, int h) {
    const char *tool = tool_for_tab(tab);
    if (!tool) return NULL;

    static bool registered = false;
    if (!registered) {
        WNDCLASSEXW wc = {
            .cbSize        = sizeof(WNDCLASSEXW),
            .lpfnWndProc   = provider_panel_proc,
            .hInstance     = hInst,
            .hbrBackground = NULL,
            .lpszClassName = PROVIDER_UI_CLASS,
            .hCursor       = LoadCursor(NULL, IDC_ARROW),
        };
        RegisterClassExW(&wc);
        registered = true;
    }

    ProviderPanel *pp = (ProviderPanel *)calloc(1, sizeof(ProviderPanel));
    strncpy(pp->tool, tool, sizeof(pp->tool) - 1);
    pp->tab = tab;

    return CreateWindowExW(0, PROVIDER_UI_CLASS, NULL,
        WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN,
        x, y, w, h,
        parent, NULL, hInst, pp);
}

/* Legacy paint-only API — kept for backward compatibility, now a no-op stub */
void provider_ui_paint(HDC hdc, RECT *rc, const ThemeColors *colors, SettingsTab tab) {
    (void)hdc; (void)rc; (void)colors; (void)tab;
    /* Replaced by provider_ui_create window-based approach */
}
