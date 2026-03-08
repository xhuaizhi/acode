#ifndef ACODE_EDITOR_VIEW_H
#define ACODE_EDITOR_VIEW_H

#include <windows.h>
#include <stdbool.h>
#include "text_buffer.h"
#include "syntax.h"

typedef struct EditorView {
    HWND            hwnd;
    TextBuffer      buffer;
    UndoManager     undo;
    SyntaxLanguage  language;
    SyntaxResult    syntaxCache;

    /* Cursor */
    int     cursorPos;
    int     selStart;
    int     selEnd;

    /* Scroll */
    int     scrollY;
    int     scrollX;
    int     visibleLines;

    /* Font */
    wchar_t fontFace[64];
    int     fontSize;
    int     charWidth;
    int     lineHeight;
    HFONT   fontCache;
    int     fontCacheSize;  /* fontSize when fontCache was last created */

    /* Gutter */
    int     gutterWidth;

    /* State */
    bool    modified;
    bool    hasFocus;
    wchar_t filePath[MAX_PATH];

    /* Find */
    wchar_t findText[256];
    bool    findActive;
} EditorView;

bool editor_view_register(HINSTANCE hInstance);
HWND editor_view_create(HWND parent, HINSTANCE hInstance);
EditorView *editor_view_from_hwnd(HWND hwnd);
void editor_view_load_file(EditorView *ev, const wchar_t *path);
bool editor_view_save(EditorView *ev);
void editor_view_set_text(EditorView *ev, const wchar_t *text);

#endif /* ACODE_EDITOR_VIEW_H */
