#include "status_bar.h"
#include "../app.h"
#include "../utils/theme.h"
#include "../utils/wstr.h"
#include "../terminal/terminal_mgr.h"
#include "../editor/editor_tabs.h"
#include "../provider/provider_service.h"
#include "../provider/provider.h"
#include "../services/usage_tracker.h"
#include "../settings/settings_window.h"
#include <stdio.h>
#include <string.h>
#include <windowsx.h>

#define STATUSBAR_CLASS L"ACodeStatusBar"

static HWND s_hwnd;
static HWND s_hwndTooltip;
static RECT s_usageRect;  /* tracked during paint for tooltip hit-test */
static bool s_tooltipVisible;

/* ---- Provider icon color inference (matches Mac ProviderIconInference) ---- */
static COLORREF infer_provider_color(const char *name, const char *apiBase, const char *tool) {
    /* Keyword -> color map, matching Mac's iconMap */
    struct { const char *keyword; COLORREF color; } map[] = {
        { "openai",      RGB(0,   166, 126) },
        { "anthropic",   RGB(212, 145, 93)  },
        { "claude",      RGB(212, 145, 93)  },
        { "google",      RGB(66,  133, 244) },
        { "gemini",      RGB(66,  133, 244) },
        { "deepseek",    RGB(30,  136, 229) },
        { "kimi",        RGB(99,  102, 241) },
        { "moonshot",    RGB(99,  102, 241) },
        { "meta",        RGB(0,   129, 251) },
        { "azure",       RGB(0,   120, 212) },
        { "aws",         RGB(255, 153, 0)   },
        { "cloudflare",  RGB(243, 128, 32)  },
        { "mistral",     RGB(255, 112, 0)   },
        { "openrouter",  RGB(99,  102, 241) },
        { "zhipu",       RGB(15,  98,  254) },
        { "alibaba",     RGB(255, 106, 0)   },
        { "tencent",     RGB(0,   164, 255) },
        { "baidu",       RGB(41,  50,  225) },
        { "cohere",      RGB(57,  89,  77)  },
        { "perplexity",  RGB(32,  128, 141) },
        { "huggingface", RGB(255, 210, 30)  },
        { NULL, 0 }
    };

    /* Search in name (case-insensitive) */
    char lowerName[256] = {0};
    for (int i = 0; name[i] && i < 255; i++)
        lowerName[i] = (name[i] >= 'A' && name[i] <= 'Z') ? name[i] + 32 : name[i];

    char lowerBase[512] = {0};
    for (int i = 0; apiBase[i] && i < 511; i++)
        lowerBase[i] = (apiBase[i] >= 'A' && apiBase[i] <= 'Z') ? apiBase[i] + 32 : apiBase[i];

    for (int i = 0; map[i].keyword; i++) {
        if (strstr(lowerName, map[i].keyword) || strstr(lowerBase, map[i].keyword))
            return map[i].color;
    }

    /* Fallback by tool */
    if (strcmp(tool, "claude_code") == 0) return RGB(212, 145, 93);
    if (strcmp(tool, "openai") == 0)      return RGB(0, 166, 126);
    if (strcmp(tool, "gemini") == 0)      return RGB(66, 133, 244);
    return RGB(128, 128, 128);
}

static LRESULT CALLBACK statusbar_wnd_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);

        const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);
        RECT rc;
        GetClientRect(hwnd, &rc);

        /* Background */
        HBRUSH bg = CreateSolidBrush(colors->surface);
        FillRect(hdc, &rc, bg);
        DeleteObject(bg);

        /* Top border */
        HPEN pen = CreatePen(PS_SOLID, 1, colors->border);
        HPEN oldPen = SelectObject(hdc, pen);
        MoveToEx(hdc, 0, 0, NULL);
        LineTo(hdc, rc.right, 0);
        SelectObject(hdc, oldPen);
        DeleteObject(pen);

        /* Font */
        HFONT font = CreateFontW(12, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
        HFONT oldFont = SelectObject(hdc, font);
        SetBkMode(hdc, TRANSPARENT);

        /* ---- Left: settings gear + terminal count ---- */
        /* Gear icon (matches Mac gearshape button) */
        HFONT gearFont = CreateFontW(14, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI Symbol");
        SelectObject(hdc, gearFont);
        SetTextColor(hdc, colors->textSecondary);
        RECT gearRect = { 6, 2, 22, rc.bottom };
        DrawTextW(hdc, L"\x2699", -1, &gearRect, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
        SelectObject(hdc, font);
        DeleteObject(gearFont);

        wchar_t leftText[64];
        _snwprintf(leftText, 64, L"  %d \u7EC8\u7AEF", terminal_mgr_count());
        SetTextColor(hdc, colors->textSecondary);
        RECT leftRect = { 24, 2, 120, rc.bottom };
        DrawTextW(hdc, leftText, -1, &leftRect, DT_LEFT | DT_VCENTER | DT_SINGLELINE);

        /* ---- Center: current file + line count (matches Mac) ---- */
        const wchar_t *currentFile = editor_tabs_current_file();
        if (currentFile) {
            const wchar_t *fileName = wcsrchr(currentFile, L'\\');
            if (fileName) fileName++; else fileName = currentFile;
            int lineCount = editor_tabs_get_line_count();
            wchar_t centerText[256];
            if (lineCount > 0) {
                _snwprintf(centerText, 256, L"%s%s  %d \u884C", fileName,
                           editor_tabs_is_modified() ? L" \u25CF" : L"",
                           lineCount);
            } else {
                _snwprintf(centerText, 256, L"%s%s", fileName,
                           editor_tabs_is_modified() ? L" \u25CF" : L"");
            }
            SetTextColor(hdc, colors->text);
            RECT centerRect = { rc.right / 2 - 200, 2, rc.right / 2 + 200, rc.bottom };
            DrawTextW(hdc, centerText, -1, &centerRect, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
        }

        /* ---- Right section: Provider indicators + Token usage ---- */
        int rx = rc.right - 8;  /* right cursor, draw right-to-left */

        /* Token usage: $cost  outK/inK */
        {
            UsageStats stats;
            usage_tracker_get(&stats);
            if (stats.requestCount > 0) {
                wchar_t usageBuf[128];
                wchar_t costBuf[32];
                if (stats.estimatedCost >= 1.0)
                    _snwprintf(costBuf, 32, L"$%.2f", stats.estimatedCost);
                else if (stats.estimatedCost >= 0.001)
                    _snwprintf(costBuf, 32, L"$%.3f", stats.estimatedCost);
                else
                    _snwprintf(costBuf, 32, L"$%.4f", stats.estimatedCost);

                /* Display: in:NNK out:NNK $cost */
                _snwprintf(usageBuf, 128, L"in:%.0fK out:%.0fK %s",
                    (double)stats.inputTokens / 1000.0,
                    (double)stats.outputTokens / 1000.0,
                    costBuf);

                SetTextColor(hdc, colors->textSecondary);
                SIZE sz;
                GetTextExtentPoint32W(hdc, usageBuf, (int)wcslen(usageBuf), &sz);
                rx -= sz.cx + 4;
                RECT ur = { rx, 2, rx + sz.cx + 4, rc.bottom };
                DrawTextW(hdc, usageBuf, -1, &ur, DT_LEFT | DT_VCENTER | DT_SINGLELINE);
                /* Save usage rect for tooltip hit-test */
                s_usageRect = ur;
                rx -= 10;
            }
        }

        /* Provider indicators: matches Mac ProviderIndicator design */
        {
            const char *toolIds[] = { "claude_code", "openai", "gemini" };

            for (int t = 0; t < 3; t++) {
                Provider p;
                if (!provider_service_get_active(toolIds[t], &p)) continue;
                if (!p.isActive) continue;

                /* Infer color dynamically from name/apiBase */
                COLORREF dotColor = infer_provider_color(p.name, p.apiBase, toolIds[t]);

                /* Build label: "Name · model" or just "Name" (matches Mac) */
                wchar_t wName[128], wModel[128];
                wstr_from_utf8(p.name, wName, 128);
                wstr_from_utf8(p.model, wModel, 128);

                wchar_t indBuf[256];
                if (wModel[0]) {
                    _snwprintf(indBuf, 256, L"%s \u00B7 %s", wName, wModel);
                } else {
                    _snwprintf(indBuf, 256, L"%s", wName);
                }

                /* Measure text with split styling */
                SIZE szName, szModel;
                GetTextExtentPoint32W(hdc, wName, (int)wcslen(wName), &szName);
                int totalTextW = szName.cx;
                bool hasModel = (wModel[0] != L'\0');
                if (hasModel) {
                    wchar_t sepModel[192];
                    _snwprintf(sepModel, 192, L" \u00B7 %s", wModel);
                    GetTextExtentPoint32W(hdc, sepModel, (int)wcslen(sepModel), &szModel);
                    totalTextW += szModel.cx;
                }

                int dotW = 6, gap = 4, padH = 6;
                int totalW = padH + dotW + gap + totalTextW + padH;
                rx -= totalW;

                /* Background pill */
                RECT pillRect = { rx, 4, rx + totalW, rc.bottom - 4 };
                HBRUSH pillBg = CreateSolidBrush(colors->surfaceAlt);
                HPEN pillPen = CreatePen(PS_SOLID, 1, colors->border);
                HPEN oldPen2 = SelectObject(hdc, pillPen);
                HBRUSH oldBr2 = SelectObject(hdc, pillBg);
                RoundRect(hdc, pillRect.left, pillRect.top, pillRect.right, pillRect.bottom, 8, 8);
                SelectObject(hdc, oldPen2);
                SelectObject(hdc, oldBr2);
                DeleteObject(pillPen);
                DeleteObject(pillBg);

                /* Colored circle dot */
                int dotX = rx + padH;
                int dotY = rc.bottom / 2 - 3;
                HBRUSH dotBrush = CreateSolidBrush(dotColor);
                HPEN dotPen = CreatePen(PS_SOLID, 1, dotColor);
                HPEN oldPen = SelectObject(hdc, dotPen);
                HBRUSH oldBrush = SelectObject(hdc, dotBrush);
                Ellipse(hdc, dotX, dotY, dotX + dotW, dotY + dotW);
                SelectObject(hdc, oldPen);
                SelectObject(hdc, oldBrush);
                DeleteObject(dotPen);
                DeleteObject(dotBrush);

                /* Provider name (primary color) */
                int textX = dotX + dotW + gap;
                SetTextColor(hdc, colors->text);
                RECT nameRect = { textX, 2, textX + szName.cx, rc.bottom };
                DrawTextW(hdc, wName, -1, &nameRect, DT_LEFT | DT_VCENTER | DT_SINGLELINE);

                /* Model name (secondary color) */
                if (hasModel) {
                    wchar_t sepModel[192];
                    _snwprintf(sepModel, 192, L" \u00B7 %s", wModel);
                    SetTextColor(hdc, colors->textSecondary);
                    RECT modelRect = { textX + szName.cx, 2, textX + totalTextW, rc.bottom };
                    DrawTextW(hdc, sepModel, -1, &modelRect, DT_LEFT | DT_VCENTER | DT_SINGLELINE);
                }

                rx -= 6; /* gap between indicators */
            }
        }

        SelectObject(hdc, oldFont);
        DeleteObject(font);
        EndPaint(hwnd, &ps);
        return 0;
    }

    case WM_TIMER:
        InvalidateRect(hwnd, NULL, FALSE);
        return 0;

    case WM_LBUTTONDOWN: {
        int x = GET_X_LPARAM(lParam);
        /* Gear icon click area (left 22px) — toggle settings */
        if (x < 22) {
            if (settings_is_visible())
                settings_hide();
            else
                settings_show(g_app.hMainWnd);
            return 0;
        }
        break;
    }

    case WM_MOUSEMOVE: {
        /* Show detailed tooltip when hovering over usage area (matches Mac popover) */
        POINT pt = { GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam) };
        if (PtInRect(&s_usageRect, pt)) {
            if (!s_tooltipVisible && s_hwndTooltip) {
                UsageStats stats;
                usage_tracker_get(&stats);
                wchar_t tip[512];
                _snwprintf(tip, 512,
                    L"\u8F93\u5165 Tokens: %lld\n"
                    L"\u8F93\u51FA Tokens: %lld\n"
                    L"\u7F13\u5B58\u8BFB\u53D6: %lld\n"
                    L"\u8BF7\u6C42\u6B21\u6570: %d\n"
                    L"\u9884\u4F30\u8D39\u7528: $%.4f",
                    stats.inputTokens, stats.outputTokens,
                    stats.cacheReadTokens, stats.requestCount,
                    stats.estimatedCost);
                TOOLINFOW ti = { sizeof(TOOLINFOW) };
                ti.hwnd = hwnd;
                ti.uId = 1;
                ti.lpszText = tip;
                SendMessageW(s_hwndTooltip, TTM_UPDATETIPTEXTW, 0, (LPARAM)&ti);
                SendMessageW(s_hwndTooltip, TTM_TRACKACTIVATE, TRUE, (LPARAM)&ti);
                POINT screen = pt;
                ClientToScreen(hwnd, &screen);
                SendMessageW(s_hwndTooltip, TTM_TRACKPOSITION, 0, MAKELPARAM(screen.x, screen.y - 80));
                s_tooltipVisible = true;
            }
        } else {
            if (s_tooltipVisible && s_hwndTooltip) {
                TOOLINFOW ti = { sizeof(TOOLINFOW) };
                ti.hwnd = hwnd;
                ti.uId = 1;
                SendMessageW(s_hwndTooltip, TTM_TRACKACTIVATE, FALSE, (LPARAM)&ti);
                s_tooltipVisible = false;
            }
        }
        /* Request WM_MOUSELEAVE */
        TRACKMOUSEEVENT tme = { sizeof(tme), TME_LEAVE, hwnd, 0 };
        TrackMouseEvent(&tme);
        return 0;
    }

    case WM_MOUSELEAVE:
        if (s_tooltipVisible && s_hwndTooltip) {
            TOOLINFOW ti = { sizeof(TOOLINFOW) };
            ti.hwnd = hwnd;
            ti.uId = 1;
            SendMessageW(s_hwndTooltip, TTM_TRACKACTIVATE, FALSE, (LPARAM)&ti);
            s_tooltipVisible = false;
        }
        return 0;

    case WM_ERASEBKGND:
        return 1;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

HWND status_bar_create(HWND parent, HINSTANCE hInstance) {
    WNDCLASSEXW wc = {
        .cbSize = sizeof(WNDCLASSEXW),
        .lpfnWndProc = statusbar_wnd_proc,
        .hInstance = hInstance,
        .hbrBackground = NULL,
        .lpszClassName = STATUSBAR_CLASS,
        .hCursor = LoadCursor(NULL, IDC_ARROW),
    };
    RegisterClassExW(&wc);

    s_hwnd = CreateWindowExW(
        0, STATUSBAR_CLASS, NULL,
        WS_CHILD | WS_VISIBLE,
        0, 0, 100, 28,
        parent, (HMENU)IDC_STATUSBAR, hInstance, NULL
    );

    /* Create tooltip for token usage popover (matches Mac UsagePopoverView) */
    s_hwndTooltip = CreateWindowExW(WS_EX_TOPMOST, TOOLTIPS_CLASSW, NULL,
        WS_POPUP | TTS_NOPREFIX | TTS_ALWAYSTIP,
        CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT, CW_USEDEFAULT,
        s_hwnd, NULL, hInstance, NULL);
    if (s_hwndTooltip) {
        TOOLINFOW ti = { sizeof(TOOLINFOW) };
        ti.uFlags = TTF_TRACK | TTF_ABSOLUTE;
        ti.hwnd = s_hwnd;
        ti.uId = 1;
        ti.lpszText = L"";
        SendMessageW(s_hwndTooltip, TTM_ADDTOOLW, 0, (LPARAM)&ti);
        SendMessageW(s_hwndTooltip, TTM_SETMAXTIPWIDTH, 0, 300);
    }

    /* Repaint every second for live updates */
    SetTimer(s_hwnd, 1, 1000, NULL);

    return s_hwnd;
}

void status_bar_update(void) {
    if (s_hwnd) InvalidateRect(s_hwnd, NULL, FALSE);
}
