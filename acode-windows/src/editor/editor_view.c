#include "editor_view.h"
#include "../app.h"
#include "../utils/theme.h"
#include "../utils/wstr.h"
#include <stdlib.h>
#include <stdio.h>
#include <windowsx.h>

#define EDITOR_CLASS L"ACodeEditorView"
#define GUTTER_PADDING 12
#define MAX_FILE_SIZE (10 * 1024 * 1024)

static void update_gutter_width(EditorView *ev) {
    int lineCount = tb_line_count(&ev->buffer);
    int digits = 1;
    int n = lineCount;
    while (n >= 10) { digits++; n /= 10; }
    if (digits < 3) digits = 3;
    ev->gutterWidth = digits * ev->charWidth + GUTTER_PADDING * 2;
}

static void update_syntax(EditorView *ev) {
    syntax_result_free(&ev->syntaxCache);
    wchar_t *text = tb_to_string(&ev->buffer);
    if (text) {
        syntax_highlight(text, tb_length(&ev->buffer), ev->language, &ev->syntaxCache);
        free(text);
    }
}

static COLORREF get_token_color(TokenType type, bool dark) {
    const ThemeColors *c = theme_get_colors(dark);
    switch (type) {
    case TOKEN_KEYWORD:  return c->synKeyword;
    case TOKEN_TYPE:     return c->synType;
    case TOKEN_STRING:   return c->synString;
    case TOKEN_NUMBER:   return c->synNumber;
    case TOKEN_COMMENT:  return c->synComment;
    case TOKEN_FUNCTION: return c->synFunction;
    default:             return c->text;
    }
}

static TokenType token_at_pos(const SyntaxResult *sr, int pos) {
    for (int i = 0; i < sr->count; i++) {
        if (pos >= sr->tokens[i].start && pos < sr->tokens[i].start + sr->tokens[i].length)
            return sr->tokens[i].type;
    }
    return TOKEN_NORMAL;
}

static void on_paint(HWND hwnd, EditorView *ev) {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(hwnd, &ps);

    const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);
    RECT rc;
    GetClientRect(hwnd, &rc);

    /* Double buffer */
    HDC memDC = CreateCompatibleDC(hdc);
    HBITMAP memBmp = CreateCompatibleBitmap(hdc, rc.right, rc.bottom);
    SelectObject(memDC, memBmp);

    /* Background */
    HBRUSH bgBrush = CreateSolidBrush(colors->background);
    FillRect(memDC, &rc, bgBrush);
    DeleteObject(bgBrush);

    /* Font (cached) */
    if (!ev->fontCache || ev->fontCacheSize != ev->fontSize) {
        if (ev->fontCache) DeleteObject(ev->fontCache);
        ev->fontCache = CreateFontW(
            ev->fontSize, 0, 0, 0, FW_NORMAL, FALSE, FALSE, FALSE,
            DEFAULT_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS,
            CLEARTYPE_QUALITY, FIXED_PITCH | FF_MODERN, ev->fontFace
        );
        ev->fontCacheSize = ev->fontSize;
    }
    HFONT oldFont = SelectObject(memDC, ev->fontCache);

    TEXTMETRICW tm;
    GetTextMetricsW(memDC, &tm);
    ev->charWidth = tm.tmAveCharWidth;
    ev->lineHeight = tm.tmHeight;
    ev->visibleLines = rc.bottom / ev->lineHeight + 1;

    update_gutter_width(ev);

    /* Gutter background */
    RECT gutterRect = { 0, 0, ev->gutterWidth, rc.bottom };
    HBRUSH gutterBrush = CreateSolidBrush(colors->surface);
    FillRect(memDC, &gutterRect, gutterBrush);
    DeleteObject(gutterBrush);

    /* Gutter separator */
    HPEN sepPen = CreatePen(PS_SOLID, 1, colors->border);
    HPEN oldPen = SelectObject(memDC, sepPen);
    MoveToEx(memDC, ev->gutterWidth - 1, 0, NULL);
    LineTo(memDC, ev->gutterWidth - 1, rc.bottom);
    SelectObject(memDC, oldPen);
    DeleteObject(sepPen);

    int totalLines = tb_line_count(&ev->buffer);
    int startLine = ev->scrollY;
    int endLine = startLine + ev->visibleLines;
    if (endLine > totalLines) endLine = totalLines;

    int cursorLine = tb_line_of_pos(&ev->buffer, ev->cursorPos);

    SetBkMode(memDC, TRANSPARENT);

    for (int line = startLine; line < endLine; line++) {
        int y = (line - startLine) * ev->lineHeight;

        /* Highlight current line */
        if (line == cursorLine && ev->hasFocus) {
            RECT lineRect = { ev->gutterWidth, y, rc.right, y + ev->lineHeight };
            HBRUSH hlBrush = CreateSolidBrush(colors->surfaceAlt);
            FillRect(memDC, &lineRect, hlBrush);
            DeleteObject(hlBrush);
        }

        /* Line number */
        wchar_t numBuf[16];
        _snwprintf(numBuf, 16, L"%d", line + 1);
        RECT numRect = { 0, y, ev->gutterWidth - GUTTER_PADDING, y + ev->lineHeight };
        SetTextColor(memDC, line == cursorLine ? colors->text : colors->textSecondary);
        DrawTextW(memDC, numBuf, -1, &numRect, DT_RIGHT | DT_VCENTER | DT_SINGLELINE);

        /* Line content with syntax coloring */
        wchar_t lineBuf[4096];
        tb_get_line(&ev->buffer, line, lineBuf, 4096);
        int lineStart = tb_line_start(&ev->buffer, line);
        int lineLen = (int)wcslen(lineBuf);

        int x = ev->gutterWidth + 4 - ev->scrollX;
        for (int col = 0; col < lineLen; col++) {
            if (lineBuf[col] == L'\t') {
                x += ev->charWidth * 4;
                continue;
            }

            TokenType tt = token_at_pos(&ev->syntaxCache, lineStart + col);
            COLORREF clr = get_token_color(tt, g_app.isDarkMode);
            SetTextColor(memDC, clr);

            TextOutW(memDC, x, y, &lineBuf[col], 1);
            x += ev->charWidth;
        }
    }

    /* Draw cursor */
    if (ev->hasFocus) {
        int cLine = cursorLine - startLine;
        int cCol = ev->cursorPos - tb_line_start(&ev->buffer, cursorLine);
        int cx = ev->gutterWidth + 4 - ev->scrollX + cCol * ev->charWidth;
        int cy = cLine * ev->lineHeight;

        if (cy >= 0 && cy < rc.bottom) {
            HPEN curPen = CreatePen(PS_SOLID, 2, colors->accent);
            HPEN prevPen = SelectObject(memDC, curPen);
            MoveToEx(memDC, cx, cy, NULL);
            LineTo(memDC, cx, cy + ev->lineHeight);
            SelectObject(memDC, prevPen);
            DeleteObject(curPen);
        }
    }

    SelectObject(memDC, oldFont);

    BitBlt(hdc, 0, 0, rc.right, rc.bottom, memDC, 0, 0, SRCCOPY);
    DeleteObject(memBmp);
    DeleteDC(memDC);

    EndPaint(hwnd, &ps);
}

static void ensure_cursor_visible(EditorView *ev) {
    int line = tb_line_of_pos(&ev->buffer, ev->cursorPos);
    if (line < ev->scrollY) ev->scrollY = line;
    if (line >= ev->scrollY + ev->visibleLines - 1)
        ev->scrollY = line - ev->visibleLines + 2;
    if (ev->scrollY < 0) ev->scrollY = 0;
}

static void handle_key(EditorView *ev, WPARAM vk) {
    bool ctrl = GetKeyState(VK_CONTROL) & 0x8000;
    bool shift = GetKeyState(VK_SHIFT) & 0x8000;
    int total = tb_length(&ev->buffer);

    if (ctrl && vk == 'S') {
        editor_view_save(ev);
        return;
    }
    if (ctrl && vk == 'Z') {
        if (undo_perform(&ev->undo, &ev->buffer)) {
            update_syntax(ev);
            InvalidateRect(ev->hwnd, NULL, FALSE);
        }
        return;
    }
    if (ctrl && vk == 'Y') {
        if (redo_perform(&ev->undo, &ev->buffer)) {
            update_syntax(ev);
            InvalidateRect(ev->hwnd, NULL, FALSE);
        }
        return;
    }
    if (ctrl && vk == 'A') {
        ev->selStart = 0;
        ev->selEnd = total;
        ev->cursorPos = total;
        InvalidateRect(ev->hwnd, NULL, FALSE);
        return;
    }

    switch (vk) {
    case VK_LEFT:
        if (ev->cursorPos > 0) ev->cursorPos--;
        break;
    case VK_RIGHT:
        if (ev->cursorPos < total) ev->cursorPos++;
        break;
    case VK_UP: {
        int line = tb_line_of_pos(&ev->buffer, ev->cursorPos);
        if (line > 0) {
            int col = ev->cursorPos - tb_line_start(&ev->buffer, line);
            int prevStart = tb_line_start(&ev->buffer, line - 1);
            int prevLen = tb_line_length(&ev->buffer, line - 1);
            ev->cursorPos = prevStart + (col < prevLen ? col : prevLen);
        }
        break;
    }
    case VK_DOWN: {
        int line = tb_line_of_pos(&ev->buffer, ev->cursorPos);
        int lineCount = tb_line_count(&ev->buffer);
        if (line < lineCount - 1) {
            int col = ev->cursorPos - tb_line_start(&ev->buffer, line);
            int nextStart = tb_line_start(&ev->buffer, line + 1);
            int nextLen = tb_line_length(&ev->buffer, line + 1);
            ev->cursorPos = nextStart + (col < nextLen ? col : nextLen);
        }
        break;
    }
    case VK_HOME: {
        int line = tb_line_of_pos(&ev->buffer, ev->cursorPos);
        ev->cursorPos = tb_line_start(&ev->buffer, line);
        break;
    }
    case VK_END: {
        int line = tb_line_of_pos(&ev->buffer, ev->cursorPos);
        ev->cursorPos = tb_line_start(&ev->buffer, line) + tb_line_length(&ev->buffer, line);
        break;
    }
    case VK_PRIOR: /* Page Up */
        ev->scrollY -= ev->visibleLines;
        if (ev->scrollY < 0) ev->scrollY = 0;
        break;
    case VK_NEXT: /* Page Down */
        ev->scrollY += ev->visibleLines;
        break;
    case VK_DELETE:
        if (ev->cursorPos < total) {
            wchar_t ch = tb_char_at(&ev->buffer, ev->cursorPos);
            undo_record_delete(&ev->undo, ev->cursorPos, &ch, 1);
            tb_delete(&ev->buffer, ev->cursorPos, 1);
            ev->modified = true;
            update_syntax(ev);
        }
        break;
    case VK_BACK:
        if (ev->cursorPos > 0) {
            ev->cursorPos--;
            wchar_t ch = tb_char_at(&ev->buffer, ev->cursorPos);
            undo_record_delete(&ev->undo, ev->cursorPos, &ch, 1);
            tb_delete(&ev->buffer, ev->cursorPos, 1);
            ev->modified = true;
            update_syntax(ev);
        }
        break;
    case VK_RETURN: {
        wchar_t nl = L'\n';
        undo_record_insert(&ev->undo, ev->cursorPos, &nl, 1);
        tb_insert(&ev->buffer, ev->cursorPos, L'\n');
        ev->cursorPos++;
        ev->modified = true;
        update_syntax(ev);
        break;
    }
    case VK_TAB: {
        wchar_t spaces[] = L"    ";
        undo_record_insert(&ev->undo, ev->cursorPos, spaces, 4);
        tb_insert_text(&ev->buffer, ev->cursorPos, spaces, 4);
        ev->cursorPos += 4;
        ev->modified = true;
        update_syntax(ev);
        break;
    }
    }

    ensure_cursor_visible(ev);
    InvalidateRect(ev->hwnd, NULL, FALSE);
}

static void handle_char(EditorView *ev, wchar_t ch) {
    if (ch < 0x20 && ch != L'\t' && ch != L'\r' && ch != L'\n') return;
    if (ch == L'\r') return;

    undo_record_insert(&ev->undo, ev->cursorPos, &ch, 1);
    tb_insert(&ev->buffer, ev->cursorPos, ch);
    ev->cursorPos++;
    ev->modified = true;
    update_syntax(ev);
    ensure_cursor_visible(ev);
    InvalidateRect(ev->hwnd, NULL, FALSE);
}

static void handle_mousewheel(EditorView *ev, short delta) {
    int lines = delta / 120 * 3;
    ev->scrollY -= lines;
    if (ev->scrollY < 0) ev->scrollY = 0;
    int maxScroll = tb_line_count(&ev->buffer) - ev->visibleLines + 1;
    if (maxScroll < 0) maxScroll = 0;
    if (ev->scrollY > maxScroll) ev->scrollY = maxScroll;
    InvalidateRect(ev->hwnd, NULL, FALSE);
}

static void handle_lbuttondown(EditorView *ev, int x, int y) {
    SetFocus(ev->hwnd);
    if (x < ev->gutterWidth) return;

    int line = ev->scrollY + y / ev->lineHeight;
    int col = (x - ev->gutterWidth - 4 + ev->scrollX) / ev->charWidth;
    if (col < 0) col = 0;

    int lineCount = tb_line_count(&ev->buffer);
    if (line >= lineCount) line = lineCount - 1;
    if (line < 0) line = 0;

    int lineStart = tb_line_start(&ev->buffer, line);
    int lineLen = tb_line_length(&ev->buffer, line);
    if (col > lineLen) col = lineLen;

    ev->cursorPos = lineStart + col;
    ev->selStart = ev->selEnd = ev->cursorPos;
    InvalidateRect(ev->hwnd, NULL, FALSE);
}

static LRESULT CALLBACK editor_wnd_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    EditorView *ev = (EditorView *)GetWindowLongPtrW(hwnd, GWLP_USERDATA);

    switch (msg) {
    case WM_CREATE: {
        CREATESTRUCTW *cs = (CREATESTRUCTW *)lParam;
        ev = (EditorView *)cs->lpCreateParams;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)ev);
        ev->hwnd = hwnd;
        return 0;
    }
    case WM_PAINT:
        if (ev) on_paint(hwnd, ev);
        else { PAINTSTRUCT ps; BeginPaint(hwnd, &ps); EndPaint(hwnd, &ps); }
        return 0;
    case WM_ERASEBKGND:
        return 1;
    case WM_KEYDOWN:
        if (ev) handle_key(ev, wParam);
        return 0;
    case WM_CHAR:
        if (ev) handle_char(ev, (wchar_t)wParam);
        return 0;
    case WM_MOUSEWHEEL:
        if (ev) handle_mousewheel(ev, GET_WHEEL_DELTA_WPARAM(wParam));
        return 0;
    case WM_LBUTTONDOWN:
        if (ev) handle_lbuttondown(ev, GET_X_LPARAM(lParam), GET_Y_LPARAM(lParam));
        return 0;
    case WM_SETFOCUS:
        if (ev) { ev->hasFocus = true; InvalidateRect(hwnd, NULL, FALSE); }
        return 0;
    case WM_KILLFOCUS:
        if (ev) { ev->hasFocus = false; InvalidateRect(hwnd, NULL, FALSE); }
        return 0;
    case WM_DESTROY:
        if (ev) {
            if (ev->fontCache) DeleteObject(ev->fontCache);
            tb_free(&ev->buffer);
            undo_free(&ev->undo);
            syntax_result_free(&ev->syntaxCache);
            free(ev);
        }
        return 0;
    }

    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

bool editor_view_register(HINSTANCE hInstance) {
    WNDCLASSEXW wc = {
        .cbSize = sizeof(WNDCLASSEXW),
        .style = CS_HREDRAW | CS_VREDRAW,
        .lpfnWndProc = editor_wnd_proc,
        .hInstance = hInstance,
        .hCursor = LoadCursor(NULL, IDC_IBEAM),
        .hbrBackground = NULL,
        .lpszClassName = EDITOR_CLASS,
    };
    return RegisterClassExW(&wc) != 0;
}

HWND editor_view_create(HWND parent, HINSTANCE hInstance) {
    EditorView *ev = (EditorView *)calloc(1, sizeof(EditorView));
    if (!ev) return NULL;

    tb_init(&ev->buffer, 4096);
    undo_init(&ev->undo);
    ev->fontSize = g_app.editorFontSize;
    wcscpy(ev->fontFace, L"Cascadia Mono");
    ev->charWidth = 8;
    ev->lineHeight = 18;
    ev->gutterWidth = 48;

    return CreateWindowExW(
        0, EDITOR_CLASS, NULL,
        WS_CHILD | WS_VISIBLE | WS_TABSTOP,
        0, 0, 100, 100,
        parent, NULL, hInstance, ev
    );
}

EditorView *editor_view_from_hwnd(HWND hwnd) {
    return (EditorView *)GetWindowLongPtrW(hwnd, GWLP_USERDATA);
}

void editor_view_load_file(EditorView *ev, const wchar_t *path) {
    if (!ev || !path) return;

    char pathUtf8[MAX_PATH * 2];
    wstr_to_utf8(path, pathUtf8, sizeof(pathUtf8));

    FILE *f = fopen(pathUtf8, "rb");
    if (!f) return;

    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);

    if (size <= 0 || size > MAX_FILE_SIZE) {
        fclose(f);
        return;
    }

    char *utf8 = (char *)malloc(size + 1);
    if (!utf8) { fclose(f); return; }
    size_t bytesRead = fread(utf8, 1, size, f);
    fclose(f);
    if ((long)bytesRead != size) { free(utf8); return; }
    utf8[size] = '\0';

    wchar_t *wtext = wstr_from_utf8_alloc(utf8);
    free(utf8);

    if (wtext) {
        tb_set_text(&ev->buffer, wtext);
        free(wtext);
    }

    wcscpy(ev->filePath, path);
    ev->language = syntax_detect_language(path);
    ev->modified = false;
    ev->cursorPos = 0;
    ev->scrollY = 0;

    undo_free(&ev->undo);
    undo_init(&ev->undo);
    update_syntax(ev);
    InvalidateRect(ev->hwnd, NULL, FALSE);
}

bool editor_view_save(EditorView *ev) {
    if (!ev || !ev->filePath[0]) return false;

    wchar_t *text = tb_to_string(&ev->buffer);
    if (!text) return false;

    char *utf8 = wstr_to_utf8_alloc(text);
    free(text);
    if (!utf8) return false;

    char pathUtf8[MAX_PATH * 2];
    wstr_to_utf8(ev->filePath, pathUtf8, sizeof(pathUtf8));

    FILE *f = fopen(pathUtf8, "wb");
    if (!f) { free(utf8); return false; }

    fwrite(utf8, 1, strlen(utf8), f);
    fclose(f);
    free(utf8);

    ev->modified = false;
    InvalidateRect(ev->hwnd, NULL, FALSE);
    return true;
}

void editor_view_set_text(EditorView *ev, const wchar_t *text) {
    if (!ev) return;
    tb_set_text(&ev->buffer, text);
    ev->cursorPos = 0;
    ev->scrollY = 0;
    ev->modified = false;
    undo_free(&ev->undo);
    undo_init(&ev->undo);
    update_syntax(ev);
    InvalidateRect(ev->hwnd, NULL, FALSE);
}
