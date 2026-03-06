#include "provider_form.h"
#include "../provider/provider.h"
#include "../provider/provider_service.h"
#include "../provider/config_writer.h"
#include "../utils/wstr.h"
#include "../app.h"
#include <commctrl.h>
#include <windowsx.h>
#include <stdio.h>
#include <string.h>

/* ---------------------------------------------------------------
 * Control IDs
 * --------------------------------------------------------------- */
#define IDC_LBL_NAME        1001
#define IDC_EDIT_NAME       1002
#define IDC_LBL_APIKEY      1003
#define IDC_EDIT_APIKEY     1004
#define IDC_LBL_APIBASE     1005
#define IDC_EDIT_APIBASE    1006
#define IDC_LBL_MODEL       1007
#define IDC_EDIT_MODEL      1008
#define IDC_LBL_HAIKU       1009
#define IDC_EDIT_HAIKU      1010
#define IDC_LBL_SONNET      1011
#define IDC_EDIT_SONNET     1012
#define IDC_LBL_OPUS        1013
#define IDC_EDIT_OPUS       1014
#define IDC_LBL_EXTRAENV    1015
#define IDC_EDIT_EXTRAENV   1016
#define IDC_LBL_NOTES       1017
#define IDC_EDIT_NOTES      1018
#define IDC_BTN_SAVE        1019
#define IDC_BTN_CANCEL      1020
#define IDC_LBL_ERROR       1021

/* Preset picker IDs */
#define IDC_LIST_PRESETS    2001
#define IDC_LBL_PK_APIKEY   2002
#define IDC_EDIT_PK_APIKEY  2003
#define IDC_BTN_PK_ADD      2004
#define IDC_BTN_PK_CANCEL   2005

/* ---------------------------------------------------------------
 * Form context passed via GWLP_USERDATA
 * --------------------------------------------------------------- */
typedef struct {
    char        tool[32];
    int         editingId;      /* 0 = new, >0 = edit existing */
    bool        isClaude;
    BOOL        saved;
} FormCtx;

/* ---------------------------------------------------------------
 * Helpers
 * --------------------------------------------------------------- */
static void set_edit_utf8(HWND hwnd, int ctrlId, const char *utf8) {
    wchar_t wbuf[2048];
    wstr_from_utf8(utf8, wbuf, 2048);
    SetDlgItemTextW(hwnd, ctrlId, wbuf);
}

static void get_edit_utf8(HWND hwnd, int ctrlId, char *buf, int bufLen) {
    wchar_t wbuf[2048];
    GetDlgItemTextW(hwnd, ctrlId, wbuf, 2048);
    wstr_to_utf8(wbuf, buf, bufLen);
    /* trim leading/trailing spaces */
    int len = (int)strlen(buf);
    while (len > 0 && buf[len-1] == ' ') buf[--len] = '\0';
    char *p = buf;
    while (*p == ' ') p++;
    if (p != buf) memmove(buf, p, strlen(p) + 1);
}

/* Create a label + edit pair at given y position, return next y */
static int add_label_edit(HWND hwnd, HINSTANCE hInst, HFONT font,
                           int lblId, const wchar_t *lblText,
                           int editId, bool isPassword, bool isMultiline,
                           int y, int editH)
{
    HWND lbl = CreateWindowExW(0, L"STATIC", lblText,
        WS_CHILD | WS_VISIBLE | SS_LEFT,
        16, y, 200, 18, hwnd, (HMENU)(UINT_PTR)lblId, hInst, NULL);
    SendMessageW(lbl, WM_SETFONT, (WPARAM)font, FALSE);

    DWORD editStyle = WS_CHILD | WS_VISIBLE | WS_BORDER | WS_TABSTOP | ES_AUTOHSCROLL;
    if (isPassword)   editStyle |= ES_PASSWORD;
    if (isMultiline)  editStyle |= ES_MULTILINE | ES_WANTRETURN | WS_VSCROLL;

    HWND edit = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", NULL,
        editStyle,
        16, y + 20, 452, editH, hwnd, (HMENU)(UINT_PTR)editId, hInst, NULL);
    SendMessageW(edit, WM_SETFONT, (WPARAM)font, FALSE);

    return y + 20 + editH + 10;
}

/* ---------------------------------------------------------------
 * Provider Form Dialog Procedure
 * --------------------------------------------------------------- */
static LRESULT CALLBACK form_wnd_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    FormCtx *ctx = (FormCtx *)GetWindowLongPtrW(hwnd, GWLP_USERDATA);

    switch (msg) {

    case WM_CREATE: {
        CREATESTRUCTW *cs = (CREATESTRUCTW *)lParam;
        ctx = (FormCtx *)cs->lpCreateParams;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)ctx);

        HINSTANCE hInst = g_app.hInstance;
        HFONT font = CreateFontW(14, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
        HFONT fontBold = CreateFontW(15, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");

        int y = 50; /* below title */

        y = add_label_edit(hwnd, hInst, font, IDC_LBL_NAME,   L"名称 *",          IDC_EDIT_NAME,    false, false, y, 24);
        y = add_label_edit(hwnd, hInst, font, IDC_LBL_APIKEY, L"API Key *",        IDC_EDIT_APIKEY,  true,  false, y, 24);
        y = add_label_edit(hwnd, hInst, font, IDC_LBL_APIBASE,L"API 端点（空=官方默认）", IDC_EDIT_APIBASE, false, false, y, 24);
        y = add_label_edit(hwnd, hInst, font, IDC_LBL_MODEL,  L"主模型（空=默认）",IDC_EDIT_MODEL,   false, false, y, 24);

        if (ctx->isClaude) {
            y = add_label_edit(hwnd, hInst, font, IDC_LBL_HAIKU,  L"Haiku 模型（空=默认）",  IDC_EDIT_HAIKU,  false, false, y, 24);
            y = add_label_edit(hwnd, hInst, font, IDC_LBL_SONNET, L"Sonnet 模型（空=默认）", IDC_EDIT_SONNET, false, false, y, 24);
            y = add_label_edit(hwnd, hInst, font, IDC_LBL_OPUS,   L"Opus 模型（空=默认）",   IDC_EDIT_OPUS,   false, false, y, 24);
        }

        y = add_label_edit(hwnd, hInst, font, IDC_LBL_EXTRAENV, L"额外环境变量 (JSON)", IDC_EDIT_EXTRAENV, false, true, y, 52);
        y = add_label_edit(hwnd, hInst, font, IDC_LBL_NOTES,    L"备注",               IDC_EDIT_NOTES,    false, false, y, 24);

        /* Error label */
        HWND errLbl = CreateWindowExW(0, L"STATIC", NULL,
            WS_CHILD | WS_VISIBLE | SS_LEFT,
            16, y, 452, 18, hwnd, (HMENU)IDC_LBL_ERROR, hInst, NULL);
        SendMessageW(errLbl, WM_SETFONT, (WPARAM)font, FALSE);

        y += 28;

        /* Buttons */
        HWND btnSave = CreateWindowExW(0, L"BUTTON",
            ctx->editingId > 0 ? L"保存" : L"添加",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_DEFPUSHBUTTON,
            252, y, 100, 28, hwnd, (HMENU)IDC_BTN_SAVE, hInst, NULL);
        SendMessageW(btnSave, WM_SETFONT, (WPARAM)fontBold, FALSE);

        HWND btnCancel = CreateWindowExW(0, L"BUTTON", L"取消",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
            368, y, 100, 28, hwnd, (HMENU)IDC_BTN_CANCEL, hInst, NULL);
        SendMessageW(btnCancel, WM_SETFONT, (WPARAM)font, FALSE);

        /* Default extraEnv placeholder */
        SetDlgItemTextW(hwnd, IDC_EDIT_EXTRAENV, L"{}");

        (void)fontBold;
        return 0;
    }

    case WM_COMMAND:
        switch (LOWORD(wParam)) {

        case IDC_BTN_SAVE: {
            char name[128] = {0}, apiKey[512] = {0}, apiBase[512] = {0};
            char model[128] = {0}, extraEnv[2048] = {0}, notes[512] = {0};
            char haiku[128] = {0}, sonnet[128] = {0}, opus[128] = {0};

            get_edit_utf8(hwnd, IDC_EDIT_NAME,    name,     sizeof(name));
            get_edit_utf8(hwnd, IDC_EDIT_APIKEY,  apiKey,   sizeof(apiKey));
            get_edit_utf8(hwnd, IDC_EDIT_APIBASE, apiBase,  sizeof(apiBase));
            get_edit_utf8(hwnd, IDC_EDIT_MODEL,   model,    sizeof(model));
            get_edit_utf8(hwnd, IDC_EDIT_EXTRAENV,extraEnv, sizeof(extraEnv));
            get_edit_utf8(hwnd, IDC_EDIT_NOTES,   notes,    sizeof(notes));

            if (!name[0] || !apiKey[0]) {
                SetDlgItemTextW(hwnd, IDC_LBL_ERROR, L"名称和 API Key 不能为空");
                HWND errCtrl = GetDlgItem(hwnd, IDC_LBL_ERROR);
                SetTextColor((HDC)NULL, RGB(200, 50, 50));
                InvalidateRect(errCtrl, NULL, TRUE);
                break;
            }

            /* Validate extraEnv JSON */
            if (!extraEnv[0]) strcpy(extraEnv, "{}");

            /* Build Claude multi-model extraEnv if needed */
            if (ctx->isClaude) {
                get_edit_utf8(hwnd, IDC_EDIT_HAIKU,  haiku,  sizeof(haiku));
                get_edit_utf8(hwnd, IDC_EDIT_SONNET, sonnet, sizeof(sonnet));
                get_edit_utf8(hwnd, IDC_EDIT_OPUS,   opus,   sizeof(opus));

                /* Inject multi-model keys into extraEnv JSON */
                /* Simple approach: rebuild JSON with existing + multi-model keys */
                char merged[2048];
                /* Strip trailing } and inject */
                strncpy(merged, extraEnv, sizeof(merged) - 1);
                int mlen = (int)strlen(merged);
                while (mlen > 0 && merged[mlen-1] != '}') mlen--;
                if (mlen > 0) merged[mlen-1] = '\0'; /* remove last } */

                /* Remove trailing comma/whitespace */
                int tlen = (int)strlen(merged);
                while (tlen > 0 && (merged[tlen-1] == ',' || merged[tlen-1] == ' ' || merged[tlen-1] == '\n'))
                    merged[--tlen] = '\0';

                /* Check if we need a comma separator */
                bool needComma = (tlen > 1); /* more than just '{' */

                char additions[1024] = "";
                if (haiku[0]) {
                    char tmp[256];
                    snprintf(tmp, sizeof(tmp), "%s\"ANTHROPIC_DEFAULT_HAIKU_MODEL\":\"%s\"",
                             needComma ? "," : "", haiku);
                    strncat(additions, tmp, sizeof(additions) - strlen(additions) - 1);
                    needComma = true;
                }
                if (sonnet[0]) {
                    char tmp[256];
                    snprintf(tmp, sizeof(tmp), "%s\"ANTHROPIC_DEFAULT_SONNET_MODEL\":\"%s\"",
                             needComma ? "," : "", sonnet);
                    strncat(additions, tmp, sizeof(additions) - strlen(additions) - 1);
                    needComma = true;
                }
                if (opus[0]) {
                    char tmp[256];
                    snprintf(tmp, sizeof(tmp), "%s\"ANTHROPIC_DEFAULT_OPUS_MODEL\":\"%s\"",
                             needComma ? "," : "", opus);
                    strncat(additions, tmp, sizeof(additions) - strlen(additions) - 1);
                }

                snprintf(extraEnv, sizeof(extraEnv), "%s%s}", merged, additions);
            }

            /* Build Provider struct */
            Provider p;
            memset(&p, 0, sizeof(Provider));
            strncpy(p.name,     name,     sizeof(p.name) - 1);
            strncpy(p.tool,     ctx->tool, sizeof(p.tool) - 1);
            strncpy(p.apiKey,   apiKey,   sizeof(p.apiKey) - 1);
            strncpy(p.apiBase,  apiBase,  sizeof(p.apiBase) - 1);
            strncpy(p.model,    model,    sizeof(p.model) - 1);
            strncpy(p.extraEnv, extraEnv, sizeof(p.extraEnv) - 1);
            strncpy(p.notes,    notes,    sizeof(p.notes) - 1);

            bool ok;
            if (ctx->editingId > 0) {
                p.id = ctx->editingId;
                ok = provider_update(&p);
            } else {
                p.sortOrder = 0;
                ok = provider_insert(&p);
                /* If first provider for this tool, auto-activate */
                if (ok) {
                    Provider *list = NULL;
                    int count = 0;
                    provider_list(ctx->tool, &list, &count);
                    if (count == 1) {
                        provider_switch(list[0].id);
                        provider_service_write_config(&list[0]);
                    }
                    provider_free_list(list);
                }
            }

            if (ok) {
                /* If editing the active provider, rewrite config */
                if (ctx->editingId > 0) {
                    p.id = ctx->editingId;
                    provider_service_write_config(&p);
                }
                ctx->saved = TRUE;
                DestroyWindow(hwnd);
            } else {
                SetDlgItemTextW(hwnd, IDC_LBL_ERROR, L"保存失败，请检查数据后重试");
            }
            break;
        }

        case IDC_BTN_CANCEL:
            DestroyWindow(hwnd);
            break;
        }
        return 0;

    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);
        RECT rc;
        GetClientRect(hwnd, &rc);

        /* Background */
        HBRUSH bg = CreateSolidBrush(g_app.isDarkMode ? RGB(30, 30, 30) : RGB(245, 245, 245));
        FillRect(hdc, &rc, bg);
        DeleteObject(bg);

        /* Title */
        HFONT titleFont = CreateFontW(16, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
        SelectObject(hdc, titleFont);
        SetBkMode(hdc, TRANSPARENT);
        SetTextColor(hdc, g_app.isDarkMode ? RGB(240, 240, 240) : RGB(20, 20, 20));

        RECT titleRect = { 16, 12, rc.right - 16, 40 };
        wchar_t titleBuf[128];
        wchar_t toolW[64];
        wstr_from_utf8(ctx->tool, toolW, 64);
        _snwprintf(titleBuf, 128, ctx->editingId > 0 ? L"编辑供应商" : L"添加供应商");
        DrawTextW(hdc, titleBuf, -1, &titleRect, DT_LEFT | DT_SINGLELINE);
        DeleteObject(titleFont);

        /* Error label color */
        HWND errCtrl = GetDlgItem(hwnd, IDC_LBL_ERROR);
        if (errCtrl) {
            SetTextColor(hdc, RGB(200, 50, 50));
        }

        EndPaint(hwnd, &ps);
        return 0;
    }

    case WM_CTLCOLORSTATIC: {
        HDC hdcStatic = (HDC)wParam;
        HWND ctrl = (HWND)lParam;
        int id = GetDlgCtrlID(ctrl);
        SetBkMode(hdcStatic, TRANSPARENT);
        if (id == IDC_LBL_ERROR) {
            SetTextColor(hdcStatic, RGB(200, 50, 50));
        } else {
            SetTextColor(hdcStatic, g_app.isDarkMode ? RGB(200, 200, 200) : RGB(60, 60, 60));
        }
        return (LRESULT)GetStockObject(NULL_BRUSH);
    }

    case WM_CTLCOLOREDIT: {
        HDC hdcEdit = (HDC)wParam;
        SetBkColor(hdcEdit, g_app.isDarkMode ? RGB(45, 45, 45) : RGB(255, 255, 255));
        SetTextColor(hdcEdit, g_app.isDarkMode ? RGB(220, 220, 220) : RGB(20, 20, 20));
        static HBRUSH s_editBg = NULL;
        if (!s_editBg) s_editBg = CreateSolidBrush(RGB(45, 45, 45));
        return g_app.isDarkMode ? (LRESULT)s_editBg : (LRESULT)GetStockObject(WHITE_BRUSH);
    }

    case WM_ERASEBKGND:
        return 1;

    case WM_KEYDOWN:
        if (wParam == VK_ESCAPE) { DestroyWindow(hwnd); return 0; }
        break;

    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

/* ---------------------------------------------------------------
 * Public API: show provider add/edit form
 * --------------------------------------------------------------- */
BOOL provider_form_show(HWND parent, const char *tool, const Provider *existing) {
    FormCtx ctx;
    memset(&ctx, 0, sizeof(ctx));
    strncpy(ctx.tool, tool, sizeof(ctx.tool) - 1);
    ctx.isClaude   = (strcmp(tool, "claude_code") == 0);
    ctx.editingId  = existing ? existing->id : 0;
    ctx.saved      = FALSE;

    /* Calculate window height based on field count */
    int baseH = 50 + 5 * (24 + 30) + 52 + 30 + 24 + 30 + 28 + 50;
    if (ctx.isClaude) baseH += 3 * (24 + 30);
    int winH = baseH < 400 ? 400 : baseH;

    static const wchar_t *CLASS = L"ACodeProviderForm";
    WNDCLASSEXW wc = {
        .cbSize        = sizeof(WNDCLASSEXW),
        .lpfnWndProc   = form_wnd_proc,
        .hInstance     = g_app.hInstance,
        .hbrBackground = NULL,
        .lpszClassName = CLASS,
        .hCursor       = LoadCursor(NULL, IDC_ARROW),
    };
    RegisterClassExW(&wc);

    RECT parentRect;
    GetWindowRect(parent, &parentRect);
    int x = parentRect.left + (parentRect.right  - parentRect.left  - 500) / 2;
    int y = parentRect.top  + (parentRect.bottom - parentRect.top   - winH) / 2;

    HWND hwnd = CreateWindowExW(
        WS_EX_DLGMODALFRAME,
        CLASS, L"供应商配置 - ACode",
        WS_POPUP | WS_CAPTION | WS_SYSMENU | WS_CLIPCHILDREN,
        x, y, 500, winH,
        parent, NULL, g_app.hInstance, &ctx
    );
    if (!hwnd) return FALSE;

    /* Pre-fill fields if editing */
    if (existing) {
        set_edit_utf8(hwnd, IDC_EDIT_NAME,    existing->name);
        set_edit_utf8(hwnd, IDC_EDIT_APIKEY,  existing->apiKey);
        set_edit_utf8(hwnd, IDC_EDIT_APIBASE, existing->apiBase);
        set_edit_utf8(hwnd, IDC_EDIT_MODEL,   existing->model);
        set_edit_utf8(hwnd, IDC_EDIT_EXTRAENV,existing->extraEnv[0] ? existing->extraEnv : "{}");
        set_edit_utf8(hwnd, IDC_EDIT_NOTES,   existing->notes);

        /* Parse Claude multi-model fields from extraEnv */
        if (ctx.isClaude && existing->extraEnv[0]) {
            /* Simple key extraction without full JSON parser for speed */
            const char *keys[] = {
                "ANTHROPIC_DEFAULT_HAIKU_MODEL",
                "ANTHROPIC_DEFAULT_SONNET_MODEL",
                "ANTHROPIC_DEFAULT_OPUS_MODEL"
            };
            int editIds[] = { IDC_EDIT_HAIKU, IDC_EDIT_SONNET, IDC_EDIT_OPUS };
            for (int k = 0; k < 3; k++) {
                const char *found = strstr(existing->extraEnv, keys[k]);
                if (found) {
                    const char *colon = strchr(found, ':');
                    if (colon) {
                        const char *valStart = colon + 1;
                        while (*valStart == ' ' || *valStart == '"') valStart++;
                        const char *valEnd = valStart;
                        while (*valEnd && *valEnd != '"' && *valEnd != ',') valEnd++;
                        char val[128] = {0};
                        int len = (int)(valEnd - valStart);
                        if (len > 0 && len < 128) {
                            strncpy(val, valStart, len);
                            set_edit_utf8(hwnd, editIds[k], val);
                        }
                    }
                }
            }
        }
    }

    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);

    /* Local message loop — blocks until form is closed */
    MSG msg;
    while (GetMessageW(&msg, NULL, 0, 0)) {
        if (msg.hwnd == hwnd || IsChild(hwnd, msg.hwnd)) {
            if (msg.message == WM_QUIT) break;
            if (!IsDialogMessageW(hwnd, &msg)) {
                TranslateMessage(&msg);
                DispatchMessageW(&msg);
            }
        } else {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
    }

    return ctx.saved;
}

/* ---------------------------------------------------------------
 * Preset Picker Dialog
 * --------------------------------------------------------------- */

typedef struct {
    char    tool[32];
    int     selectedPresetIdx;  /* -1 = none */
    BOOL    saved;
} PresetCtx;

static LRESULT CALLBACK preset_wnd_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    PresetCtx *ctx = (PresetCtx *)GetWindowLongPtrW(hwnd, GWLP_USERDATA);

    switch (msg) {

    case WM_CREATE: {
        CREATESTRUCTW *cs = (CREATESTRUCTW *)lParam;
        ctx = (PresetCtx *)cs->lpCreateParams;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)ctx);

        HINSTANCE hInst = g_app.hInstance;
        HFONT font = CreateFontW(14, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
        HFONT fontBold = CreateFontW(15, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");

        /* Preset list */
        HWND list = CreateWindowExW(WS_EX_CLIENTEDGE, WC_LISTBOXW, NULL,
            WS_CHILD | WS_VISIBLE | LBS_NOTIFY | LBS_NOINTEGRALHEIGHT | WS_VSCROLL,
            16, 50, 452, 180, hwnd, (HMENU)IDC_LIST_PRESETS, hInst, NULL);
        SendMessageW(list, WM_SETFONT, (WPARAM)font, FALSE);

        /* Populate presets */
        int presetCount = 0;
        const ProviderPreset *presets = provider_get_presets(&presetCount);
        for (int i = 0; i < presetCount; i++) {
            if (strcmp(presets[i].tool, ctx->tool) != 0) continue;
            wchar_t label[256];
            wchar_t wName[128], wBase[256];
            wstr_from_utf8(presets[i].name, wName, 128);
            wstr_from_utf8(presets[i].apiBase[0] ? presets[i].apiBase : "官方默认端点", wBase, 256);
            _snwprintf(label, 256, L"%s  —  %s", wName, wBase);
            int idx = (int)SendMessageW(list, LB_ADDSTRING, 0, (LPARAM)label);
            SendMessageW(list, LB_SETITEMDATA, idx, (LPARAM)i);
        }

        /* API Key label + edit */
        HWND pkLbl = CreateWindowExW(0, L"STATIC", L"API Key *",
            WS_CHILD | WS_VISIBLE | SS_LEFT,
            16, 244, 200, 18, hwnd, (HMENU)IDC_LBL_PK_APIKEY, hInst, NULL);
        SendMessageW(pkLbl, WM_SETFONT, (WPARAM)font, FALSE);

        HWND pkEdit = CreateWindowExW(WS_EX_CLIENTEDGE, L"EDIT", NULL,
            WS_CHILD | WS_VISIBLE | WS_BORDER | WS_TABSTOP | ES_PASSWORD | ES_AUTOHSCROLL,
            16, 264, 452, 24, hwnd, (HMENU)IDC_EDIT_PK_APIKEY, hInst, NULL);
        SendMessageW(pkEdit, WM_SETFONT, (WPARAM)font, FALSE);

        /* Buttons */
        HWND btnAdd = CreateWindowExW(0, L"BUTTON", L"添加",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_DEFPUSHBUTTON,
            252, 304, 100, 28, hwnd, (HMENU)IDC_BTN_PK_ADD, hInst, NULL);
        SendMessageW(btnAdd, WM_SETFONT, (WPARAM)fontBold, FALSE);

        HWND btnCancel = CreateWindowExW(0, L"BUTTON", L"取消",
            WS_CHILD | WS_VISIBLE | WS_TABSTOP | BS_PUSHBUTTON,
            368, 304, 100, 28, hwnd, (HMENU)IDC_BTN_PK_CANCEL, hInst, NULL);
        SendMessageW(btnCancel, WM_SETFONT, (WPARAM)font, FALSE);

        (void)fontBold;
        return 0;
    }

    case WM_COMMAND:
        switch (LOWORD(wParam)) {

        case IDC_LIST_PRESETS:
            if (HIWORD(wParam) == LBN_SELCHANGE) {
                HWND list = GetDlgItem(hwnd, IDC_LIST_PRESETS);
                int sel = (int)SendMessageW(list, LB_GETCURSEL, 0, 0);
                ctx->selectedPresetIdx = (sel >= 0)
                    ? (int)SendMessageW(list, LB_GETITEMDATA, sel, 0)
                    : -1;
            }
            break;

        case IDC_BTN_PK_ADD: {
            if (ctx->selectedPresetIdx < 0) {
                MessageBoxW(hwnd, L"请先选择一个预设", L"提示", MB_OK | MB_ICONINFORMATION);
                break;
            }

            char apiKey[512] = {0};
            get_edit_utf8(hwnd, IDC_EDIT_PK_APIKEY, apiKey, sizeof(apiKey));
            if (!apiKey[0]) {
                MessageBoxW(hwnd, L"API Key 不能为空", L"提示", MB_OK | MB_ICONINFORMATION);
                break;
            }

            int presetCount = 0;
            const ProviderPreset *presets = provider_get_presets(&presetCount);
            const ProviderPreset *preset = &presets[ctx->selectedPresetIdx];

            Provider p;
            memset(&p, 0, sizeof(Provider));
            strncpy(p.name,     preset->name,    sizeof(p.name) - 1);
            strncpy(p.tool,     preset->tool,    sizeof(p.tool) - 1);
            strncpy(p.apiKey,   apiKey,          sizeof(p.apiKey) - 1);
            strncpy(p.apiBase,  preset->apiBase, sizeof(p.apiBase) - 1);
            strncpy(p.model,    preset->model,   sizeof(p.model) - 1);
            strncpy(p.presetId, preset->id,      sizeof(p.presetId) - 1);
            strncpy(p.icon,     preset->icon,    sizeof(p.icon) - 1);
            strcpy(p.extraEnv, "{}");

            bool ok = provider_insert(&p);
            if (ok) {
                /* Auto-activate if first for this tool */
                Provider *list = NULL;
                int count = 0;
                provider_list(preset->tool, &list, &count);
                if (count == 1) {
                    provider_switch(list[0].id);
                    provider_service_write_config(&list[0]);
                }
                provider_free_list(list);

                ctx->saved = TRUE;
                DestroyWindow(hwnd);
            } else {
                MessageBoxW(hwnd, L"添加失败", L"错误", MB_OK | MB_ICONERROR);
            }
            break;
        }

        case IDC_BTN_PK_CANCEL:
            DestroyWindow(hwnd);
            break;
        }
        return 0;

    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);
        RECT rc;
        GetClientRect(hwnd, &rc);

        HBRUSH bg = CreateSolidBrush(g_app.isDarkMode ? RGB(30, 30, 30) : RGB(245, 245, 245));
        FillRect(hdc, &rc, bg);
        DeleteObject(bg);

        HFONT titleFont = CreateFontW(16, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
        SelectObject(hdc, titleFont);
        SetBkMode(hdc, TRANSPARENT);
        SetTextColor(hdc, g_app.isDarkMode ? RGB(240, 240, 240) : RGB(20, 20, 20));

        RECT titleRect = { 16, 12, rc.right - 16, 40 };
        DrawTextW(hdc, L"从预设添加供应商", -1, &titleRect, DT_LEFT | DT_SINGLELINE);
        DeleteObject(titleFont);

        EndPaint(hwnd, &ps);
        return 0;
    }

    case WM_CTLCOLORSTATIC: {
        HDC hdcS = (HDC)wParam;
        SetBkMode(hdcS, TRANSPARENT);
        SetTextColor(hdcS, g_app.isDarkMode ? RGB(200, 200, 200) : RGB(60, 60, 60));
        return (LRESULT)GetStockObject(NULL_BRUSH);
    }

    case WM_CTLCOLOREDIT: {
        HDC hdcE = (HDC)wParam;
        SetBkColor(hdcE, g_app.isDarkMode ? RGB(45, 45, 45) : RGB(255, 255, 255));
        SetTextColor(hdcE, g_app.isDarkMode ? RGB(220, 220, 220) : RGB(20, 20, 20));
        static HBRUSH s_bg = NULL;
        if (!s_bg) s_bg = CreateSolidBrush(RGB(45, 45, 45));
        return g_app.isDarkMode ? (LRESULT)s_bg : (LRESULT)GetStockObject(WHITE_BRUSH);
    }

    case WM_ERASEBKGND:
        return 1;

    case WM_KEYDOWN:
        if (wParam == VK_ESCAPE) { DestroyWindow(hwnd); return 0; }
        break;

    case WM_DESTROY:
        PostQuitMessage(0);
        return 0;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

BOOL provider_preset_show(HWND parent, const char *tool) {
    PresetCtx ctx;
    memset(&ctx, 0, sizeof(ctx));
    strncpy(ctx.tool, tool, sizeof(ctx.tool) - 1);
    ctx.selectedPresetIdx = -1;
    ctx.saved = FALSE;

    static const wchar_t *CLASS = L"ACodePresetPicker";
    WNDCLASSEXW wc = {
        .cbSize        = sizeof(WNDCLASSEXW),
        .lpfnWndProc   = preset_wnd_proc,
        .hInstance     = g_app.hInstance,
        .hbrBackground = NULL,
        .lpszClassName = CLASS,
        .hCursor       = LoadCursor(NULL, IDC_ARROW),
    };
    RegisterClassExW(&wc);

    RECT parentRect;
    GetWindowRect(parent, &parentRect);
    int x = parentRect.left + (parentRect.right  - parentRect.left  - 490) / 2;
    int y = parentRect.top  + (parentRect.bottom - parentRect.top   - 360) / 2;

    HWND hwnd = CreateWindowExW(
        WS_EX_DLGMODALFRAME,
        CLASS, L"从预设添加 - ACode",
        WS_POPUP | WS_CAPTION | WS_SYSMENU | WS_CLIPCHILDREN,
        x, y, 490, 360,
        parent, NULL, g_app.hInstance, &ctx
    );
    if (!hwnd) return FALSE;

    ShowWindow(hwnd, SW_SHOW);
    UpdateWindow(hwnd);

    MSG msg;
    while (GetMessageW(&msg, NULL, 0, 0)) {
        if (msg.hwnd == hwnd || IsChild(hwnd, msg.hwnd)) {
            if (msg.message == WM_QUIT) break;
            if (!IsDialogMessageW(hwnd, &msg)) {
                TranslateMessage(&msg);
                DispatchMessageW(&msg);
            }
        } else {
            TranslateMessage(&msg);
            DispatchMessageW(&msg);
        }
    }

    return ctx.saved;
}
