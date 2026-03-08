#include "skills_ui.h"
#include "../services/skills.h"
#include "../app.h"
#include "../utils/theme.h"
#include "../utils/wstr.h"
#include <commctrl.h>
#include <stdio.h>
#include <string.h>
#include <windowsx.h>

/* ---------------------------------------------------------------
 * Skills Panel (skill list + action buttons + toggle checkboxes)
 * --------------------------------------------------------------- */
#define IDC_SK_LIST        8001
#define IDC_SK_ADD         8002
#define IDC_SK_EDIT        8003
#define IDC_SK_DELETE      8004
#define IDC_SK_REFRESH     8005
#define IDC_SK_CHK_CLAUDE  8010
#define IDC_SK_CHK_CODEX   8011
#define IDC_SK_CHK_GEMINI  8012

static HWND s_skPanel     = NULL;
static HWND s_skList      = NULL;
static HWND s_skBtnAdd    = NULL;
static HWND s_skBtnEdit   = NULL;
static HWND s_skBtnDel    = NULL;
static HWND s_skBtnRefresh= NULL;
static HWND s_skTitle     = NULL;
static HWND s_skCount     = NULL;
static HWND s_skChkClaude = NULL;
static HWND s_skChkCodex  = NULL;
static HWND s_skChkGemini = NULL;
static HWND s_skLblToggle = NULL;

static Skill s_skills[SKILL_MAX_COUNT];
static int s_skillCount = 0;

/* Cached GDI fonts for skill card drawing */
static HFONT s_skNameFont  = NULL;
static HFONT s_skSmallFont = NULL;
static HFONT s_skTinyFont  = NULL;

static void ensure_sk_fonts(void) {
    if (!s_skNameFont)
        s_skNameFont = CreateFontW(13, 0, 0, 0, FW_MEDIUM, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    if (!s_skSmallFont)
        s_skSmallFont = CreateFontW(11, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    if (!s_skTinyFont)
        s_skTinyFont = CreateFontW(9, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
}

static void skills_refresh_list(void);
static void skills_update_toggles(void);

/* ---- Draw one skill card (matches Mac SkillCard) ---- */
static void draw_skill_card(DRAWITEMSTRUCT *di) {
    if (di->itemID >= (UINT)s_skillCount) {
        const ThemeColors *c = theme_get_colors(g_app.isDarkMode);
        HBRUSH bg = CreateSolidBrush(c->background);
        FillRect(di->hDC, &di->rcItem, bg);
        DeleteObject(bg);
        return;
    }
    Skill *sk = &s_skills[di->itemID];
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

    /* Purple circle */
    COLORREF purple = RGB(147, 51, 234);
    int dotX = card.left + 12, dotY = card.top + 10;
    HBRUSH dBr = CreateSolidBrush(purple);
    HPEN dPen = CreatePen(PS_SOLID, 1, purple);
    op = SelectObject(hdc, dPen); ob = SelectObject(hdc, dBr);
    Ellipse(hdc, dotX, dotY, dotX + 10, dotY + 10);
    SelectObject(hdc, op); SelectObject(hdc, ob);
    DeleteObject(dPen); DeleteObject(dBr);

    int textX = dotX + 18;

    /* Line 1: Skill name */
    ensure_sk_fonts();
    HFONT oldFont = SelectObject(hdc, s_skNameFont);
    wchar_t wName[128];
    MultiByteToWideChar(CP_UTF8, 0, sk->name, -1, wName, 128);
    SetTextColor(hdc, colors->text);
    RECT nameR = { textX, card.top + 6, card.right - 12, card.top + 22 };
    DrawTextW(hdc, wName, -1, &nameR, DT_LEFT | DT_SINGLELINE | DT_END_ELLIPSIS);

    /* Line 2: Description */
    SelectObject(hdc, s_skSmallFont);
    if (sk->description[0]) {
        wchar_t wDesc[256];
        MultiByteToWideChar(CP_UTF8, 0, sk->description, -1, wDesc, 256);
        SetTextColor(hdc, colors->textSecondary);
        RECT descR = { textX, card.top + 24, card.right - 12, card.top + 38 };
        DrawTextW(hdc, wDesc, -1, &descR, DT_LEFT | DT_SINGLELINE | DT_END_ELLIPSIS);
    }

    /* Line 3: App badges */
    SelectObject(hdc, s_skTinyFont);
    struct { bool enabled; const wchar_t *label; COLORREF color; } apps[] = {
        { sk->enabledClaude, L"Claude",  RGB(212,145,93) },
        { sk->enabledCodex,  L"Codex",   RGB(0,166,126) },
        { sk->enabledGemini, L"Gemini",  RGB(66,133,244) },
    };
    int sx = textX;
    for (int j = 0; j < 3; j++) {
        SIZE sz;
        GetTextExtentPoint32W(hdc, apps[j].label, (int)wcslen(apps[j].label), &sz);
        RECT ab = { sx, card.top + 42, sx + sz.cx + 8, card.top + 54 };
        COLORREF aBg = apps[j].enabled
            ? (g_app.isDarkMode ? RGB(GetRValue(apps[j].color)/4, GetGValue(apps[j].color)/4, GetBValue(apps[j].color)/4)
               : RGB(230 + (GetRValue(apps[j].color)-230)/6, 230 + (GetGValue(apps[j].color)-230)/6, 230 + (GetBValue(apps[j].color)-230)/6))
            : (g_app.isDarkMode ? RGB(45,45,50) : RGB(235,235,240));
        HBRUSH aBr = CreateSolidBrush(aBg);
        HPEN aPen = CreatePen(PS_SOLID, 1, aBg);
        op = SelectObject(hdc, aPen); ob = SelectObject(hdc, aBr);
        RoundRect(hdc, ab.left, ab.top, ab.right, ab.bottom, 4, 4);
        SelectObject(hdc, op); SelectObject(hdc, ob);
        DeleteObject(aPen); DeleteObject(aBr);
        SetTextColor(hdc, apps[j].enabled ? apps[j].color : colors->textSecondary);
        RECT at = { ab.left + 4, ab.top, ab.right - 4, ab.bottom };
        DrawTextW(hdc, apps[j].label, -1, &at, DT_LEFT | DT_VCENTER | DT_SINGLELINE);
        sx = ab.right + 4;
    }

    SelectObject(hdc, oldFont);
}

static void skills_refresh_list(void) {
    s_skillCount = skills_list(s_skills, SKILL_MAX_COUNT);
    if (!s_skList) return;

    /* Owner-drawn: add empty strings */
    SendMessageW(s_skList, LB_RESETCONTENT, 0, 0);
    for (int i = 0; i < s_skillCount; i++)
        SendMessageW(s_skList, LB_ADDSTRING, 0, (LPARAM)L"");

    if (s_skCount) {
        wchar_t countBuf[32];
        _snwprintf(countBuf, 32, L"%d \x4E2A\x6280\x80FD", s_skillCount);
        SetWindowTextW(s_skCount, countBuf);
    }

    skills_update_toggles();
}

static void skills_update_toggles(void) {
    int sel = s_skList ? (int)SendMessageW(s_skList, LB_GETCURSEL, 0, 0) : -1;
    BOOL hasSelection = (sel >= 0 && sel < s_skillCount);

    EnableWindow(s_skChkClaude, hasSelection);
    EnableWindow(s_skChkCodex, hasSelection);
    EnableWindow(s_skChkGemini, hasSelection);
    EnableWindow(s_skBtnEdit, hasSelection);
    EnableWindow(s_skBtnDel, hasSelection);

    if (hasSelection) {
        SendMessageW(s_skChkClaude, BM_SETCHECK, s_skills[sel].enabledClaude ? BST_CHECKED : BST_UNCHECKED, 0);
        SendMessageW(s_skChkCodex, BM_SETCHECK, s_skills[sel].enabledCodex ? BST_CHECKED : BST_UNCHECKED, 0);
        SendMessageW(s_skChkGemini, BM_SETCHECK, s_skills[sel].enabledGemini ? BST_CHECKED : BST_UNCHECKED, 0);
    } else {
        SendMessageW(s_skChkClaude, BM_SETCHECK, BST_UNCHECKED, 0);
        SendMessageW(s_skChkCodex, BM_SETCHECK, BST_UNCHECKED, 0);
        SendMessageW(s_skChkGemini, BM_SETCHECK, BST_UNCHECKED, 0);
    }
}

static LRESULT CALLBACK skills_panel_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_COMMAND: {
        int id = LOWORD(wParam);
        int code = HIWORD(wParam);

        if (id == IDC_SK_ADD) {
            if (skills_form_show(hwnd, NULL))
                skills_refresh_list();
        }
        else if (id == IDC_SK_EDIT) {
            int sel = (int)SendMessageW(s_skList, LB_GETCURSEL, 0, 0);
            if (sel >= 0 && sel < s_skillCount) {
                if (skills_form_show(hwnd, s_skills[sel].id))
                    skills_refresh_list();
            }
        }
        else if (id == IDC_SK_DELETE) {
            int sel = (int)SendMessageW(s_skList, LB_GETCURSEL, 0, 0);
            if (sel >= 0 && sel < s_skillCount) {
                wchar_t wName[128];
                MultiByteToWideChar(CP_UTF8, 0, s_skills[sel].name, -1, wName, 128);
                wchar_t msg[256];
                _snwprintf(msg, 256, L"\x786E\x5B9A\x8981\x5220\x9664\x6280\x80FD \"%s\" \x5417\xFF1F", wName);
                if (MessageBoxW(hwnd, msg, L"\x786E\x8BA4\x5220\x9664", MB_YESNO | MB_ICONQUESTION) == IDYES) {
                    skills_delete(s_skills[sel].id);
                    skills_refresh_list();
                }
            }
        }
        else if (id == IDC_SK_REFRESH) {
            skills_refresh_list();
        }
        else if (id == IDC_SK_LIST && code == LBN_SELCHANGE) {
            skills_update_toggles();
        }
        else if (id == IDC_SK_LIST && code == LBN_DBLCLK) {
            int sel = (int)SendMessageW(s_skList, LB_GETCURSEL, 0, 0);
            if (sel >= 0 && sel < s_skillCount) {
                if (skills_form_show(hwnd, s_skills[sel].id))
                    skills_refresh_list();
            }
        }
        else if (id == IDC_SK_CHK_CLAUDE || id == IDC_SK_CHK_CODEX || id == IDC_SK_CHK_GEMINI) {
            int sel = (int)SendMessageW(s_skList, LB_GETCURSEL, 0, 0);
            if (sel >= 0 && sel < s_skillCount) {
                HWND chk = (id == IDC_SK_CHK_CLAUDE) ? s_skChkClaude :
                           (id == IDC_SK_CHK_CODEX) ? s_skChkCodex : s_skChkGemini;
                bool checked = (SendMessageW(chk, BM_GETCHECK, 0, 0) == BST_CHECKED);
                const char *app = (id == IDC_SK_CHK_CLAUDE) ? "claude" :
                                  (id == IDC_SK_CHK_CODEX) ? "codex" : "gemini";
                skills_toggle_app(s_skills[sel].id, app, checked);
                skills_refresh_list();
                /* Restore selection */
                SendMessageW(s_skList, LB_SETCURSEL, sel, 0);
                skills_update_toggles();
            }
        }
        return 0;
    }

    case WM_SIZE: {
        int w = LOWORD(lParam);
        int h = HIWORD(lParam);
        int btnH = 28;
        int toggleY = h - btnH - 8 - 30;
        int btnY = h - btnH - 8;
        int listY = 40;
        int listH = toggleY - listY - 8;

        if (s_skTitle)  MoveWindow(s_skTitle, 8, 8, 200, 24, TRUE);
        if (s_skCount)  MoveWindow(s_skCount, w - 120, 8, 112, 24, TRUE);
        if (s_skList)   MoveWindow(s_skList, 8, listY, w - 16, listH, TRUE);

        /* Toggle row */
        if (s_skLblToggle) MoveWindow(s_skLblToggle, 8, toggleY, 70, 22, TRUE);
        if (s_skChkClaude) MoveWindow(s_skChkClaude, 80, toggleY, 80, 22, TRUE);
        if (s_skChkCodex)  MoveWindow(s_skChkCodex, 168, toggleY, 80, 22, TRUE);
        if (s_skChkGemini) MoveWindow(s_skChkGemini, 256, toggleY, 80, 22, TRUE);

        /* Buttons */
        int btnX = 8;
        if (s_skBtnAdd)     { MoveWindow(s_skBtnAdd, btnX, btnY, 80, btnH, TRUE); btnX += 88; }
        if (s_skBtnEdit)    { MoveWindow(s_skBtnEdit, btnX, btnY, 60, btnH, TRUE); btnX += 68; }
        if (s_skBtnDel)     { MoveWindow(s_skBtnDel, btnX, btnY, 60, btnH, TRUE); }
        if (s_skBtnRefresh) MoveWindow(s_skBtnRefresh, w - 68, btnY, 60, btnH, TRUE);
        return 0;
    }

    case WM_MEASUREITEM: {
        MEASUREITEMSTRUCT *mi = (MEASUREITEMSTRUCT *)lParam;
        if (mi->CtlID == IDC_SK_LIST)
            mi->itemHeight = 60;
        return TRUE;
    }

    case WM_DRAWITEM: {
        DRAWITEMSTRUCT *di = (DRAWITEMSTRUCT *)lParam;
        if (di->CtlID == IDC_SK_LIST) {
            draw_skill_card(di);
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

HWND skills_ui_create(HWND parent, HINSTANCE hInst, int x, int y, int w, int h) {
    static bool s_registered = false;
    if (!s_registered) {
        WNDCLASSEXW wc = {
            .cbSize = sizeof(WNDCLASSEXW),
            .lpfnWndProc = skills_panel_proc,
            .hInstance = hInst,
            .hbrBackground = NULL,
            .lpszClassName = L"ACodeSkillsPanel",
            .hCursor = LoadCursor(NULL, IDC_ARROW),
        };
        RegisterClassExW(&wc);
        s_registered = true;
    }

    s_skPanel = CreateWindowExW(0, L"ACodeSkillsPanel", NULL,
        WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN,
        x, y, w, h, parent, NULL, hInst, NULL);

    HFONT font = CreateFontW(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    HFONT boldFont = CreateFontW(15, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
        DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");

    /* Title */
    s_skTitle = CreateWindowExW(0, L"STATIC", L"\x6280\x80FD\x7BA1\x7406",
        WS_CHILD | WS_VISIBLE | SS_LEFT,
        8, 8, 200, 24, s_skPanel, NULL, hInst, NULL);
    SendMessageW(s_skTitle, WM_SETFONT, (WPARAM)boldFont, FALSE);

    /* Count */
    s_skCount = CreateWindowExW(0, L"STATIC", L"",
        WS_CHILD | WS_VISIBLE | SS_RIGHT,
        w - 120, 8, 112, 24, s_skPanel, NULL, hInst, NULL);
    SendMessageW(s_skCount, WM_SETFONT, (WPARAM)font, FALSE);

    /* Owner-drawn ListBox (card-style items matching Mac SkillCard) */
    s_skList = CreateWindowExW(0, WC_LISTBOXW, NULL,
        WS_CHILD | WS_VISIBLE | WS_VSCROLL | LBS_OWNERDRAWFIXED | LBS_NOTIFY
        | LBS_NOINTEGRALHEIGHT,
        8, 40, w - 16, h - 120, s_skPanel, (HMENU)IDC_SK_LIST, hInst, NULL);
    SendMessageW(s_skList, LB_SETITEMHEIGHT, 0, 60);

    /* Toggle row */
    int toggleY = h - 66;
    s_skLblToggle = CreateWindowExW(0, L"STATIC", L"\x542F\x7528\x4E8E:",
        WS_CHILD | WS_VISIBLE | SS_LEFT,
        8, toggleY, 70, 22, s_skPanel, NULL, hInst, NULL);
    SendMessageW(s_skLblToggle, WM_SETFONT, (WPARAM)font, FALSE);

    s_skChkClaude = CreateWindowExW(0, L"BUTTON", L"Claude",
        WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX | WS_DISABLED,
        80, toggleY, 80, 22, s_skPanel, (HMENU)IDC_SK_CHK_CLAUDE, hInst, NULL);
    SendMessageW(s_skChkClaude, WM_SETFONT, (WPARAM)font, FALSE);

    s_skChkCodex = CreateWindowExW(0, L"BUTTON", L"Codex",
        WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX | WS_DISABLED,
        168, toggleY, 80, 22, s_skPanel, (HMENU)IDC_SK_CHK_CODEX, hInst, NULL);
    SendMessageW(s_skChkCodex, WM_SETFONT, (WPARAM)font, FALSE);

    s_skChkGemini = CreateWindowExW(0, L"BUTTON", L"Gemini",
        WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX | WS_DISABLED,
        256, toggleY, 80, 22, s_skPanel, (HMENU)IDC_SK_CHK_GEMINI, hInst, NULL);
    SendMessageW(s_skChkGemini, WM_SETFONT, (WPARAM)font, FALSE);

    /* Buttons */
    int btnY = h - 36;
    s_skBtnAdd = CreateWindowExW(0, L"BUTTON", L"\x6DFB\x52A0\x6280\x80FD",
        WS_CHILD | WS_VISIBLE | WS_TABSTOP,
        8, btnY, 80, 28, s_skPanel, (HMENU)IDC_SK_ADD, hInst, NULL);
    SendMessageW(s_skBtnAdd, WM_SETFONT, (WPARAM)font, FALSE);

    s_skBtnEdit = CreateWindowExW(0, L"BUTTON", L"\x7F16\x8F91",
        WS_CHILD | WS_VISIBLE | WS_TABSTOP | WS_DISABLED,
        96, btnY, 60, 28, s_skPanel, (HMENU)IDC_SK_EDIT, hInst, NULL);
    SendMessageW(s_skBtnEdit, WM_SETFONT, (WPARAM)font, FALSE);

    s_skBtnDel = CreateWindowExW(0, L"BUTTON", L"\x5220\x9664",
        WS_CHILD | WS_VISIBLE | WS_TABSTOP | WS_DISABLED,
        164, btnY, 60, 28, s_skPanel, (HMENU)IDC_SK_DELETE, hInst, NULL);
    SendMessageW(s_skBtnDel, WM_SETFONT, (WPARAM)font, FALSE);

    s_skBtnRefresh = CreateWindowExW(0, L"BUTTON", L"\x5237\x65B0",
        WS_CHILD | WS_VISIBLE | WS_TABSTOP,
        w - 68, btnY, 60, 28, s_skPanel, (HMENU)IDC_SK_REFRESH, hInst, NULL);
    SendMessageW(s_skBtnRefresh, WM_SETFONT, (WPARAM)font, FALSE);

    skills_refresh_list();
    return s_skPanel;
}

/* ---------------------------------------------------------------
 * Skills Add/Edit Form Dialog
 * --------------------------------------------------------------- */
#define IDC_SKF_NAME       9001
#define IDC_SKF_DESC       9002
#define IDC_SKF_CONTENT    9003
#define IDC_SKF_CLAUDE     9004
#define IDC_SKF_CODEX      9005
#define IDC_SKF_GEMINI     9006
#define IDC_SKF_OK         9007
#define IDC_SKF_CANCEL     9008

typedef struct {
    const char *existingId;
    BOOL saved;
} SkillFormCtx;

static INT_PTR CALLBACK skills_form_dlg_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    SkillFormCtx *ctx = (SkillFormCtx *)GetWindowLongPtrW(hwnd, GWLP_USERDATA);

    switch (msg) {
    case WM_INITDIALOG: {
        ctx = (SkillFormCtx *)lParam;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)ctx);

        HFONT font = CreateFontW(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
        HFONT boldFont = CreateFontW(15, 0, 0, 0, FW_BOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
        HFONT monoFont = CreateFontW(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, FIXED_PITCH, L"Consolas");
        HINSTANCE hInst = g_app.hInstance;
        bool isEdit = (ctx->existingId != NULL);

        /* Title */
        HWND lblTitle = CreateWindowExW(0, L"STATIC",
            isEdit ? L"\x7F16\x8F91\x6280\x80FD" : L"\x6DFB\x52A0\x6280\x80FD",
            WS_CHILD | WS_VISIBLE, 12, 8, 300, 22, hwnd, NULL, hInst, NULL);
        SendMessageW(lblTitle, WM_SETFONT, (WPARAM)boldFont, FALSE);

        /* Name */
        HWND lblName = CreateWindowExW(0, L"STATIC", L"\x540D\x79F0 *",
            WS_CHILD | WS_VISIBLE, 12, 38, 100, 18, hwnd, NULL, hInst, NULL);
        SendMessageW(lblName, WM_SETFONT, (WPARAM)font, FALSE);
        HWND edName = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", NULL,
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | ES_AUTOHSCROLL,
            12, 58, 360, 24, hwnd, (HMENU)IDC_SKF_NAME, hInst, NULL);
        SendMessageW(edName, WM_SETFONT, (WPARAM)font, FALSE);

        /* Description */
        HWND lblDesc = CreateWindowExW(0, L"STATIC", L"\x63CF\x8FF0",
            WS_CHILD | WS_VISIBLE, 12, 90, 100, 18, hwnd, NULL, hInst, NULL);
        SendMessageW(lblDesc, WM_SETFONT, (WPARAM)font, FALSE);
        HWND edDesc = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", NULL,
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | ES_AUTOHSCROLL,
            12, 110, 360, 24, hwnd, (HMENU)IDC_SKF_DESC, hInst, NULL);
        SendMessageW(edDesc, WM_SETFONT, (WPARAM)font, FALSE);

        /* Content */
        HWND lblContent = CreateWindowExW(0, L"STATIC", L"\x6307\x4EE4\x5185\x5BB9 *",
            WS_CHILD | WS_VISIBLE, 12, 142, 100, 18, hwnd, NULL, hInst, NULL);
        SendMessageW(lblContent, WM_SETFONT, (WPARAM)font, FALSE);
        HWND edContent = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", NULL,
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | WS_VSCROLL |
            ES_MULTILINE | ES_AUTOVSCROLL | ES_WANTRETURN,
            12, 162, 360, 120, hwnd, (HMENU)IDC_SKF_CONTENT, hInst, NULL);
        SendMessageW(edContent, WM_SETFONT, (WPARAM)monoFont, FALSE);

        /* App checkboxes */
        HWND lblApps = CreateWindowExW(0, L"STATIC", L"\x542F\x7528\x7684\x5DE5\x5177",
            WS_CHILD | WS_VISIBLE, 12, 292, 100, 18, hwnd, NULL, hInst, NULL);
        SendMessageW(lblApps, WM_SETFONT, (WPARAM)font, FALSE);

        HWND chkClaude = CreateWindowExW(0, L"BUTTON", L"Claude Code",
            WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
            12, 312, 110, 22, hwnd, (HMENU)IDC_SKF_CLAUDE, hInst, NULL);
        SendMessageW(chkClaude, WM_SETFONT, (WPARAM)font, FALSE);
        SendMessageW(chkClaude, BM_SETCHECK, BST_CHECKED, 0);

        HWND chkCodex = CreateWindowExW(0, L"BUTTON", L"Codex CLI",
            WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
            130, 312, 100, 22, hwnd, (HMENU)IDC_SKF_CODEX, hInst, NULL);
        SendMessageW(chkCodex, WM_SETFONT, (WPARAM)font, FALSE);
        SendMessageW(chkCodex, BM_SETCHECK, BST_CHECKED, 0);

        HWND chkGemini = CreateWindowExW(0, L"BUTTON", L"Gemini CLI",
            WS_CHILD | WS_VISIBLE | BS_AUTOCHECKBOX,
            238, 312, 100, 22, hwnd, (HMENU)IDC_SKF_GEMINI, hInst, NULL);
        SendMessageW(chkGemini, WM_SETFONT, (WPARAM)font, FALSE);
        SendMessageW(chkGemini, BM_SETCHECK, BST_CHECKED, 0);

        /* OK / Cancel */
        HWND btnOk = CreateWindowExW(0, L"BUTTON",
            isEdit ? L"\x4FDD\x5B58" : L"\x6DFB\x52A0",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_DEFPUSHBUTTON,
            200, 346, 80, 28, hwnd, (HMENU)IDC_SKF_OK, hInst, NULL);
        SendMessageW(btnOk, WM_SETFONT, (WPARAM)font, FALSE);

        HWND btnCancel = CreateWindowExW(0, L"BUTTON", L"\x53D6\x6D88",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP,
            288, 346, 80, 28, hwnd, (HMENU)IDC_SKF_CANCEL, hInst, NULL);
        SendMessageW(btnCancel, WM_SETFONT, (WPARAM)font, FALSE);

        /* Populate if editing */
        if (isEdit) {
            Skill all[SKILL_MAX_COUNT];
            int count = skills_list(all, SKILL_MAX_COUNT);
            for (int i = 0; i < count; i++) {
                if (strcmp(all[i].id, ctx->existingId) == 0) {
                    wchar_t wBuf[SKILL_MAX_CONTENT];
                    MultiByteToWideChar(CP_UTF8, 0, all[i].name, -1, wBuf, SKILL_MAX_NAME_LEN);
                    SetWindowTextW(edName, wBuf);
                    MultiByteToWideChar(CP_UTF8, 0, all[i].description, -1, wBuf, SKILL_MAX_DESC_LEN);
                    SetWindowTextW(edDesc, wBuf);
                    MultiByteToWideChar(CP_UTF8, 0, all[i].content, -1, wBuf, SKILL_MAX_CONTENT);
                    SetWindowTextW(edContent, wBuf);
                    SendMessageW(chkClaude, BM_SETCHECK, all[i].enabledClaude ? BST_CHECKED : BST_UNCHECKED, 0);
                    SendMessageW(chkCodex, BM_SETCHECK, all[i].enabledCodex ? BST_CHECKED : BST_UNCHECKED, 0);
                    SendMessageW(chkGemini, BM_SETCHECK, all[i].enabledGemini ? BST_CHECKED : BST_UNCHECKED, 0);
                    break;
                }
            }
        }

        return TRUE;
    }

    case WM_COMMAND: {
        int id = LOWORD(wParam);
        if (id == IDC_SKF_CANCEL) {
            EndDialog(hwnd, 0);
            return TRUE;
        }
        if (id == IDC_SKF_OK) {
            Skill skill;
            memset(&skill, 0, sizeof(skill));

            /* ID: use existing or generate new UUID-like string */
            if (ctx->existingId) {
                strncpy_s(skill.id, SKILL_MAX_ID_LEN, ctx->existingId, _TRUNCATE);
            } else {
                /* Simple unique ID using tick count */
                DWORD tick = GetTickCount();
                LARGE_INTEGER pc;
                QueryPerformanceCounter(&pc);
                _snprintf_s(skill.id, SKILL_MAX_ID_LEN, _TRUNCATE, "sk_%08x%08x",
                            tick, (unsigned int)(pc.QuadPart & 0xFFFFFFFF));
            }

            /* Name */
            wchar_t wBuf[SKILL_MAX_CONTENT];
            GetDlgItemTextW(hwnd, IDC_SKF_NAME, wBuf, SKILL_MAX_NAME_LEN);
            WideCharToMultiByte(CP_UTF8, 0, wBuf, -1, skill.name, SKILL_MAX_NAME_LEN, NULL, NULL);
            /* Trim */
            char *p = skill.name;
            while (*p == ' ') p++;
            if (p != skill.name) memmove(skill.name, p, strlen(p) + 1);
            int len = (int)strlen(skill.name);
            while (len > 0 && skill.name[len-1] == ' ') skill.name[--len] = '\0';

            if (!skill.name[0]) {
                MessageBoxW(hwnd, L"\x540D\x79F0\x4E0D\x80FD\x4E3A\x7A7A", L"\x9519\x8BEF", MB_OK | MB_ICONERROR);
                return TRUE;
            }

            /* Description */
            GetDlgItemTextW(hwnd, IDC_SKF_DESC, wBuf, SKILL_MAX_DESC_LEN);
            WideCharToMultiByte(CP_UTF8, 0, wBuf, -1, skill.description, SKILL_MAX_DESC_LEN, NULL, NULL);

            /* Content */
            GetDlgItemTextW(hwnd, IDC_SKF_CONTENT, wBuf, SKILL_MAX_CONTENT);
            WideCharToMultiByte(CP_UTF8, 0, wBuf, -1, skill.content, SKILL_MAX_CONTENT, NULL, NULL);
            if (!skill.content[0]) {
                MessageBoxW(hwnd, L"\x6307\x4EE4\x5185\x5BB9\x4E0D\x80FD\x4E3A\x7A7A", L"\x9519\x8BEF", MB_OK | MB_ICONERROR);
                return TRUE;
            }

            /* Enabled apps */
            skill.enabledClaude = (SendDlgItemMessageW(hwnd, IDC_SKF_CLAUDE, BM_GETCHECK, 0, 0) == BST_CHECKED);
            skill.enabledCodex  = (SendDlgItemMessageW(hwnd, IDC_SKF_CODEX, BM_GETCHECK, 0, 0) == BST_CHECKED);
            skill.enabledGemini = (SendDlgItemMessageW(hwnd, IDC_SKF_GEMINI, BM_GETCHECK, 0, 0) == BST_CHECKED);

            if (skills_save(&skill)) {
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

BOOL skills_form_show(HWND parent, const char *existingId) {
    DLGTEMPLATE dlg = {
        .style = DS_MODALFRAME | DS_CENTER | WS_POPUP | WS_CAPTION | WS_SYSMENU,
        .cx = 200, .cy = 200,
    };

    SkillFormCtx ctx = { .existingId = existingId, .saved = FALSE };
    DialogBoxIndirectParamW(g_app.hInstance, &dlg, parent, skills_form_dlg_proc, (LPARAM)&ctx);
    return ctx.saved;
}
