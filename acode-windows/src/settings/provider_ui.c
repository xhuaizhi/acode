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

    /* Rebuild ListBox */
    SendMessageW(pp->hwndList, LB_RESETCONTENT, 0, 0);
    for (int i = 0; i < pp->count; i++) {
        Provider *p = &pp->providers[i];
        wchar_t wName[256], wModel[256], label[512];
        wstr_from_utf8(p->name,  wName,  256);
        wstr_from_utf8(p->model, wModel, 256);
        _snwprintf(label, 512, L"%s%s  [%s]",
            p->isActive ? L"\u2713 " : L"  ",
            wName,
            wModel[0] ? wModel : L"默认模型");
        SendMessageW(pp->hwndList, LB_ADDSTRING, 0, (LPARAM)label);
    }

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
        HFONT font = CreateFontW(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");

        /* ListBox — fills most of the panel */
        pp->hwndList = CreateWindowExW(WS_EX_CLIENTEDGE, WC_LISTBOXW, NULL,
            WS_CHILD | WS_VISIBLE | LBS_NOTIFY | LBS_NOINTEGRALHEIGHT | WS_VSCROLL,
            8, 8, 400, 300, hwnd, (HMENU)IDC_PUI_LIST, hInst, NULL);
        SendMessageW(pp->hwndList, WM_SETFONT, (WPARAM)font, FALSE);
        SendMessageW(pp->hwndList, LB_SETITEMHEIGHT, 0, 32);

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
