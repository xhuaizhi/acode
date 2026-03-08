#include "file_tree.h"
#include "file_node.h"
#include "../app.h"
#include "../utils/theme.h"
#include "../utils/wstr.h"
#include "../editor/editor_tabs.h"
#include <commctrl.h>
#include <shlwapi.h>
#include <shlobj.h>
#include <stdio.h>

#define EXPLORER_CLASS L"ACodeFileExplorer"

static HWND s_hwndContainer;
static HWND s_hwndTree;
static HWND s_hwndToolbar;
static HWND s_hwndPathBar;
static wchar_t s_rootPath[MAX_PATH] = {0};
static HIMAGELIST s_hImageList;

/* Cached GDI fonts to avoid per-paint allocation */
static HFONT s_ftIconFont    = NULL;
static HFONT s_ftNameFont    = NULL;
static HFONT s_ftRefreshFont = NULL;
static HFONT s_ftEmptyFont   = NULL;
static HFONT s_ftPathFont    = NULL;
static HFONT s_ftCopyFont    = NULL;

static void ensure_ft_fonts(void) {
    if (!s_ftIconFont)
        s_ftIconFont = CreateFontW(14, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI Symbol");
    if (!s_ftNameFont)
        s_ftNameFont = CreateFontW(14, 0, 0, 0, FW_SEMIBOLD, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    if (!s_ftRefreshFont)
        s_ftRefreshFont = CreateFontW(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI Symbol");
    if (!s_ftEmptyFont)
        s_ftEmptyFont = CreateFontW(13, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI");
    if (!s_ftPathFont)
        s_ftPathFont = CreateFontW(11, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Cascadia Mono");
    if (!s_ftCopyFont)
        s_ftCopyFont = CreateFontW(12, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, 0, 0, CLEARTYPE_QUALITY, 0, L"Segoe UI Symbol");
}

#define IDC_TOOLBAR_REFRESH  5001
#define TOOLBAR_HEIGHT       30
#define PATHBAR_HEIGHT       22

static void populate_tree_item(HTREEITEM parentItem, const wchar_t *dirPath);

static int get_icon_index(const wchar_t *path, bool isDir) {
    SHFILEINFOW sfi = {0};
    DWORD flags = SHGFI_SYSICONINDEX | SHGFI_SMALLICON;
    if (isDir) flags |= SHGFI_USEFILEATTRIBUTES;

    SHGetFileInfoW(path, isDir ? FILE_ATTRIBUTE_DIRECTORY : 0,
                   &sfi, sizeof(sfi), flags);
    return sfi.iIcon;
}

static void insert_node(HTREEITEM parent, const wchar_t *name, const wchar_t *fullPath, bool isDir) {
    TVINSERTSTRUCTW tvis = {0};
    tvis.hParent = parent;
    tvis.hInsertAfter = TVI_SORT;
    tvis.item.mask = TVIF_TEXT | TVIF_IMAGE | TVIF_SELECTEDIMAGE | TVIF_PARAM;
    tvis.item.pszText = (LPWSTR)name;

    int icon = get_icon_index(fullPath, isDir);
    tvis.item.iImage = icon;
    tvis.item.iSelectedImage = icon;

    /* Store a FileNode as lParam */
    FileNode *node = file_node_create(fullPath, isDir);
    tvis.item.lParam = (LPARAM)node;

    if (isDir) {
        tvis.item.mask |= TVIF_CHILDREN;
        tvis.item.cChildren = 1;
    }

    SendMessageW(s_hwndTree, TVM_INSERTITEMW, 0, (LPARAM)&tvis);
}

static void populate_tree_item(HTREEITEM parentItem, const wchar_t *dirPath) {
    wchar_t searchPath[MAX_PATH];
    _snwprintf(searchPath, MAX_PATH, L"%s\\*", dirPath);

    WIN32_FIND_DATAW fd;
    HANDLE hFind = FindFirstFileW(searchPath, &fd);
    if (hFind == INVALID_HANDLE_VALUE) return;

    /* First pass: directories */
    do {
        if (fd.cFileName[0] == L'.') continue;
        if (!(fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY)) continue;

        wchar_t fullPath[MAX_PATH];
        _snwprintf(fullPath, MAX_PATH, L"%s\\%s", dirPath, fd.cFileName);
        insert_node(parentItem, fd.cFileName, fullPath, true);
    } while (FindNextFileW(hFind, &fd));

    /* Restart for files */
    FindClose(hFind);
    hFind = FindFirstFileW(searchPath, &fd);
    if (hFind == INVALID_HANDLE_VALUE) return;

    do {
        if (fd.cFileName[0] == L'.') continue;
        if (fd.dwFileAttributes & FILE_ATTRIBUTE_DIRECTORY) continue;

        wchar_t fullPath[MAX_PATH];
        _snwprintf(fullPath, MAX_PATH, L"%s\\%s", dirPath, fd.cFileName);
        insert_node(parentItem, fd.cFileName, fullPath, false);
    } while (FindNextFileW(hFind, &fd));

    FindClose(hFind);
}

static void on_item_expanding(NMTREEVIEWW *nmtv) {
    if (nmtv->action != TVE_EXPAND) return;

    HTREEITEM hItem = nmtv->itemNew.hItem;
    FileNode *node = (FileNode *)nmtv->itemNew.lParam;
    if (!node || !node->isDir || node->loaded) return;

    /* Remove placeholder children and load real ones */
    HTREEITEM hChild = TreeView_GetChild(s_hwndTree, hItem);
    while (hChild) {
        HTREEITEM hNext = TreeView_GetNextSibling(s_hwndTree, hChild);
        TreeView_DeleteItem(s_hwndTree, hChild);
        hChild = hNext;
    }

    populate_tree_item(hItem, node->path);
    node->loaded = true;
}

static void on_item_click(NMTREEVIEWW *nmtv) {
    FileNode *node = (FileNode *)nmtv->itemNew.lParam;
    if (!node || node->isDir) return;
    editor_tabs_open_file(node->path);
}

static void show_context_menu(HWND hwnd, int x, int y) {
    TVHITTESTINFO ht = {0};
    ht.pt.x = x;
    ht.pt.y = y;
    ScreenToClient(s_hwndTree, &ht.pt);
    HTREEITEM hItem = TreeView_HitTest(s_hwndTree, &ht);
    if (!hItem) return;

    TreeView_SelectItem(s_hwndTree, hItem);

    TVITEMW tvi = {0};
    tvi.mask = TVIF_PARAM;
    tvi.hItem = hItem;
    SendMessageW(s_hwndTree, TVM_GETITEMW, 0, (LPARAM)&tvi);
    FileNode *node = (FileNode *)tvi.lParam;
    if (!node) return;

    HMENU hMenu = CreatePopupMenu();
    AppendMenuW(hMenu, MF_STRING, 1, L"\u590D\u5236\u8DEF\u5F84");
    AppendMenuW(hMenu, MF_STRING, 5, L"\u590D\u5236\u76F8\u5BF9\u8DEF\u5F84");
    AppendMenuW(hMenu, MF_STRING, 2, L"\u5728\u8D44\u6E90\u7BA1\u7406\u5668\u4E2D\u663E\u793A");
    AppendMenuW(hMenu, MF_SEPARATOR, 0, NULL);
    AppendMenuW(hMenu, MF_STRING, 3, L"\u91CD\u547D\u540D");
    AppendMenuW(hMenu, MF_STRING, 4, L"\u5220\u9664");

    int cmd = TrackPopupMenu(hMenu, TPM_RETURNCMD, x, y, 0, hwnd, NULL);
    DestroyMenu(hMenu);

    switch (cmd) {
    case 1: { /* Copy path */
        if (OpenClipboard(hwnd)) {
            EmptyClipboard();
            size_t len = wcslen(node->path) + 1;
            HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, len * sizeof(wchar_t));
            if (hMem) {
                wchar_t *mem = (wchar_t *)GlobalLock(hMem);
                wcscpy(mem, node->path);
                GlobalUnlock(hMem);
                SetClipboardData(CF_UNICODETEXT, hMem);
            }
            CloseClipboard();
        }
        break;
    }
    case 5: { /* Copy relative path (matches Mac) */
        const wchar_t *relPath = node->path;
        if (s_rootPath[0]) {
            size_t rootLen = wcslen(s_rootPath);
            if (wcsncmp(node->path, s_rootPath, rootLen) == 0) {
                relPath = node->path + rootLen;
                if (*relPath == L'\\' || *relPath == L'/') relPath++;
            }
        }
        if (OpenClipboard(hwnd)) {
            EmptyClipboard();
            size_t len = wcslen(relPath) + 1;
            HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, len * sizeof(wchar_t));
            if (hMem) {
                wchar_t *mem = (wchar_t *)GlobalLock(hMem);
                wcscpy(mem, relPath);
                GlobalUnlock(hMem);
                SetClipboardData(CF_UNICODETEXT, hMem);
            }
            CloseClipboard();
        }
        break;
    }
    case 2: { /* Reveal in Explorer */
        wchar_t cmd[MAX_PATH + 32];
        _snwprintf(cmd, _countof(cmd), L"/select,\"%s\"", node->path);
        ShellExecuteW(NULL, L"open", L"explorer.exe", cmd, NULL, SW_SHOW);
        break;
    }
    case 3: { /* Rename - TODO: inline edit */
        TreeView_EditLabel(s_hwndTree, hItem);
        break;
    }
    case 4: { /* Delete */
        wchar_t msg[MAX_PATH + 64];
        _snwprintf(msg, _countof(msg), L"\u786E\u5B9A\u8981\u5220\u9664 \"%s\" \u5417\uFF1F",
                   PathFindFileNameW(node->path));
        if (MessageBoxW(hwnd, msg, L"ACode", MB_YESNO | MB_ICONQUESTION) == IDYES) {
            /* Move to recycle bin */
            SHFILEOPSTRUCTW op = {0};
            wchar_t from[MAX_PATH + 2] = {0};
            wcscpy(from, node->path);
            op.wFunc = FO_DELETE;
            op.pFrom = from;
            op.fFlags = FOF_ALLOWUNDO | FOF_NOCONFIRMATION;
            SHFileOperationW(&op);
            file_tree_refresh();
        }
        break;
    }
    }
}

/* ---- Toolbar paint: folder icon + project name + refresh button ---- */
static void paint_toolbar(HDC hdc, RECT *rc) {
    const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);

    /* Background */
    HBRUSH bg = CreateSolidBrush(colors->surface);
    FillRect(hdc, rc, bg);
    DeleteObject(bg);

    /* Bottom border */
    HPEN pen = CreatePen(PS_SOLID, 1, colors->border);
    HPEN oldPen = SelectObject(hdc, pen);
    MoveToEx(hdc, 0, rc->bottom - 1, NULL);
    LineTo(hdc, rc->right, rc->bottom - 1);
    SelectObject(hdc, oldPen);
    DeleteObject(pen);

    SetBkMode(hdc, TRANSPARENT);

    ensure_ft_fonts();

    if (s_rootPath[0]) {
        /* Folder icon (Unicode folder glyph) */
        HFONT origFont = SelectObject(hdc, s_ftIconFont);
        SetTextColor(hdc, colors->textSecondary);
        RECT iconRect = { 8, 0, 26, rc->bottom - 1 };
        DrawTextW(hdc, L"\U0001F4C1", -1, &iconRect, DT_LEFT | DT_VCENTER | DT_SINGLELINE);

        /* Project name */
        SelectObject(hdc, s_ftNameFont);
        SetTextColor(hdc, colors->text);

        const wchar_t *projName = wcsrchr(s_rootPath, L'\\');
        if (projName) projName++; else projName = s_rootPath;

        RECT nameRect = { 28, 0, rc->right - 30, rc->bottom - 1 };
        DrawTextW(hdc, projName, -1, &nameRect, DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS);

        /* Refresh button (arrow clockwise glyph) */
        SelectObject(hdc, s_ftRefreshFont);
        SetTextColor(hdc, colors->textSecondary);
        RECT refreshRect = { rc->right - 26, 0, rc->right - 4, rc->bottom - 1 };
        DrawTextW(hdc, L"\x21BB", -1, &refreshRect, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
        SelectObject(hdc, origFont);
    } else {
        HFONT oldFont = SelectObject(hdc, s_ftEmptyFont);
        SetTextColor(hdc, colors->textSecondary);
        RECT textRect = { 8, 0, rc->right - 4, rc->bottom - 1 };
        DrawTextW(hdc, L"\u6587\u4EF6\u6D4F\u89C8\u5668", -1, &textRect, DT_LEFT | DT_VCENTER | DT_SINGLELINE);
        SelectObject(hdc, oldFont);
    }
}

/* ---- Path bar paint: full root path at bottom ---- */
static void paint_pathbar(HDC hdc, RECT *rc) {
    const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);

    HBRUSH bg = CreateSolidBrush(colors->surface);
    FillRect(hdc, rc, bg);
    DeleteObject(bg);

    /* Top border */
    HPEN pen = CreatePen(PS_SOLID, 1, colors->border);
    HPEN oldPen = SelectObject(hdc, pen);
    MoveToEx(hdc, 0, 0, NULL);
    LineTo(hdc, rc->right, 0);
    SelectObject(hdc, oldPen);
    DeleteObject(pen);

    ensure_ft_fonts();

    if (s_rootPath[0]) {
        SetBkMode(hdc, TRANSPARENT);
        HFONT oldFont = SelectObject(hdc, s_ftPathFont);
        SetTextColor(hdc, colors->textSecondary);
        RECT textRect = { 6, 1, rc->right - 24, rc->bottom };
        DrawTextW(hdc, s_rootPath, -1, &textRect, DT_LEFT | DT_VCENTER | DT_SINGLELINE | DT_END_ELLIPSIS | DT_PATH_ELLIPSIS);

        /* Copy button glyph (matches Mac doc.on.doc) */
        SelectObject(hdc, s_ftCopyFont);
        SetTextColor(hdc, colors->textSecondary);
        RECT copyRect = { rc->right - 22, 1, rc->right - 2, rc->bottom };
        DrawTextW(hdc, L"\x2398", -1, &copyRect, DT_CENTER | DT_VCENTER | DT_SINGLELINE);
        SelectObject(hdc, oldFont);
    }
}

/* ---- Toolbar window proc ---- */
static LRESULT CALLBACK toolbar_wnd_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);
        RECT rc;
        GetClientRect(hwnd, &rc);
        paint_toolbar(hdc, &rc);
        EndPaint(hwnd, &ps);
        return 0;
    }
    case WM_ERASEBKGND:
        return 1;
    case WM_LBUTTONDOWN: {
        /* Check if refresh button area was clicked */
        RECT rc;
        GetClientRect(hwnd, &rc);
        int x = GET_X_LPARAM(lParam);
        if (x >= rc.right - 28 && s_rootPath[0]) {
            file_tree_refresh();
            InvalidateRect(hwnd, NULL, FALSE);
        }
        return 0;
    }
    }
    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

/* ---- Path bar window proc ---- */
static LRESULT CALLBACK pathbar_wnd_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);
        RECT rc;
        GetClientRect(hwnd, &rc);
        paint_pathbar(hdc, &rc);
        EndPaint(hwnd, &ps);
        return 0;
    }
    case WM_ERASEBKGND:
        return 1;
    case WM_LBUTTONDOWN: {
        /* Copy path button click area (right 22px) */
        RECT rc;
        GetClientRect(hwnd, &rc);
        int x = GET_X_LPARAM(lParam);
        if (x >= rc.right - 22 && s_rootPath[0]) {
            if (OpenClipboard(hwnd)) {
                EmptyClipboard();
                size_t len = wcslen(s_rootPath) + 1;
                HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, len * sizeof(wchar_t));
                if (hMem) {
                    wchar_t *mem = (wchar_t *)GlobalLock(hMem);
                    wcscpy(mem, s_rootPath);
                    GlobalUnlock(hMem);
                    SetClipboardData(CF_UNICODETEXT, hMem);
                }
                CloseClipboard();
            }
        }
        return 0;
    }
    }
    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

static LRESULT CALLBACK explorer_wnd_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_SIZE: {
        RECT rc;
        GetClientRect(hwnd, &rc);
        int pathH = s_rootPath[0] ? PATHBAR_HEIGHT : 0;
        if (s_hwndToolbar)
            MoveWindow(s_hwndToolbar, 0, 0, rc.right, TOOLBAR_HEIGHT, TRUE);
        if (s_hwndTree)
            MoveWindow(s_hwndTree, 0, TOOLBAR_HEIGHT, rc.right, rc.bottom - TOOLBAR_HEIGHT - pathH, TRUE);
        if (s_hwndPathBar) {
            ShowWindow(s_hwndPathBar, s_rootPath[0] ? SW_SHOW : SW_HIDE);
            MoveWindow(s_hwndPathBar, 0, rc.bottom - pathH, rc.right, pathH, TRUE);
        }
        return 0;
    }

    case WM_NOTIFY: {
        NMHDR *nmhdr = (NMHDR *)lParam;
        if (nmhdr->hwndFrom == s_hwndTree) {
            switch (nmhdr->code) {
            case TVN_ITEMEXPANDINGW:
                on_item_expanding((NMTREEVIEWW *)lParam);
                return 0;
            case TVN_SELCHANGEDW:
                on_item_click((NMTREEVIEWW *)lParam);
                return 0;
            case TVN_DELETEITEMW: {
                NMTREEVIEWW *nmtv = (NMTREEVIEWW *)lParam;
                FileNode *node = (FileNode *)nmtv->itemOld.lParam;
                if (node) file_node_free(node);
                return 0;
            }
            case NM_RCLICK: {
                POINT pt;
                GetCursorPos(&pt);
                show_context_menu(hwnd, pt.x, pt.y);
                return 0;
            }
            }
        }
        break;
    }

    case WM_CONTEXTMENU: {
        POINT pt;
        GetCursorPos(&pt);
        show_context_menu(hwnd, pt.x, pt.y);
        return 0;
    }

    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);
        const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);
        HBRUSH bg = CreateSolidBrush(colors->surface);
        FillRect(hdc, &ps.rcPaint, bg);
        DeleteObject(bg);
        EndPaint(hwnd, &ps);
        return 0;
    }

    case WM_ERASEBKGND:
        return 1;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

HWND file_tree_create(HWND parent, HINSTANCE hInstance) {
    WNDCLASSEXW wc = {
        .cbSize = sizeof(WNDCLASSEXW),
        .lpfnWndProc = explorer_wnd_proc,
        .hInstance = hInstance,
        .hbrBackground = NULL,
        .lpszClassName = EXPLORER_CLASS,
        .hCursor = LoadCursor(NULL, IDC_ARROW),
    };
    RegisterClassExW(&wc);

    /* Register toolbar sub-window class */
    WNDCLASSEXW tbwc = {
        .cbSize = sizeof(WNDCLASSEXW),
        .lpfnWndProc = toolbar_wnd_proc,
        .hInstance = hInstance,
        .hbrBackground = NULL,
        .lpszClassName = L"ACodeExplorerToolbar",
        .hCursor = LoadCursor(NULL, IDC_ARROW),
    };
    RegisterClassExW(&tbwc);

    /* Register path bar sub-window class */
    WNDCLASSEXW pbwc = {
        .cbSize = sizeof(WNDCLASSEXW),
        .lpfnWndProc = pathbar_wnd_proc,
        .hInstance = hInstance,
        .hbrBackground = NULL,
        .lpszClassName = L"ACodeExplorerPathBar",
        .hCursor = LoadCursor(NULL, IDC_ARROW),
    };
    RegisterClassExW(&pbwc);

    s_hwndContainer = CreateWindowExW(
        0, EXPLORER_CLASS, NULL,
        WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN,
        0, 0, 100, 100,
        parent, (HMENU)IDC_SIDEBAR, hInstance, NULL
    );

    /* Create toolbar */
    s_hwndToolbar = CreateWindowExW(
        0, L"ACodeExplorerToolbar", NULL,
        WS_CHILD | WS_VISIBLE,
        0, 0, 100, TOOLBAR_HEIGHT,
        s_hwndContainer, NULL, hInstance, NULL
    );

    /* Create path bar */
    s_hwndPathBar = CreateWindowExW(
        0, L"ACodeExplorerPathBar", NULL,
        WS_CHILD,
        0, 0, 100, PATHBAR_HEIGHT,
        s_hwndContainer, NULL, hInstance, NULL
    );

    /* System image list */
    SHFILEINFOW sfi = {0};
    s_hImageList = (HIMAGELIST)SHGetFileInfoW(
        L"C:\\", 0, &sfi, sizeof(sfi),
        SHGFI_SYSICONINDEX | SHGFI_SMALLICON
    );

    /* Create TreeView */
    s_hwndTree = CreateWindowExW(
        0, WC_TREEVIEWW, NULL,
        WS_CHILD | WS_VISIBLE | WS_TABSTOP |
        TVS_HASLINES | TVS_HASBUTTONS | TVS_LINESATROOT |
        TVS_SHOWSELALWAYS | TVS_EDITLABELS,
        0, 0, 100, 100,
        s_hwndContainer, NULL, hInstance, NULL
    );

    TreeView_SetImageList(s_hwndTree, s_hImageList, TVSIL_NORMAL);

    return s_hwndContainer;
}

void file_tree_open_folder(const wchar_t *path) {
    if (!path || !*path) return;
    wcscpy(s_rootPath, path);

    TreeView_DeleteAllItems(s_hwndTree);
    populate_tree_item(TVI_ROOT, path);

    /* Refresh toolbar and path bar */
    if (s_hwndToolbar) InvalidateRect(s_hwndToolbar, NULL, FALSE);
    if (s_hwndPathBar) {
        ShowWindow(s_hwndPathBar, SW_SHOW);
        InvalidateRect(s_hwndPathBar, NULL, FALSE);
    }
    /* Trigger relayout to account for path bar visibility */
    if (s_hwndContainer) SendMessageW(s_hwndContainer, WM_SIZE, 0, 0);
}

void file_tree_refresh(void) {
    if (s_rootPath[0]) {
        file_tree_open_folder(s_rootPath);
    }
}

const wchar_t *file_tree_get_root_path(void) {
    return s_rootPath[0] ? s_rootPath : NULL;
}
