#include "mcp_ui.h"
#include "../services/mcp.h"
#include "../app.h"
#include "../utils/theme.h"
#include "../utils/wstr.h"
#include <commctrl.h>
#include <stdio.h>
#include <string.h>
#include <windowsx.h>

/* ---------------------------------------------------------------
 * MCP Panel (server list + action buttons)
 * --------------------------------------------------------------- */
#define IDC_MCP_LIST        5001
#define IDC_MCP_ADD         5002
#define IDC_MCP_PRESET      5003
#define IDC_MCP_EDIT        5004
#define IDC_MCP_DELETE      5005
#define IDC_MCP_REFRESH     5006

static HWND s_mcpPanel    = NULL;
static HWND s_mcpList     = NULL;
static HWND s_mcpBtnAdd   = NULL;
static HWND s_mcpBtnPreset= NULL;
static HWND s_mcpBtnEdit  = NULL;
static HWND s_mcpBtnDel   = NULL;
static HWND s_mcpBtnRefresh = NULL;
static HWND s_mcpTitle    = NULL;
static HWND s_mcpCount    = NULL;

static MCPServer s_servers[MCP_MAX_SERVERS];
static int s_serverCount = 0;

/* Cached GDI fonts for MCP card drawing */
static HFONT s_mcpNameFont  = NULL;
static HFONT s_mcpSmallFont = NULL;
static HFONT s_mcpSumFont   = NULL;
static HFONT s_mcpTinyFont  = NULL;

static void ensure_mcp_fonts(void) {
    if (!s_mcpNameFont)
        s_mcpNameFont = CreateFontW(13, 0, 0, 0, FW_MEDIUM, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    if (!s_mcpSmallFont)
        s_mcpSmallFont = CreateFontW(10, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    if (!s_mcpSumFont)
        s_mcpSumFont = CreateFontW(11, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    if (!s_mcpTinyFont)
        s_mcpTinyFont = CreateFontW(9, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
}

/* ---- Transport color (matches Mac MCPServerCard) ---- */
static COLORREF mcp_transport_color(MCPTransport t) {
    switch (t) {
    case MCP_TRANSPORT_STDIO: return RGB(59, 130, 246);   /* blue */
    case MCP_TRANSPORT_HTTP:  return RGB(34, 197, 94);    /* green */
    case MCP_TRANSPORT_SSE:   return RGB(249, 115, 22);   /* orange */
    default:                  return RGB(128, 128, 128);
    }
}

static const wchar_t *mcp_transport_label(MCPTransport t) {
    switch (t) {
    case MCP_TRANSPORT_STDIO: return L"STDIO";
    case MCP_TRANSPORT_HTTP:  return L"HTTP";
    case MCP_TRANSPORT_SSE:   return L"SSE";
    default:                  return L"?";
    }
}

/* ---- Draw one MCP server card ---- */
static void draw_mcp_card(DRAWITEMSTRUCT *di) {
    if (di->itemID >= (UINT)s_serverCount) {
        const ThemeColors *c = theme_get_colors(g_app.isDarkMode);
        HBRUSH bg = CreateSolidBrush(c->background);
        FillRect(di->hDC, &di->rcItem, bg);
        DeleteObject(bg);
        return;
    }
    MCPServer *s = &s_servers[di->itemID];
    const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);
    HDC hdc = di->hDC;
    RECT rc = di->rcItem;
    bool selected = (di->itemState & ODS_SELECTED) != 0;

    HBRUSH bgBr = CreateSolidBrush(colors->background);
    FillRect(hdc, &rc, bgBr);
    DeleteObject(bgBr);
    SetBkMode(hdc, TRANSPARENT);

    /* Card background */
    RECT card = { rc.left + 4, rc.top + 2, rc.right - 4, rc.bottom - 2 };
    COLORREF cardBg = selected
        ? (g_app.isDarkMode ? RGB(50,50,58) : RGB(225,232,240))
        : colors->surfaceAlt;
    HBRUSH cBr = CreateSolidBrush(cardBg);
    HPEN cPen = CreatePen(PS_SOLID, 1, selected ? colors->accent : colors->border);
    HPEN op = SelectObject(hdc, cPen);
    HBRUSH ob = SelectObject(hdc, cBr);
    RoundRect(hdc, card.left, card.top, card.right, card.bottom, 8, 8);
    SelectObject(hdc, op); SelectObject(hdc, ob);
    DeleteObject(cPen); DeleteObject(cBr);

    /* Colored transport circle */
    COLORREF dotClr = mcp_transport_color(s->transport);
    int dotX = card.left + 12, dotY = (card.top + card.bottom) / 2 - 5;
    HBRUSH dBr = CreateSolidBrush(dotClr);
    HPEN dPen = CreatePen(PS_SOLID, 1, dotClr);
    op = SelectObject(hdc, dPen); ob = SelectObject(hdc, dBr);
    Ellipse(hdc, dotX, dotY, dotX + 10, dotY + 10);
    SelectObject(hdc, op); SelectObject(hdc, ob);
    DeleteObject(dPen); DeleteObject(dBr);

    int textX = dotX + 18;

    /* Line 1: Server ID */
    ensure_mcp_fonts();
    HFONT oldFont = SelectObject(hdc, s_mcpNameFont);
    wchar_t wId[128];
    MultiByteToWideChar(CP_UTF8, 0, s->id, -1, wId, 128);
    SetTextColor(hdc, colors->text);
    RECT idR = { textX, card.top + 6, card.right - 12, card.top + 22 };
    DrawTextW(hdc, wId, -1, &idR, DT_LEFT | DT_SINGLELINE | DT_END_ELLIPSIS);

    /* Line 2: [TRANSPORT] badge + summary */
    SelectObject(hdc, s_mcpSmallFont);
    const wchar_t *tLabel = mcp_transport_label(s->transport);
    SIZE tsz;
    GetTextExtentPoint32W(hdc, tLabel, (int)wcslen(tLabel), &tsz);
    /* Badge background */
    RECT badge = { textX, card.top + 25, textX + tsz.cx + 8, card.top + 37 };
    COLORREF badgeBg = dotClr;
    /* Lighten for badge: mix with background */
    BYTE br = GetRValue(badgeBg), bg2 = GetGValue(badgeBg), bb = GetBValue(badgeBg);
    COLORREF badgeFill = g_app.isDarkMode
        ? RGB(br/4, bg2/4, bb/4)
        : RGB(220 + (br-220)/5, 220 + (bg2-220)/5, 220 + (bb-220)/5);
    HBRUSH badgeBr = CreateSolidBrush(badgeFill);
    HPEN badgePen = CreatePen(PS_SOLID, 1, badgeFill);
    op = SelectObject(hdc, badgePen); ob = SelectObject(hdc, badgeBr);
    RoundRect(hdc, badge.left, badge.top, badge.right, badge.bottom, 4, 4);
    SelectObject(hdc, op); SelectObject(hdc, ob);
    DeleteObject(badgePen); DeleteObject(badgeBr);
    SetTextColor(hdc, dotClr);
    RECT badgeText = { badge.left + 4, badge.top, badge.right - 4, badge.bottom };
    DrawTextW(hdc, tLabel, -1, &badgeText, DT_LEFT | DT_VCENTER | DT_SINGLELINE);

    /* Summary after badge */
    SelectObject(hdc, s_mcpSumFont);
    wchar_t wSum[256];
    MultiByteToWideChar(CP_UTF8, 0, s->summary, -1, wSum, 256);
    SetTextColor(hdc, colors->textSecondary);
    RECT sumR = { badge.right + 6, card.top + 24, card.right - 12, card.top + 38 };
    DrawTextW(hdc, wSum, -1, &sumR, DT_LEFT | DT_SINGLELINE | DT_END_ELLIPSIS);

    /* Line 3: source badges */
    if (s->sourceCount > 0) {
        SelectObject(hdc, s_mcpTinyFont);
        int sx = textX;
        for (int j = 0; j < s->sourceCount && j < 4; j++) {
            wchar_t ws[32];
            MultiByteToWideChar(CP_UTF8, 0, s->sources[j], -1, ws, 32);
            SIZE ssz;
            GetTextExtentPoint32W(hdc, ws, (int)wcslen(ws), &ssz);
            RECT sb = { sx, card.top + 42, sx + ssz.cx + 8, card.top + 54 };
            COLORREF sBg = g_app.isDarkMode ? RGB(50,50,55) : RGB(230,230,235);
            HBRUSH sBr = CreateSolidBrush(sBg);
            HPEN sPen = CreatePen(PS_SOLID, 1, sBg);
            op = SelectObject(hdc, sPen); ob = SelectObject(hdc, sBr);
            RoundRect(hdc, sb.left, sb.top, sb.right, sb.bottom, 4, 4);
            SelectObject(hdc, op); SelectObject(hdc, ob);
            DeleteObject(sPen); DeleteObject(sBr);
            SetTextColor(hdc, colors->textSecondary);
            RECT st = { sb.left + 4, sb.top, sb.right - 4, sb.bottom };
            DrawTextW(hdc, ws, -1, &st, DT_LEFT | DT_VCENTER | DT_SINGLELINE);
            sx = sb.right + 4;
        }
    }

    SelectObject(hdc, oldFont);
}

static void mcp_refresh_list(void) {
    s_serverCount = mcp_list_servers(s_servers, MCP_MAX_SERVERS);
    if (!s_mcpList) return;

    /* Owner-drawn: add empty strings, draw in WM_DRAWITEM */
    SendMessageW(s_mcpList, LB_RESETCONTENT, 0, 0);
    for (int i = 0; i < s_serverCount; i++)
        SendMessageW(s_mcpList, LB_ADDSTRING, 0, (LPARAM)L"");

    /* Update count label */
    if (s_mcpCount) {
        wchar_t countBuf[32];
        _snwprintf(countBuf, 32, L"%d \x4E2A\x670D\x52A1\x5668", s_serverCount);
        SetWindowTextW(s_mcpCount, countBuf);
    }
}

static LRESULT CALLBACK mcp_panel_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_COMMAND: {
        int id = LOWORD(wParam);
        int code = HIWORD(wParam);

        if (id == IDC_MCP_ADD) {
            if (mcp_form_show(hwnd, NULL))
                mcp_refresh_list();
        }
        else if (id == IDC_MCP_PRESET) {
            if (mcp_preset_show(hwnd))
                mcp_refresh_list();
        }
        else if (id == IDC_MCP_EDIT) {
            int sel = (int)SendMessageW(s_mcpList, LB_GETCURSEL, 0, 0);
            if (sel >= 0 && sel < s_serverCount) {
                if (mcp_form_show(hwnd, s_servers[sel].id))
                    mcp_refresh_list();
            }
        }
        else if (id == IDC_MCP_DELETE) {
            int sel = (int)SendMessageW(s_mcpList, LB_GETCURSEL, 0, 0);
            if (sel >= 0 && sel < s_serverCount) {
                wchar_t wId[128];
                MultiByteToWideChar(CP_UTF8, 0, s_servers[sel].id, -1, wId, 128);
                wchar_t msg[256];
                _snwprintf(msg, 256, L"\x786E\x5B9A\x8981\x5220\x9664 MCP \x670D\x52A1\x5668 \"%s\" \x5417\xFF1F", wId);
                if (MessageBoxW(hwnd, msg, L"\x786E\x8BA4\x5220\x9664", MB_YESNO | MB_ICONQUESTION) == IDYES) {
                    mcp_delete_server(s_servers[sel].id);
                    mcp_refresh_list();
                }
            }
        }
        else if (id == IDC_MCP_REFRESH) {
            mcp_refresh_list();
        }
        else if (id == IDC_MCP_LIST && code == LBN_DBLCLK) {
            int sel = (int)SendMessageW(s_mcpList, LB_GETCURSEL, 0, 0);
            if (sel >= 0 && sel < s_serverCount) {
                if (mcp_form_show(hwnd, s_servers[sel].id))
                    mcp_refresh_list();
            }
        }
        return 0;
    }

    case WM_SIZE: {
        int w = LOWORD(lParam);
        int h = HIWORD(lParam);
        int btnH = 28;
        int btnY = h - btnH - 8;
        int listY = 40;
        int listH = btnY - listY - 8;

        if (s_mcpTitle)  MoveWindow(s_mcpTitle, 8, 8, 200, 24, TRUE);
        if (s_mcpCount)  MoveWindow(s_mcpCount, w - 120, 8, 112, 24, TRUE);
        if (s_mcpList)   MoveWindow(s_mcpList, 8, listY, w - 16, listH, TRUE);

        int btnX = 8;
        if (s_mcpBtnAdd)    { MoveWindow(s_mcpBtnAdd, btnX, btnY, 100, btnH, TRUE); btnX += 108; }
        if (s_mcpBtnPreset) { MoveWindow(s_mcpBtnPreset, btnX, btnY, 100, btnH, TRUE); btnX += 108; }
        if (s_mcpBtnEdit)   { MoveWindow(s_mcpBtnEdit, btnX, btnY, 60, btnH, TRUE); btnX += 68; }
        if (s_mcpBtnDel)    { MoveWindow(s_mcpBtnDel, btnX, btnY, 60, btnH, TRUE); }
        if (s_mcpBtnRefresh) MoveWindow(s_mcpBtnRefresh, w - 68, btnY, 60, btnH, TRUE);
        return 0;
    }

    case WM_MEASUREITEM: {
        MEASUREITEMSTRUCT *mi = (MEASUREITEMSTRUCT *)lParam;
        if (mi->CtlID == IDC_MCP_LIST)
            mi->itemHeight = 60;
        return TRUE;
    }

    case WM_DRAWITEM: {
        DRAWITEMSTRUCT *di = (DRAWITEMSTRUCT *)lParam;
        if (di->CtlID == IDC_MCP_LIST) {
            draw_mcp_card(di);
            return TRUE;
        }
        break;
    }

    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);
        const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);
        RECT rc;
        GetClientRect(hwnd, &rc);
        HBRUSH bg = CreateSolidBrush(colors->background);
        FillRect(hdc, &rc, bg);
        DeleteObject(bg);
        EndPaint(hwnd, &ps);
        return 0;
    }

    case WM_ERASEBKGND:
        return 1;
    }
    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

HWND mcp_ui_create(HWND parent, HINSTANCE hInst, int x, int y, int w, int h) {
    static bool s_registered = false;
    if (!s_registered) {
        WNDCLASSEXW wc = {
            .cbSize = sizeof(WNDCLASSEXW),
            .lpfnWndProc = mcp_panel_proc,
            .hInstance = hInst,
            .hbrBackground = NULL,
            .lpszClassName = L"ACodeMCPPanel",
            .hCursor = LoadCursor(NULL, IDC_ARROW),
        };
        RegisterClassExW(&wc);
        s_registered = true;
    }

    s_mcpPanel = CreateWindowExW(0, L"ACodeMCPPanel", NULL,
        WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN,
        x, y, w, h, parent, NULL, hInst, NULL);

    HFONT font = CreateFontW(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    HFONT boldFont = CreateFontW(15, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");

    /* Title */
    s_mcpTitle = CreateWindowExW(0, L"STATIC", L"MCP \x670D\x52A1\x5668\x7BA1\x7406",
        WS_CHILD | WS_VISIBLE | SS_LEFT,
        8, 8, 200, 24, s_mcpPanel, NULL, hInst, NULL);
    SendMessageW(s_mcpTitle, WM_SETFONT, (WPARAM)boldFont, FALSE);

    /* Count */
    s_mcpCount = CreateWindowExW(0, L"STATIC", L"",
        WS_CHILD | WS_VISIBLE | SS_RIGHT,
        w - 120, 8, 112, 24, s_mcpPanel, NULL, hInst, NULL);
    SendMessageW(s_mcpCount, WM_SETFONT, (WPARAM)font, FALSE);

    /* Owner-drawn ListBox (card-style items matching Mac MCPServerCard) */
    s_mcpList = CreateWindowExW(0, WC_LISTBOXW, NULL,
        WS_CHILD | WS_VISIBLE | WS_VSCROLL | LBS_OWNERDRAWFIXED | LBS_NOTIFY
        | LBS_NOINTEGRALHEIGHT,
        8, 40, w - 16, h - 88, s_mcpPanel, (HMENU)IDC_MCP_LIST, hInst, NULL);
    SendMessageW(s_mcpList, LB_SETITEMHEIGHT, 0, 60);

    /* Buttons */
    int btnY = h - 36;
    s_mcpBtnAdd = CreateWindowExW(0, L"BUTTON", L"\x6DFB\x52A0\x670D\x52A1\x5668",
        WS_CHILD | WS_VISIBLE | WS_TABSTOP,
        8, btnY, 100, 28, s_mcpPanel, (HMENU)IDC_MCP_ADD, hInst, NULL);
    SendMessageW(s_mcpBtnAdd, WM_SETFONT, (WPARAM)font, FALSE);

    s_mcpBtnPreset = CreateWindowExW(0, L"BUTTON", L"\x4ECE\x9884\x8BBE\x6DFB\x52A0",
        WS_CHILD | WS_VISIBLE | WS_TABSTOP,
        116, btnY, 100, 28, s_mcpPanel, (HMENU)IDC_MCP_PRESET, hInst, NULL);
    SendMessageW(s_mcpBtnPreset, WM_SETFONT, (WPARAM)font, FALSE);

    s_mcpBtnEdit = CreateWindowExW(0, L"BUTTON", L"\x7F16\x8F91",
        WS_CHILD | WS_VISIBLE | WS_TABSTOP,
        224, btnY, 60, 28, s_mcpPanel, (HMENU)IDC_MCP_EDIT, hInst, NULL);
    SendMessageW(s_mcpBtnEdit, WM_SETFONT, (WPARAM)font, FALSE);

    s_mcpBtnDel = CreateWindowExW(0, L"BUTTON", L"\x5220\x9664",
        WS_CHILD | WS_VISIBLE | WS_TABSTOP,
        292, btnY, 60, 28, s_mcpPanel, (HMENU)IDC_MCP_DELETE, hInst, NULL);
    SendMessageW(s_mcpBtnDel, WM_SETFONT, (WPARAM)font, FALSE);

    s_mcpBtnRefresh = CreateWindowExW(0, L"BUTTON", L"\x5237\x65B0",
        WS_CHILD | WS_VISIBLE | WS_TABSTOP,
        w - 68, btnY, 60, 28, s_mcpPanel, (HMENU)IDC_MCP_REFRESH, hInst, NULL);
    SendMessageW(s_mcpBtnRefresh, WM_SETFONT, (WPARAM)font, FALSE);

    mcp_refresh_list();
    return s_mcpPanel;
}

/* ---------------------------------------------------------------
 * MCP Add/Edit Form Dialog
 * --------------------------------------------------------------- */
#define IDC_FORM_ID        6001
#define IDC_FORM_STDIO     6002
#define IDC_FORM_HTTP      6003
#define IDC_FORM_SSE       6004
#define IDC_FORM_COMMAND   6005
#define IDC_FORM_ARGS      6006
#define IDC_FORM_URL       6007
#define IDC_FORM_OK        6008
#define IDC_FORM_CANCEL    6009

typedef struct {
    const char *existingId;
    BOOL saved;
} MCPFormCtx;

static HWND s_formId      = NULL;
static HWND s_formStdio   = NULL;
static HWND s_formHttp    = NULL;
static HWND s_formSse     = NULL;
static HWND s_formCommand = NULL;
static HWND s_formArgs    = NULL;
static HWND s_formUrl     = NULL;
static HWND s_formLblCmd  = NULL;
static HWND s_formLblArgs = NULL;
static HWND s_formLblUrl  = NULL;

static void form_update_transport_ui(void) {
    BOOL isStdio = (SendMessageW(s_formStdio, BM_GETCHECK, 0, 0) == BST_CHECKED);
    ShowWindow(s_formCommand, isStdio ? SW_SHOW : SW_HIDE);
    ShowWindow(s_formArgs,    isStdio ? SW_SHOW : SW_HIDE);
    ShowWindow(s_formLblCmd,  isStdio ? SW_SHOW : SW_HIDE);
    ShowWindow(s_formLblArgs, isStdio ? SW_SHOW : SW_HIDE);
    ShowWindow(s_formUrl,    isStdio ? SW_HIDE : SW_SHOW);
    ShowWindow(s_formLblUrl, isStdio ? SW_HIDE : SW_SHOW);
}

static INT_PTR CALLBACK mcp_form_dlg_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    MCPFormCtx *ctx = (MCPFormCtx *)GetWindowLongPtrW(hwnd, GWLP_USERDATA);

    switch (msg) {
    case WM_INITDIALOG: {
        ctx = (MCPFormCtx *)lParam;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)ctx);

        HFONT font = CreateFontW(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
        HFONT boldFont = CreateFontW(15, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
        HINSTANCE hInst = g_app.hInstance;

        bool isEdit = (ctx->existingId != NULL);

        /* Title */
        HWND lblTitle = CreateWindowExW(0, L"STATIC",
            isEdit ? L"\x7F16\x8F91 MCP \x670D\x52A1\x5668" : L"\x6DFB\x52A0 MCP \x670D\x52A1\x5668",
            WS_CHILD | WS_VISIBLE, 12, 8, 300, 22, hwnd, NULL, hInst, NULL);
        SendMessageW(lblTitle, WM_SETFONT, (WPARAM)boldFont, FALSE);

        /* ID */
        HWND lblId = CreateWindowExW(0, L"STATIC", L"\x670D\x52A1\x5668 ID *",
            WS_CHILD | WS_VISIBLE, 12, 40, 100, 18, hwnd, NULL, hInst, NULL);
        SendMessageW(lblId, WM_SETFONT, (WPARAM)font, FALSE);
        s_formId = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", NULL,
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | ES_AUTOHSCROLL,
            12, 60, 300, 24, hwnd, (HMENU)IDC_FORM_ID, hInst, NULL);
        SendMessageW(s_formId, WM_SETFONT, (WPARAM)font, FALSE);
        if (isEdit) EnableWindow(s_formId, FALSE);

        /* Transport radio buttons */
        HWND lblTransport = CreateWindowExW(0, L"STATIC", L"\x4F20\x8F93\x7C7B\x578B",
            WS_CHILD | WS_VISIBLE, 12, 96, 100, 18, hwnd, NULL, hInst, NULL);
        SendMessageW(lblTransport, WM_SETFONT, (WPARAM)font, FALSE);

        s_formStdio = CreateWindowExW(0, L"BUTTON", L"stdio",
            WS_CHILD | WS_VISIBLE | BS_AUTORADIOBUTTON | WS_GROUP,
            12, 116, 70, 22, hwnd, (HMENU)IDC_FORM_STDIO, hInst, NULL);
        SendMessageW(s_formStdio, WM_SETFONT, (WPARAM)font, FALSE);

        s_formHttp = CreateWindowExW(0, L"BUTTON", L"HTTP",
            WS_CHILD | WS_VISIBLE | BS_AUTORADIOBUTTON,
            90, 116, 70, 22, hwnd, (HMENU)IDC_FORM_HTTP, hInst, NULL);
        SendMessageW(s_formHttp, WM_SETFONT, (WPARAM)font, FALSE);

        s_formSse = CreateWindowExW(0, L"BUTTON", L"SSE",
            WS_CHILD | WS_VISIBLE | BS_AUTORADIOBUTTON,
            168, 116, 70, 22, hwnd, (HMENU)IDC_FORM_SSE, hInst, NULL);
        SendMessageW(s_formSse, WM_SETFONT, (WPARAM)font, FALSE);

        SendMessageW(s_formStdio, BM_SETCHECK, BST_CHECKED, 0);

        /* Command */
        s_formLblCmd = CreateWindowExW(0, L"STATIC", L"\x547D\x4EE4 *",
            WS_CHILD | WS_VISIBLE, 12, 150, 100, 18, hwnd, NULL, hInst, NULL);
        SendMessageW(s_formLblCmd, WM_SETFONT, (WPARAM)font, FALSE);
        s_formCommand = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", NULL,
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | ES_AUTOHSCROLL,
            12, 170, 300, 24, hwnd, (HMENU)IDC_FORM_COMMAND, hInst, NULL);
        SendMessageW(s_formCommand, WM_SETFONT, (WPARAM)font, FALSE);

        /* Args */
        s_formLblArgs = CreateWindowExW(0, L"STATIC", L"\x53C2\x6570\xFF08\x9017\x53F7\x5206\x9694\xFF09",
            WS_CHILD | WS_VISIBLE, 12, 202, 200, 18, hwnd, NULL, hInst, NULL);
        SendMessageW(s_formLblArgs, WM_SETFONT, (WPARAM)font, FALSE);
        s_formArgs = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", NULL,
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | ES_AUTOHSCROLL,
            12, 222, 300, 24, hwnd, (HMENU)IDC_FORM_ARGS, hInst, NULL);
        SendMessageW(s_formArgs, WM_SETFONT, (WPARAM)font, FALSE);

        /* URL */
        s_formLblUrl = CreateWindowExW(0, L"STATIC", L"URL *",
            WS_CHILD, 12, 150, 100, 18, hwnd, NULL, hInst, NULL);
        SendMessageW(s_formLblUrl, WM_SETFONT, (WPARAM)font, FALSE);
        s_formUrl = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", NULL,
            WS_CHILD | WS_TABSTOP | ES_AUTOHSCROLL,
            12, 170, 300, 24, hwnd, (HMENU)IDC_FORM_URL, hInst, NULL);
        SendMessageW(s_formUrl, WM_SETFONT, (WPARAM)font, FALSE);

        /* OK / Cancel */
        HWND btnOk = CreateWindowExW(0, L"BUTTON",
            isEdit ? L"\x4FDD\x5B58" : L"\x6DFB\x52A0",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_DEFPUSHBUTTON,
            148, 270, 80, 28, hwnd, (HMENU)IDC_FORM_OK, hInst, NULL);
        SendMessageW(btnOk, WM_SETFONT, (WPARAM)font, FALSE);

        HWND btnCancel = CreateWindowExW(0, L"BUTTON", L"\x53D6\x6D88",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP,
            236, 270, 80, 28, hwnd, (HMENU)IDC_FORM_CANCEL, hInst, NULL);
        SendMessageW(btnCancel, WM_SETFONT, (WPARAM)font, FALSE);

        /* Populate if editing */
        if (isEdit) {
            MCPServer servers[MCP_MAX_SERVERS];
            int count = mcp_list_servers(servers, MCP_MAX_SERVERS);
            for (int i = 0; i < count; i++) {
                if (strcmp(servers[i].id, ctx->existingId) == 0) {
                    wchar_t wBuf[512];
                    MultiByteToWideChar(CP_UTF8, 0, servers[i].id, -1, wBuf, 512);
                    SetWindowTextW(s_formId, wBuf);

                    SendMessageW(s_formStdio, BM_SETCHECK, BST_UNCHECKED, 0);
                    SendMessageW(s_formHttp, BM_SETCHECK, BST_UNCHECKED, 0);
                    SendMessageW(s_formSse, BM_SETCHECK, BST_UNCHECKED, 0);
                    switch (servers[i].transport) {
                        case MCP_TRANSPORT_HTTP: SendMessageW(s_formHttp, BM_SETCHECK, BST_CHECKED, 0); break;
                        case MCP_TRANSPORT_SSE:  SendMessageW(s_formSse, BM_SETCHECK, BST_CHECKED, 0); break;
                        default: SendMessageW(s_formStdio, BM_SETCHECK, BST_CHECKED, 0); break;
                    }

                    MultiByteToWideChar(CP_UTF8, 0, servers[i].command, -1, wBuf, 512);
                    SetWindowTextW(s_formCommand, wBuf);

                    /* Join args with comma */
                    wchar_t argsBuf[1024] = L"";
                    for (int j = 0; j < servers[i].argCount; j++) {
                        if (j > 0) wcscat_s(argsBuf, 1024, L", ");
                        wchar_t wa[256];
                        MultiByteToWideChar(CP_UTF8, 0, servers[i].args[j], -1, wa, 256);
                        wcscat_s(argsBuf, 1024, wa);
                    }
                    SetWindowTextW(s_formArgs, argsBuf);

                    MultiByteToWideChar(CP_UTF8, 0, servers[i].url, -1, wBuf, 512);
                    SetWindowTextW(s_formUrl, wBuf);
                    break;
                }
            }
        }

        form_update_transport_ui();
        return TRUE;
    }

    case WM_COMMAND: {
        int id = LOWORD(wParam);
        if (id == IDC_FORM_STDIO || id == IDC_FORM_HTTP || id == IDC_FORM_SSE) {
            form_update_transport_ui();
            return TRUE;
        }
        if (id == IDC_FORM_CANCEL) {
            EndDialog(hwnd, 0);
            return TRUE;
        }
        if (id == IDC_FORM_OK) {
            /* Collect data */
            MCPFormData data;
            memset(&data, 0, sizeof(data));

            wchar_t wBuf[1024];
            GetWindowTextW(s_formId, wBuf, 128);
            WideCharToMultiByte(CP_UTF8, 0, wBuf, -1, data.id, MCP_MAX_ID_LEN, NULL, NULL);

            /* Trim */
            char *p = data.id;
            while (*p == ' ') p++;
            if (p != data.id) memmove(data.id, p, strlen(p) + 1);
            int len = (int)strlen(data.id);
            while (len > 0 && data.id[len-1] == ' ') data.id[--len] = '\0';

            if (!data.id[0]) {
                MessageBoxW(hwnd, L"ID \x4E0D\x80FD\x4E3A\x7A7A", L"\x9519\x8BEF", MB_OK | MB_ICONERROR);
                return TRUE;
            }

            if (SendMessageW(s_formHttp, BM_GETCHECK, 0, 0) == BST_CHECKED)
                data.transport = MCP_TRANSPORT_HTTP;
            else if (SendMessageW(s_formSse, BM_GETCHECK, 0, 0) == BST_CHECKED)
                data.transport = MCP_TRANSPORT_SSE;
            else
                data.transport = MCP_TRANSPORT_STDIO;

            if (data.transport == MCP_TRANSPORT_STDIO) {
                GetWindowTextW(s_formCommand, wBuf, 512);
                WideCharToMultiByte(CP_UTF8, 0, wBuf, -1, data.command, MCP_MAX_CMD_LEN, NULL, NULL);
                if (!data.command[0]) {
                    MessageBoxW(hwnd, L"\x547D\x4EE4\x4E0D\x80FD\x4E3A\x7A7A", L"\x9519\x8BEF", MB_OK | MB_ICONERROR);
                    return TRUE;
                }

                GetWindowTextW(s_formArgs, wBuf, 1024);
                char argsBuf[2048];
                WideCharToMultiByte(CP_UTF8, 0, wBuf, -1, argsBuf, 2048, NULL, NULL);
                /* Split by comma */
                char *tok = strtok(argsBuf, ",");
                while (tok && data.argCount < MCP_MAX_ARGS) {
                    while (*tok == ' ') tok++;
                    int tl = (int)strlen(tok);
                    while (tl > 0 && tok[tl-1] == ' ') tok[--tl] = '\0';
                    if (tok[0]) {
                        strncpy_s(data.args[data.argCount], MCP_MAX_ARG_LEN, tok, _TRUNCATE);
                        data.argCount++;
                    }
                    tok = strtok(NULL, ",");
                }
            } else {
                GetWindowTextW(s_formUrl, wBuf, 1024);
                WideCharToMultiByte(CP_UTF8, 0, wBuf, -1, data.url, MCP_MAX_URL_LEN, NULL, NULL);
                if (!data.url[0]) {
                    MessageBoxW(hwnd, L"URL \x4E0D\x80FD\x4E3A\x7A7A", L"\x9519\x8BEF", MB_OK | MB_ICONERROR);
                    return TRUE;
                }
            }

            if (mcp_upsert_server(&data)) {
                ctx->saved = TRUE;
                EndDialog(hwnd, 1);
            } else {
                MessageBoxW(hwnd, L"\x4FDD\x5B58\x5931\x8D25", L"\x9519\x8BEF", MB_OK | MB_ICONERROR);
            }
            return TRUE;
        }
        break;
    }

    case WM_CLOSE:
        EndDialog(hwnd, 0);
        return TRUE;
    }
    return FALSE;
}

BOOL mcp_form_show(HWND parent, const char *existingId) {
    /* Create a dialog template in memory */
    DLGTEMPLATE dlg = {
        .style = DS_MODALFRAME | DS_CENTER | WS_POPUP | WS_CAPTION | WS_SYSMENU,
        .cx = 170, .cy = 160,
    };

    MCPFormCtx ctx = { .existingId = existingId, .saved = FALSE };
    DialogBoxIndirectParamW(g_app.hInstance, &dlg, parent, mcp_form_dlg_proc, (LPARAM)&ctx);
    return ctx.saved;
}

/* ---------------------------------------------------------------
 * MCP Preset Selection Dialog
 * --------------------------------------------------------------- */
#define IDC_PRESET_LIST    7001
#define IDC_PRESET_INSTALL 7002
#define IDC_PRESET_CLOSE   7003

typedef struct {
    BOOL installed;
} MCPPresetCtx;

static INT_PTR CALLBACK mcp_preset_dlg_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    MCPPresetCtx *ctx = (MCPPresetCtx *)GetWindowLongPtrW(hwnd, GWLP_USERDATA);

    switch (msg) {
    case WM_INITDIALOG: {
        ctx = (MCPPresetCtx *)lParam;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)ctx);

        HFONT font = CreateFontW(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
        HFONT boldFont = CreateFontW(15, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
        HINSTANCE hInst = g_app.hInstance;

        HWND lblTitle = CreateWindowExW(0, L"STATIC", L"\x4ECE\x9884\x8BBE\x6DFB\x52A0 MCP \x670D\x52A1\x5668",
            WS_CHILD | WS_VISIBLE, 12, 8, 300, 22, hwnd, NULL, hInst, NULL);
        SendMessageW(lblTitle, WM_SETFONT, (WPARAM)boldFont, FALSE);

        HWND list = CreateWindowExW(WS_EX_CLIENTEDGE, WC_LISTBOXW, NULL,
            WS_CHILD | WS_VISIBLE | WS_VSCROLL | LBS_NOTIFY | LBS_NOINTEGRALHEIGHT,
            12, 36, 310, 180, hwnd, (HMENU)IDC_PRESET_LIST, hInst, NULL);
        SendMessageW(list, WM_SETFONT, (WPARAM)font, TRUE);
        SendMessageW(list, LB_SETITEMHEIGHT, 0, 24);

        int presetCount;
        const MCPPreset *presets = mcp_get_presets(&presetCount);
        for (int i = 0; i < presetCount; i++) {
            wchar_t wName[128], wDesc[256], item[512];
            MultiByteToWideChar(CP_UTF8, 0, presets[i].name, -1, wName, 128);
            MultiByteToWideChar(CP_UTF8, 0, presets[i].description, -1, wDesc, 256);
            _snwprintf(item, 512, L"%s - %s", wName, wDesc);
            SendMessageW(list, LB_ADDSTRING, 0, (LPARAM)item);
        }

        HWND btnInstall = CreateWindowExW(0, L"BUTTON", L"\x5B89\x88C5",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_DEFPUSHBUTTON,
            148, 224, 80, 28, hwnd, (HMENU)IDC_PRESET_INSTALL, hInst, NULL);
        SendMessageW(btnInstall, WM_SETFONT, (WPARAM)font, FALSE);

        HWND btnClose = CreateWindowExW(0, L"BUTTON", L"\x5173\x95ED",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP,
            236, 224, 80, 28, hwnd, (HMENU)IDC_PRESET_CLOSE, hInst, NULL);
        SendMessageW(btnClose, WM_SETFONT, (WPARAM)font, FALSE);

        return TRUE;
    }

    case WM_COMMAND: {
        int id = LOWORD(wParam);
        if (id == IDC_PRESET_CLOSE) {
            EndDialog(hwnd, 0);
            return TRUE;
        }
        if (id == IDC_PRESET_INSTALL) {
            HWND list = GetDlgItem(hwnd, IDC_PRESET_LIST);
            int sel = (int)SendMessageW(list, LB_GETCURSEL, 0, 0);

            int presetCount;
            const MCPPreset *presets = mcp_get_presets(&presetCount);
            if (sel >= 0 && sel < presetCount) {
                MCPFormData data;
                memset(&data, 0, sizeof(data));
                strncpy_s(data.id, MCP_MAX_ID_LEN, presets[sel].id, _TRUNCATE);
                data.transport = MCP_TRANSPORT_STDIO;
                strncpy_s(data.command, MCP_MAX_CMD_LEN, presets[sel].command, _TRUNCATE);
                for (int i = 0; i < presets[sel].argCount && i < MCP_MAX_ARGS; i++)
                    strncpy_s(data.args[i], MCP_MAX_ARG_LEN, presets[sel].args[i], _TRUNCATE);
                data.argCount = presets[sel].argCount;

                if (mcp_upsert_server(&data)) {
                    ctx->installed = TRUE;
                    EndDialog(hwnd, 1);
                } else {
                    MessageBoxW(hwnd, L"\x5B89\x88C5\x5931\x8D25", L"\x9519\x8BEF", MB_OK | MB_ICONERROR);
                }
            }
            return TRUE;
        }
        break;
    }

    case WM_CLOSE:
        EndDialog(hwnd, 0);
        return TRUE;
    }
    return FALSE;
}

BOOL mcp_preset_show(HWND parent) {
    DLGTEMPLATE dlg = {
        .style = DS_MODALFRAME | DS_CENTER | WS_POPUP | WS_CAPTION | WS_SYSMENU,
        .cx = 170, .cy = 136,
    };

    MCPPresetCtx ctx = { .installed = FALSE };
    DialogBoxIndirectParamW(g_app.hInstance, &dlg, parent, mcp_preset_dlg_proc, (LPARAM)&ctx);
    return ctx.installed;
}
