#include "terminal_mgr.h"
#include "terminal_view.h"
#include "conpty.h"
#include "../app.h"
#include "../utils/theme.h"
#include "../utils/wstr.h"
#include "../window/split_view.h"
#include "../window/main_window.h"
#include <stdlib.h>
#include <stdio.h>
#include <windowsx.h>

#define TERMMGR_CLASS L"ACodeTerminalManager"

typedef struct {
    HWND       hwndContainer;
    SplitNode *root;
    HWND       focusedTerm;
    int        nextId;
    wchar_t    envBlock[8192];
    bool       dragging;
    SplitNode *dragNode;
    int        dragStartPos;
    float      dragStartRatio;
} TermMgrState;

static TermMgrState s_mgr = {0};

static void do_layout(void) {
    if (!s_mgr.hwndContainer || !s_mgr.root) return;
    RECT rc;
    GetClientRect(s_mgr.hwndContainer, &rc);
    split_node_layout(s_mgr.root, rc, s_mgr.hwndContainer);
}

static void start_shell(HWND hwndTerm) {
    TerminalView *tv = terminal_view_from_hwnd(hwndTerm);
    if (!tv) return;
    wchar_t cwd[MAX_PATH];
    GetCurrentDirectoryW(MAX_PATH, cwd);
    const wchar_t *env = s_mgr.envBlock[0] ? s_mgr.envBlock : NULL;
    conpty_create(&tv->pty, g_app.defaultShell, cwd, env, tv->cols, tv->rows);
}

static HWND create_terminal(void) {
    int id = s_mgr.nextId++;
    HWND hwnd = terminal_view_create(s_mgr.hwndContainer, g_app.hInstance, id);
    if (hwnd) start_shell(hwnd);
    return hwnd;
}

static SplitNode *find_focused_leaf(SplitNode *node) {
    if (!node) return NULL;
    if (node->type == SNODE_LEAF) {
        if (node->hwndTerminal == s_mgr.focusedTerm)
            return node;
        return NULL;
    }
    SplitNode *f = find_focused_leaf(node->first);
    return f ? f : find_focused_leaf(node->second);
}

static SplitNode *find_first_leaf(SplitNode *node) {
    if (!node) return NULL;
    if (node->type == SNODE_LEAF) return node;
    return find_first_leaf(node->first);
}

/* Replace a child node within its parent (or root) with a new node */
static void replace_node(SplitNode *old, SplitNode *replacement) {
    if (s_mgr.root == old) {
        s_mgr.root = replacement;
        return;
    }
    SplitNode *parent = split_node_find_parent(s_mgr.root, old);
    if (parent) {
        if (parent->first == old) parent->first = replacement;
        else if (parent->second == old) parent->second = replacement;
    }
}

static void do_split(SplitDirection dir) {
    SplitNode *leaf = find_focused_leaf(s_mgr.root);
    if (!leaf) leaf = find_first_leaf(s_mgr.root);
    if (!leaf) return;

    HWND newTerm = create_terminal();
    if (!newTerm) return;

    TerminalView *tv = terminal_view_from_hwnd(newTerm);
    SplitNode *newLeaf = split_node_new_leaf(newTerm, tv ? tv->id : 0);
    SplitNode *split = split_node_new_split(dir, leaf, newLeaf);

    replace_node(leaf, split);
    s_mgr.focusedTerm = newTerm;
    do_layout();
    SetFocus(newTerm);
}

static void paint_splitters(HDC hdc, SplitNode *node) {
    if (!node || node->type != SNODE_SPLIT) return;

    RECT b = node->bounds;
    int w = b.right - b.left;
    int h = b.bottom - b.top;
    const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);

    RECT splitterRect;
    if (node->dir == SPLIT_VERTICAL) {
        int sx = b.left + (int)(w * node->ratio);
        splitterRect = (RECT){ sx, b.top, sx + SPLITTER_WIDTH, b.bottom };
    } else {
        int sy = b.top + (int)(h * node->ratio);
        splitterRect = (RECT){ b.left, sy, b.right, sy + SPLITTER_WIDTH };
    }

    HBRUSH brush = CreateSolidBrush(colors->border);
    FillRect(hdc, &splitterRect, brush);
    DeleteObject(brush);

    paint_splitters(hdc, node->first);
    paint_splitters(hdc, node->second);
}

static LRESULT CALLBACK mgr_wnd_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    switch (msg) {
    case WM_SIZE:
        do_layout();
        return 0;

    case WM_PAINT: {
        PAINTSTRUCT ps;
        HDC hdc = BeginPaint(hwnd, &ps);
        const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);
        HBRUSH bg = CreateSolidBrush(colors->surface);
        FillRect(hdc, &ps.rcPaint, bg);
        DeleteObject(bg);
        paint_splitters(hdc, s_mgr.root);
        EndPaint(hwnd, &ps);
        return 0;
    }

    case WM_ERASEBKGND:
        return 1;

    case WM_LBUTTONDOWN: {
        if (!s_mgr.root) break;
        int x = GET_X_LPARAM(lParam), y = GET_Y_LPARAM(lParam);
        SplitHitResult hit = split_node_hit_test(s_mgr.root, x, y);
        if (hit.type == SPLIT_HIT_SPLITTER && hit.splitNode) {
            SetCapture(hwnd);
            s_mgr.dragging = true;
            s_mgr.dragNode = hit.splitNode;
            s_mgr.dragStartRatio = hit.splitNode->ratio;
            s_mgr.dragStartPos = (hit.dir == SPLIT_VERTICAL) ? x : y;
            SetCursor(LoadCursor(NULL,
                hit.dir == SPLIT_VERTICAL ? IDC_SIZEWE : IDC_SIZENS));
            return 0;
        }
        break;
    }

    case WM_MOUSEMOVE: {
        if (s_mgr.dragging && s_mgr.dragNode) {
            RECT b = s_mgr.dragNode->bounds;
            int x = GET_X_LPARAM(lParam), y = GET_Y_LPARAM(lParam);
            if (s_mgr.dragNode->dir == SPLIT_VERTICAL) {
                int totalW = b.right - b.left;
                if (totalW > 0) {
                    int dx = x - s_mgr.dragStartPos;
                    float newRatio = s_mgr.dragStartRatio + (float)dx / totalW;
                    if (newRatio < 0.15f) newRatio = 0.15f;
                    if (newRatio > 0.85f) newRatio = 0.85f;
                    s_mgr.dragNode->ratio = newRatio;
                    do_layout();
                    InvalidateRect(hwnd, NULL, TRUE);
                }
            } else {
                int totalH = b.bottom - b.top;
                if (totalH > 0) {
                    int dy = y - s_mgr.dragStartPos;
                    float newRatio = s_mgr.dragStartRatio + (float)dy / totalH;
                    if (newRatio < 0.15f) newRatio = 0.15f;
                    if (newRatio > 0.85f) newRatio = 0.85f;
                    s_mgr.dragNode->ratio = newRatio;
                    do_layout();
                    InvalidateRect(hwnd, NULL, TRUE);
                }
            }
            return 0;
        }

        /* Set cursor shape over splitter hot zones */
        if (!s_mgr.dragging && s_mgr.root) {
            int x = GET_X_LPARAM(lParam), y = GET_Y_LPARAM(lParam);
            SplitHitResult hit = split_node_hit_test(s_mgr.root, x, y);
            if (hit.type == SPLIT_HIT_SPLITTER) {
                SetCursor(LoadCursor(NULL,
                    hit.dir == SPLIT_VERTICAL ? IDC_SIZEWE : IDC_SIZENS));
                return 0;
            }
        }
        break;
    }

    case WM_LBUTTONUP:
        if (s_mgr.dragging) {
            ReleaseCapture();
            s_mgr.dragging = false;
            s_mgr.dragNode = NULL;
            return 0;
        }
        break;

    case WM_SETCURSOR:
        if (LOWORD(lParam) == HTCLIENT && s_mgr.root) {
            POINT pt;
            GetCursorPos(&pt);
            ScreenToClient(hwnd, &pt);
            SplitHitResult hit = split_node_hit_test(s_mgr.root, pt.x, pt.y);
            if (hit.type == SPLIT_HIT_SPLITTER) {
                SetCursor(LoadCursor(NULL,
                    hit.dir == SPLIT_VERTICAL ? IDC_SIZEWE : IDC_SIZENS));
                return TRUE;
            }
        }
        break;

    /* Track which terminal has focus */
    case WM_PARENTNOTIFY:
        if (LOWORD(wParam) == WM_LBUTTONDOWN) {
            POINT pt = { GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam) };
            HWND child = ChildWindowFromPoint(hwnd, pt);
            if (child && child != hwnd) {
                TerminalView *tv = terminal_view_from_hwnd(child);
                if (tv) s_mgr.focusedTerm = child;
            }
        }
        break;
    }


    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

/* ---- Public API ---- */

HWND terminal_mgr_create(HWND parent, HINSTANCE hInstance) {
    WNDCLASSEXW wc = {
        .cbSize = sizeof(WNDCLASSEXW),
        .style = CS_HREDRAW | CS_VREDRAW,
        .lpfnWndProc = mgr_wnd_proc,
        .hInstance = hInstance,
        .hbrBackground = NULL,
        .lpszClassName = TERMMGR_CLASS,
        .hCursor = LoadCursor(NULL, IDC_ARROW),
    };
    RegisterClassExW(&wc);
    terminal_view_register(hInstance);

    s_mgr.hwndContainer = CreateWindowExW(
        0, TERMMGR_CLASS, NULL,
        WS_CHILD | WS_VISIBLE | WS_CLIPCHILDREN,
        0, 0, 100, 100,
        parent, (HMENU)IDC_TERMINAL, hInstance, NULL
    );

    /* Create first terminal as root leaf */
    HWND hwndTerm = create_terminal();
    if (hwndTerm) {
        TerminalView *tv = terminal_view_from_hwnd(hwndTerm);
        s_mgr.root = split_node_new_leaf(hwndTerm, tv ? tv->id : 0);
        s_mgr.focusedTerm = hwndTerm;
        do_layout();
        SetFocus(hwndTerm);
    }


    return s_mgr.hwndContainer;
}

void terminal_mgr_new_tab(void) {
    HWND hwndTerm = create_terminal();
    if (!hwndTerm) return;

    TerminalView *tv = terminal_view_from_hwnd(hwndTerm);
    int id = tv ? tv->id : 0;

    if (!s_mgr.root) {
        s_mgr.root = split_node_new_leaf(hwndTerm, id);
    } else {
        /* Replace root with a vertical split: old root | new terminal */
        SplitNode *newLeaf = split_node_new_leaf(hwndTerm, id);
        s_mgr.root = split_node_new_split(SPLIT_VERTICAL, s_mgr.root, newLeaf);
    }

    s_mgr.focusedTerm = hwndTerm;
    do_layout();
    SetFocus(hwndTerm);
}

static void close_terminal_by_id(int terminalId) {
    if (!s_mgr.root) return;
    int total = split_node_count_leaves(s_mgr.root);
    if (total <= 1) return;  /* Keep at least one terminal */

    /* Find terminal HWND by id */
    HWND targets[MAX_TERMINALS]; int cnt = 0;
    split_node_collect_terminals(s_mgr.root, targets, &cnt, MAX_TERMINALS);

    HWND target = NULL;
    for (int i = 0; i < cnt; i++) {
        TerminalView *tv = terminal_view_from_hwnd(targets[i]);
        if (tv && tv->id == terminalId) { target = targets[i]; break; }
    }
    if (!target) return;

    SplitNode *leaf = split_node_find_leaf(s_mgr.root, target);
    if (!leaf) return;

    if (s_mgr.root == leaf) {
        /* Shouldn't happen since total > 1, but safety */
        return;
    }

    SplitNode *parent = split_node_find_parent(s_mgr.root, leaf);
    if (!parent) return;

    /* Determine sibling */
    SplitNode *sibling = (parent->first == leaf) ? parent->second : parent->first;

    /* Replace parent with sibling in the tree */
    SplitNode *grandparent = split_node_find_parent(s_mgr.root, parent);
    if (grandparent) {
        if (grandparent->first == parent) grandparent->first = sibling;
        else grandparent->second = sibling;
    } else {
        /* parent IS root */
        s_mgr.root = sibling;
    }

    /* Free the orphaned parent (children nulled so sibling subtree is not freed) */
    parent->first = NULL;
    parent->second = NULL;
    split_node_free(parent);
    /* Free the leaf node itself */
    free(leaf);

    /* Destroy terminal window */
    DestroyWindow(target);

    /* Update focus */
    if (s_mgr.focusedTerm == target) {
        HWND newTargets[MAX_TERMINALS]; int nc = 0;
        split_node_collect_terminals(s_mgr.root, newTargets, &nc, MAX_TERMINALS);
        s_mgr.focusedTerm = (nc > 0) ? newTargets[0] : NULL;
    }

    do_layout();
    if (s_mgr.focusedTerm) SetFocus(s_mgr.focusedTerm);
    InvalidateRect(s_mgr.hwndContainer, NULL, TRUE);
}

void terminal_mgr_close_active(void) {
    if (!s_mgr.focusedTerm) return;
    TerminalView *tv = terminal_view_from_hwnd(s_mgr.focusedTerm);
    if (tv) close_terminal_by_id(tv->id);
}

void terminal_mgr_close_tab(int index) {
    /* index is treated as terminal ID */
    close_terminal_by_id(index);
}

void terminal_mgr_split_vertical(void) {
    do_split(SPLIT_VERTICAL);
}

void terminal_mgr_split_horizontal(void) {
    do_split(SPLIT_HORIZONTAL);
}

int terminal_mgr_count(void) {
    return split_node_count_leaves(s_mgr.root);
}

void terminal_mgr_set_env(const wchar_t *envBlock) {
    if (envBlock)
        wcsncpy(s_mgr.envBlock, envBlock, 8191);
    else
        s_mgr.envBlock[0] = L'\0';
}

void terminal_mgr_update_all_fonts(void) {
    if (!s_mgr.root) return;
    HWND terms[MAX_TERMINALS];
    int count = 0;
    split_node_collect_terminals(s_mgr.root, terms, &count, MAX_TERMINALS);
    for (int i = 0; i < count; i++) {
        TerminalView *tv = terminal_view_from_hwnd(terms[i]);
        if (tv) terminal_view_set_font(tv, NULL, g_app.terminalFontSize);
    }
}

void terminal_mgr_destroy_all(void) {
    if (s_mgr.root) {
        HWND terms[MAX_TERMINALS];
        int count = 0;
        split_node_collect_terminals(s_mgr.root, terms, &count, MAX_TERMINALS);
        for (int i = 0; i < count; i++)
            if (terms[i]) DestroyWindow(terms[i]);
        split_node_free(s_mgr.root);
        s_mgr.root = NULL;
    }
    s_mgr.focusedTerm = NULL;
}
