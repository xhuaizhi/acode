#ifndef ACODE_TERMINAL_VIEW_H
#define ACODE_TERMINAL_VIEW_H

#include <windows.h>
#include <stdbool.h>
#include "conpty.h"

#define TERM_MAX_COLS  512
#define TERM_MAX_ROWS  256

/* Inner padding matching Mac SwiftTerminalView (hPadding=12, vPadding=6) */
#define TERM_PAD_H     12
#define TERM_PAD_V     6

/* Terminal cell attributes */
typedef struct {
    COLORREF fg;
    COLORREF bg;
    bool     bold;
    bool     italic;
    bool     underline;
    bool     inverse;
} CellAttr;

typedef struct {
    wchar_t  ch;
    CellAttr attr;
    bool     isWide;      /* first cell of a CJK double-width character */
    bool     isCont;      /* continuation cell (second half of wide char) */
} TermCell;

typedef struct TerminalView {
    HWND        hwnd;
    ConPTY      pty;

    /* Screen buffer */
    TermCell   *cells;
    int         cols;
    int         rows;
    int         cursorX;
    int         cursorY;
    bool        cursorVisible;

    /* Scroll */
    int         scrollback;
    int         scrollOffset;

    /* Font metrics */
    int         cellWidth;
    int         cellHeight;
    wchar_t     fontFace[64];
    int         fontSize;

    /* Cached GDI fonts (avoid per-paint creation) */
    HFONT       fontNormal;
    HFONT       fontBold;
    int         fontCacheSize;   /* fontSize when fonts were last created */

    /* ANSI parser state */
    int         parseState;
    char        escBuf[256];
    int         escLen;

    /* UTF-8 accumulator */
    unsigned char utf8Buf[6];
    int         utf8Len;
    int         utf8Need;   /* total bytes expected for current sequence */

    /* Current rendering attributes (modified by SGR) */
    CellAttr    curAttr;
    /* Base attributes (what SGR 0 resets to - theme default fg/bg) */
    CellAttr    baseAttr;

    /* 256-color palette */
    COLORREF    palette256[256];

    /* Text selection */
    int         selStartCol, selStartRow;
    int         selEndCol,   selEndRow;
    bool        selecting;
    bool        hasSelection;

    /* Title */
    wchar_t     title[256];

    /* ID for tab management */
    int         id;
} TerminalView;

bool terminal_view_register(HINSTANCE hInstance);
HWND terminal_view_create(HWND parent, HINSTANCE hInstance, int id);
TerminalView *terminal_view_from_hwnd(HWND hwnd);
void terminal_view_set_font(TerminalView *tv, const wchar_t *face, int size);
void terminal_view_recalc_size(TerminalView *tv);

#endif /* ACODE_TERMINAL_VIEW_H */
