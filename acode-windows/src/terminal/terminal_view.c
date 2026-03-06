#include "terminal_view.h"
#include "../app.h"
#include "../utils/theme.h"
#include "../utils/wstr.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

#define TERM_CLASS L"ACodeTerminalView"
#define CURSOR_BLINK_MS 600

/* ---- CJK / East-Asian width detection ---- */
static int term_wcwidth(wchar_t c) {
    if (c == 0) return 0;
    if (c < 0x20 || (c >= 0x7f && c < 0xa0)) return -1;

    /* CJK Unified Ideographs + Extensions */
    if ((c >= 0x1100 && c <= 0x115f)   ||  /* Hangul Jamo */
        c == 0x2329 || c == 0x232a     ||
        (c >= 0x2e80 && c <= 0x303e)   ||  /* CJK Radicals..Ideographic Description */
        (c >= 0x3040 && c <= 0x33bf)   ||  /* Hiragana..CJK Compatibility */
        (c >= 0x3400 && c <= 0x4dbf)   ||  /* CJK Unified Ext A */
        (c >= 0x4e00 && c <= 0xa4cf)   ||  /* CJK Unified..Yi Radicals */
        (c >= 0xa960 && c <= 0xa97c)   ||  /* Hangul Jamo Extended-A */
        (c >= 0xac00 && c <= 0xd7a3)   ||  /* Hangul Syllables */
        (c >= 0xf900 && c <= 0xfaff)   ||  /* CJK Compatibility Ideographs */
        (c >= 0xfe10 && c <= 0xfe6f)   ||  /* Vertical forms..Small Form Variants */
        (c >= 0xff01 && c <= 0xff60)   ||  /* Fullwidth Forms */
        (c >= 0xffe0 && c <= 0xffe6))      /* Fullwidth Signs */
        return 2;

    return 1;
}

/* ---- UTF-8 sequence length from leading byte ---- */
static int utf8_seq_len(unsigned char b) {
    if (b < 0x80) return 1;
    if ((b & 0xe0) == 0xc0) return 2;
    if ((b & 0xf0) == 0xe0) return 3;
    if ((b & 0xf8) == 0xf0) return 4;
    return 1; /* invalid, treat as single byte */
}

static void init_256_palette(TerminalView *tv) {
    const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);
    for (int i = 0; i < 16; i++)
        tv->palette256[i] = colors->termColors[i];

    for (int r = 0; r < 6; r++)
        for (int g = 0; g < 6; g++)
            for (int b = 0; b < 6; b++) {
                int idx = 16 + r * 36 + g * 6 + b;
                tv->palette256[idx] = RGB(r ? 55+r*40 : 0, g ? 55+g*40 : 0, b ? 55+b*40 : 0);
            }

    for (int i = 0; i < 24; i++) {
        int v = 8 + i * 10;
        tv->palette256[232 + i] = RGB(v, v, v);
    }
}

static void alloc_cells(TerminalView *tv) {
    if (tv->cells) free(tv->cells);
    tv->cells = (TermCell *)calloc(tv->cols * tv->rows, sizeof(TermCell));
    if (tv->cells) {
        for (int i = 0; i < tv->cols * tv->rows; i++) {
            tv->cells[i].ch = L' ';
            tv->cells[i].attr = tv->baseAttr;
        }
    }
}

static TermCell *cell_at(TerminalView *tv, int col, int row) {
    if (col < 0 || col >= tv->cols || row < 0 || row >= tv->rows) return NULL;
    return &tv->cells[row * tv->cols + col];
}

static void scroll_up(TerminalView *tv) {
    memmove(tv->cells, tv->cells + tv->cols, (tv->rows - 1) * tv->cols * sizeof(TermCell));
    for (int c = 0; c < tv->cols; c++) {
        TermCell *cell = &tv->cells[(tv->rows - 1) * tv->cols + c];
        cell->ch = L' ';
        cell->attr = tv->baseAttr;
        cell->isWide = false;
        cell->isCont = false;
    }
}

static void clear_cell(TerminalView *tv, TermCell *cell) {
    cell->ch = L' ';
    cell->attr = tv->baseAttr;
    cell->isWide = false;
    cell->isCont = false;
}

/* Put a decoded wchar_t at cursor position with CJK width handling */
static void put_char(TerminalView *tv, wchar_t wc) {
    int w = term_wcwidth(wc);
    if (w <= 0) w = 1;

    /* If wide char would overflow the line, wrap first */
    if (w == 2 && tv->cursorX >= tv->cols - 1) {
        TermCell *cell = cell_at(tv, tv->cursorX, tv->cursorY);
        if (cell) clear_cell(tv, cell);
        tv->cursorX = 0;
        tv->cursorY++;
        if (tv->cursorY >= tv->rows) {
            scroll_up(tv);
            tv->cursorY = tv->rows - 1;
        }
    }

    TermCell *cell = cell_at(tv, tv->cursorX, tv->cursorY);
    if (cell) {
        cell->ch = wc;
        cell->attr = tv->curAttr;
        cell->isWide = (w == 2);
        cell->isCont = false;
    }
    tv->cursorX++;

    if (w == 2 && tv->cursorX < tv->cols) {
        TermCell *cont = cell_at(tv, tv->cursorX, tv->cursorY);
        if (cont) {
            cont->ch = L' ';
            cont->attr = tv->curAttr;
            cont->isWide = false;
            cont->isCont = true;
        }
        tv->cursorX++;
    }

    if (tv->cursorX >= tv->cols) {
        tv->cursorX = 0;
        tv->cursorY++;
        if (tv->cursorY >= tv->rows) {
            scroll_up(tv);
            tv->cursorY = tv->rows - 1;
        }
    }
}

/* ---- SGR handler ---- */
static void handle_sgr(TerminalView *tv, int *params, int paramCount) {
    for (int i = 0; i < paramCount; i++) {
        int p = params[i];
        if (p == 0) {
            tv->curAttr = tv->baseAttr;
        } else if (p == 1) { tv->curAttr.bold = true;
        } else if (p == 2) { tv->curAttr.bold = false;
        } else if (p == 3) { tv->curAttr.italic = true;
        } else if (p == 4) { tv->curAttr.underline = true;
        } else if (p == 7) { tv->curAttr.inverse = true;
        } else if (p == 22) { tv->curAttr.bold = false;
        } else if (p == 23) { tv->curAttr.italic = false;
        } else if (p == 24) { tv->curAttr.underline = false;
        } else if (p == 27) { tv->curAttr.inverse = false;
        } else if (p >= 30 && p <= 37) {
            int idx = p - 30;
            tv->curAttr.fg = tv->curAttr.bold ? tv->palette256[idx + 8] : tv->palette256[idx];
        } else if (p == 38) {
            if (i+1 < paramCount && params[i+1] == 5 && i+2 < paramCount) {
                int n = params[i+2];
                if (n >= 0 && n <= 255) tv->curAttr.fg = tv->palette256[n];
                i += 2;
            } else if (i+1 < paramCount && params[i+1] == 2 && i+4 < paramCount) {
                int r = params[i+2], g = params[i+3], b = params[i+4];
                if (r<0)r=0;if(r>255)r=255;if(g<0)g=0;if(g>255)g=255;if(b<0)b=0;if(b>255)b=255;
                tv->curAttr.fg = RGB(r, g, b);
                i += 4;
            }
        } else if (p == 39) { tv->curAttr.fg = tv->baseAttr.fg;
        } else if (p >= 40 && p <= 47) { tv->curAttr.bg = tv->palette256[p - 40];
        } else if (p == 48) {
            if (i+1 < paramCount && params[i+1] == 5 && i+2 < paramCount) {
                int n = params[i+2];
                if (n >= 0 && n <= 255) tv->curAttr.bg = tv->palette256[n];
                i += 2;
            } else if (i+1 < paramCount && params[i+1] == 2 && i+4 < paramCount) {
                int r = params[i+2], g = params[i+3], b = params[i+4];
                if (r<0)r=0;if(r>255)r=255;if(g<0)g=0;if(g>255)g=255;if(b<0)b=0;if(b>255)b=255;
                tv->curAttr.bg = RGB(r, g, b);
                i += 4;
            }
        } else if (p == 49) { tv->curAttr.bg = tv->baseAttr.bg;
        } else if (p >= 90 && p <= 97) { tv->curAttr.fg = tv->palette256[p - 90 + 8];
        } else if (p >= 100 && p <= 107) { tv->curAttr.bg = tv->palette256[p - 100 + 8];
        }
    }
}

/* ---- ANSI escape sequence parser ---- */
static void process_char(TerminalView *tv, unsigned char ch) {
    /* UTF-8 accumulation: if we're in the middle of a multi-byte sequence */
    if (tv->utf8Len > 0) {
        if ((ch & 0xc0) == 0x80) {
            tv->utf8Buf[tv->utf8Len++] = ch;
            if (tv->utf8Len >= tv->utf8Need) {
                wchar_t wc = 0;
                int n = MultiByteToWideChar(CP_UTF8, 0, (char *)tv->utf8Buf, tv->utf8Len, &wc, 1);
                tv->utf8Len = 0;
                if (n == 1) put_char(tv, wc);
            }
            return;
        }
        /* Invalid continuation: discard buffer, fall through to process this byte fresh */
        tv->utf8Len = 0;
    }

    /* ESC received */
    if (tv->parseState == 1) {
        tv->escBuf[tv->escLen++] = (char)ch;
        if (tv->escLen >= (int)sizeof(tv->escBuf) - 1) {
            tv->parseState = 0; tv->escLen = 0; return;
        }
        if (ch == '[') { tv->parseState = 2; return; }
        if (ch == ']') { tv->parseState = 3; return; }
        if (ch == '(') { tv->parseState = 4; return; }
        tv->parseState = 0; tv->escLen = 0; return;
    }

    if (tv->parseState == 4) { tv->parseState = 0; tv->escLen = 0; return; }

    /* OSC */
    if (tv->parseState == 3) {
        if (ch == '\a' || (ch == '\\' && tv->escLen > 0 && tv->escBuf[tv->escLen-1] == '\x1b')) {
            tv->escBuf[tv->escLen] = '\0';
            const char *data = tv->escBuf + 1;
            if ((data[0] == '0' || data[0] == '2') && data[1] == ';')
                wstr_from_utf8(data + 2, tv->title, 256);
            tv->parseState = 0; tv->escLen = 0;
        } else {
            if (tv->escLen < (int)sizeof(tv->escBuf) - 1)
                tv->escBuf[tv->escLen++] = (char)ch;
            else { tv->parseState = 0; tv->escLen = 0; }
        }
        return;
    }

    /* CSI */
    if (tv->parseState == 2) {
        tv->escBuf[tv->escLen++] = (char)ch;
        if (tv->escLen >= (int)sizeof(tv->escBuf) - 1) {
            tv->parseState = 0; tv->escLen = 0; return;
        }
        bool isFinal = (ch >= 'A' && ch <= 'Z') || (ch >= 'a' && ch <= 'z') || ch == '@';
        if (!isFinal) return;

        tv->escBuf[tv->escLen] = '\0';
        const char *paramStart = tv->escBuf + 1;
        bool privateMode = false;
        if (*paramStart == '?') { privateMode = true; paramStart++; }

        int params[32] = {0};
        int paramCount = 0;
        const char *pp = paramStart;
        while (*pp && paramCount < 32) {
            if (*pp >= '0' && *pp <= '9')
                params[paramCount] = params[paramCount] * 10 + (*pp - '0');
            else if (*pp == ';')
                paramCount++;
            else break;
            pp++;
        }
        paramCount++;

        switch (ch) {
        case 'A': { int n = params[0]?params[0]:1; tv->cursorY -= n; if(tv->cursorY<0) tv->cursorY=0; break; }
        case 'B': { int n = params[0]?params[0]:1; tv->cursorY += n; if(tv->cursorY>=tv->rows) tv->cursorY=tv->rows-1; break; }
        case 'C': { int n = params[0]?params[0]:1; tv->cursorX += n; if(tv->cursorX>=tv->cols) tv->cursorX=tv->cols-1; break; }
        case 'D': { int n = params[0]?params[0]:1; tv->cursorX -= n; if(tv->cursorX<0) tv->cursorX=0; break; }
        case 'E': { int n = params[0]?params[0]:1; tv->cursorX=0; tv->cursorY+=n; if(tv->cursorY>=tv->rows) tv->cursorY=tv->rows-1; break; }
        case 'F': { int n = params[0]?params[0]:1; tv->cursorX=0; tv->cursorY-=n; if(tv->cursorY<0) tv->cursorY=0; break; }
        case 'G': { int n = params[0]?params[0]:1; tv->cursorX=n-1; if(tv->cursorX>=tv->cols) tv->cursorX=tv->cols-1; if(tv->cursorX<0) tv->cursorX=0; break; }
        case 'H': case 'f':
            tv->cursorY = (params[0]?params[0]-1:0);
            tv->cursorX = (paramCount>1&&params[1])?params[1]-1:0;
            if(tv->cursorY>=tv->rows) tv->cursorY=tv->rows-1;
            if(tv->cursorX>=tv->cols) tv->cursorX=tv->cols-1;
            if(tv->cursorY<0) tv->cursorY=0; if(tv->cursorX<0) tv->cursorX=0;
            break;
        case 'J': {
            int mode = params[0];
            if (mode == 0) {
                for (int c=tv->cursorX;c<tv->cols;c++) { TermCell *cl=cell_at(tv,c,tv->cursorY); if(cl)clear_cell(tv,cl); }
                for (int r=tv->cursorY+1;r<tv->rows;r++) for (int c=0;c<tv->cols;c++) { TermCell *cl=cell_at(tv,c,r); if(cl)clear_cell(tv,cl); }
            } else if (mode == 1) {
                for (int r=0;r<tv->cursorY;r++) for (int c=0;c<tv->cols;c++) { TermCell *cl=cell_at(tv,c,r); if(cl)clear_cell(tv,cl); }
                for (int c=0;c<=tv->cursorX;c++) { TermCell *cl=cell_at(tv,c,tv->cursorY); if(cl)clear_cell(tv,cl); }
            } else if (mode == 2 || mode == 3) {
                for (int i=0;i<tv->cols*tv->rows;i++) clear_cell(tv,&tv->cells[i]);
                tv->cursorX=0; tv->cursorY=0;
            }
            break;
        }
        case 'K': {
            int mode = params[0];
            if (mode==0) { for(int c=tv->cursorX;c<tv->cols;c++){TermCell *cl=cell_at(tv,c,tv->cursorY);if(cl)clear_cell(tv,cl);} }
            else if(mode==1) { for(int c=0;c<=tv->cursorX;c++){TermCell *cl=cell_at(tv,c,tv->cursorY);if(cl)clear_cell(tv,cl);} }
            else if(mode==2) { for(int c=0;c<tv->cols;c++){TermCell *cl=cell_at(tv,c,tv->cursorY);if(cl)clear_cell(tv,cl);} }
            break;
        }
        case 'L': {
            int n=params[0]?params[0]:1;
            for(int r=tv->rows-1;r>=tv->cursorY+n;r--) memcpy(&tv->cells[r*tv->cols],&tv->cells[(r-n)*tv->cols],tv->cols*sizeof(TermCell));
            for(int r=tv->cursorY;r<tv->cursorY+n&&r<tv->rows;r++) for(int c=0;c<tv->cols;c++) clear_cell(tv,cell_at(tv,c,r));
            break;
        }
        case 'M': {
            int n=params[0]?params[0]:1;
            for(int r=tv->cursorY;r<tv->rows-n;r++) memcpy(&tv->cells[r*tv->cols],&tv->cells[(r+n)*tv->cols],tv->cols*sizeof(TermCell));
            for(int r=tv->rows-n;r<tv->rows;r++) for(int c=0;c<tv->cols;c++) clear_cell(tv,cell_at(tv,c,r));
            break;
        }
        case 'P': {
            int n=params[0]?params[0]:1; int row=tv->cursorY;
            for(int c=tv->cursorX;c<tv->cols-n;c++) tv->cells[row*tv->cols+c]=tv->cells[row*tv->cols+c+n];
            for(int c=tv->cols-n;c<tv->cols;c++) clear_cell(tv,cell_at(tv,c,row));
            break;
        }
        case 'X': {
            int n=params[0]?params[0]:1;
            for(int c=tv->cursorX;c<tv->cursorX+n&&c<tv->cols;c++){TermCell *cl=cell_at(tv,c,tv->cursorY);if(cl)clear_cell(tv,cl);}
            break;
        }
        case 'd': { int n=params[0]?params[0]:1; tv->cursorY=n-1; if(tv->cursorY>=tv->rows) tv->cursorY=tv->rows-1; if(tv->cursorY<0) tv->cursorY=0; break; }
        case 'm': handle_sgr(tv, params, paramCount); break;
        case 'r': break;
        case 's': break;
        case 'u': break;
        case 'h':
            if (privateMode) {
                if (params[0]==25) tv->cursorVisible=true;
                if (params[0]==1049) { for(int i=0;i<tv->cols*tv->rows;i++) clear_cell(tv,&tv->cells[i]); tv->cursorX=0;tv->cursorY=0; }
            }
            break;
        case 'l':
            if (privateMode) {
                if (params[0]==25) tv->cursorVisible=false;
                if (params[0]==1049) { for(int i=0;i<tv->cols*tv->rows;i++) clear_cell(tv,&tv->cells[i]); tv->cursorX=0;tv->cursorY=0; }
            }
            break;
        case 'n':
            if (params[0]==6) { char reply[32]; int len=snprintf(reply,sizeof(reply),"\x1b[%d;%dR",tv->cursorY+1,tv->cursorX+1); if(len>0) conpty_write(&tv->pty,reply,len); }
            break;
        case '@': {
            int n=params[0]?params[0]:1; int row=tv->cursorY;
            for(int c=tv->cols-1;c>=tv->cursorX+n;c--) tv->cells[row*tv->cols+c]=tv->cells[row*tv->cols+c-n];
            for(int c=tv->cursorX;c<tv->cursorX+n&&c<tv->cols;c++) clear_cell(tv,cell_at(tv,c,row));
            break;
        }
        }
        tv->parseState = 0; tv->escLen = 0; return;
    }

    /* Normal character processing */
    switch (ch) {
    case '\x1b': tv->parseState = 1; tv->escLen = 0; break;
    case '\r':   tv->cursorX = 0; break;
    case '\n':
        tv->cursorY++;
        if (tv->cursorY >= tv->rows) { scroll_up(tv); tv->cursorY = tv->rows - 1; }
        break;
    case '\b':   if (tv->cursorX > 0) tv->cursorX--; break;
    case '\t': { int nt = (tv->cursorX/8+1)*8; if(nt>=tv->cols) nt=tv->cols-1; tv->cursorX=nt; break; }
    case '\a': break;
    case '\x0e': case '\x0f': break;
    default:
        if (ch >= 0x80) {
            /* Start of UTF-8 multi-byte sequence */
            tv->utf8Need = utf8_seq_len(ch);
            tv->utf8Buf[0] = ch;
            tv->utf8Len = 1;
            if (tv->utf8Need <= 1) {
                tv->utf8Len = 0;
                put_char(tv, (wchar_t)ch);
            } else if (tv->utf8Len >= tv->utf8Need) {
                wchar_t wc = 0;
                MultiByteToWideChar(CP_UTF8, 0, (char *)tv->utf8Buf, tv->utf8Len, &wc, 1);
                tv->utf8Len = 0;
                put_char(tv, wc);
            }
        } else if (ch >= 0x20) {
            put_char(tv, (wchar_t)ch);
        }
        break;
    }
}

static void on_pty_output(ConPTY *pty, const char *data, int len, void *ctx) {
    TerminalView *tv = (TerminalView *)ctx;
    for (int i = 0; i < len; i++)
        process_char(tv, (unsigned char)data[i]);
    PostMessage(tv->hwnd, WM_USER + 200, 0, 0);
}

/* ---- Selection helpers ---- */
static bool cell_in_selection(TerminalView *tv, int col, int row) {
    if (!tv->hasSelection) return false;
    int sr = tv->selStartRow, sc = tv->selStartCol;
    int er = tv->selEndRow, ec = tv->selEndCol;
    if (sr > er || (sr == er && sc > ec)) { int t; t=sr;sr=er;er=t; t=sc;sc=ec;ec=t; }
    int pos = row * tv->cols + col;
    int start = sr * tv->cols + sc;
    int end = er * tv->cols + ec;
    return pos >= start && pos <= end;
}

static void copy_selection_to_clipboard(TerminalView *tv) {
    if (!tv->hasSelection) return;
    int sr = tv->selStartRow, sc = tv->selStartCol;
    int er = tv->selEndRow, ec = tv->selEndCol;
    if (sr > er || (sr == er && sc > ec)) { int t; t=sr;sr=er;er=t; t=sc;sc=ec;ec=t; }

    int maxLen = (er - sr + 1) * (tv->cols + 2) + 1;
    wchar_t *buf = (wchar_t *)malloc(maxLen * sizeof(wchar_t));
    if (!buf) return;
    int pos = 0;

    for (int r = sr; r <= er; r++) {
        int cStart = (r == sr) ? sc : 0;
        int cEnd = (r == er) ? ec : tv->cols - 1;
        int lastNonSpace = cStart;
        for (int c = cStart; c <= cEnd && c < tv->cols; c++) {
            TermCell *cell = cell_at(tv, c, r);
            if (cell && !cell->isCont && cell->ch != L' ') lastNonSpace = c;
        }
        for (int c = cStart; c <= lastNonSpace && c < tv->cols; c++) {
            TermCell *cell = cell_at(tv, c, r);
            if (!cell || cell->isCont) continue;
            buf[pos++] = cell->ch ? cell->ch : L' ';
        }
        if (r < er) { buf[pos++] = L'\r'; buf[pos++] = L'\n'; }
    }
    buf[pos] = L'\0';

    if (OpenClipboard(tv->hwnd)) {
        EmptyClipboard();
        HGLOBAL hMem = GlobalAlloc(GMEM_MOVEABLE, (pos + 1) * sizeof(wchar_t));
        if (hMem) {
            wchar_t *dst = (wchar_t *)GlobalLock(hMem);
            memcpy(dst, buf, (pos + 1) * sizeof(wchar_t));
            GlobalUnlock(hMem);
            SetClipboardData(CF_UNICODETEXT, hMem);
        }
        CloseClipboard();
    }
    free(buf);
}

static void paste_from_clipboard(TerminalView *tv) {
    if (!OpenClipboard(tv->hwnd)) return;
    HANDLE hMem = GetClipboardData(CF_UNICODETEXT);
    if (hMem) {
        wchar_t *src = (wchar_t *)GlobalLock(hMem);
        if (src) {
            int wlen = (int)wcslen(src);
            char utf8[8192];
            int len = WideCharToMultiByte(CP_UTF8, 0, src, wlen, utf8, sizeof(utf8)-1, NULL, NULL);
            if (len > 0) conpty_write(&tv->pty, utf8, len);
            GlobalUnlock(hMem);
        }
    }
    CloseClipboard();
}

/* ---- Paint ---- */
static void on_paint(HWND hwnd, TerminalView *tv) {
    PAINTSTRUCT ps;
    HDC hdc = BeginPaint(hwnd, &ps);
    const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);

    RECT rc;
    GetClientRect(hwnd, &rc);
    HDC memDC = CreateCompatibleDC(hdc);
    HBITMAP memBmp = CreateCompatibleBitmap(hdc, rc.right, rc.bottom);
    SelectObject(memDC, memBmp);

    HBRUSH bgBrush = CreateSolidBrush(colors->background);
    FillRect(memDC, &rc, bgBrush);
    DeleteObject(bgBrush);

    HFONT fontNormal = CreateFontW(tv->fontSize, 0,0,0, FW_NORMAL, FALSE,FALSE,FALSE,
        DEFAULT_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, FIXED_PITCH|FF_MODERN, tv->fontFace);
    HFONT fontBold = CreateFontW(tv->fontSize, 0,0,0, FW_BOLD, FALSE,FALSE,FALSE,
        DEFAULT_CHARSET, OUT_TT_PRECIS, CLIP_DEFAULT_PRECIS, CLEARTYPE_QUALITY, FIXED_PITCH|FF_MODERN, tv->fontFace);
    SelectObject(memDC, fontNormal);

    TEXTMETRICW tm;
    GetTextMetricsW(memDC, &tm);
    tv->cellWidth = tm.tmAveCharWidth;
    tv->cellHeight = tm.tmHeight;

    SetBkMode(memDC, OPAQUE);

    if (tv->cells) {
        for (int row = 0; row < tv->rows; row++) {
            for (int col = 0; col < tv->cols; col++) {
                TermCell *cell = cell_at(tv, col, row);
                if (!cell) continue;
                if (cell->isCont) continue;

                int x = col * tv->cellWidth;
                int y = row * tv->cellHeight;
                int charW = cell->isWide ? tv->cellWidth * 2 : tv->cellWidth;

                COLORREF fg = cell->attr.fg;
                COLORREF bg = cell->attr.bg;
                if (cell->attr.inverse) { COLORREF tmp=fg; fg=bg; bg=tmp; }

                if (cell_in_selection(tv, col, row)) {
                    fg = colors->background;
                    bg = colors->text;
                }

                SelectObject(memDC, cell->attr.bold ? fontBold : fontNormal);
                SetTextColor(memDC, fg);
                SetBkColor(memDC, bg);

                RECT cellRect = { x, y, x + charW, y + tv->cellHeight };
                wchar_t ch = cell->ch ? cell->ch : L' ';
                ExtTextOutW(memDC, x, y, ETO_OPAQUE|ETO_CLIPPED, &cellRect, &ch, 1, NULL);

                if (cell->attr.underline) {
                    HPEN pen = CreatePen(PS_SOLID, 1, fg);
                    HPEN oldPen = SelectObject(memDC, pen);
                    MoveToEx(memDC, x, y + tv->cellHeight - 1, NULL);
                    LineTo(memDC, x + charW, y + tv->cellHeight - 1);
                    SelectObject(memDC, oldPen);
                    DeleteObject(pen);
                }
            }
        }
    }

    if (tv->cursorVisible && tv->cursorX < tv->cols && tv->cursorY < tv->rows) {
        RECT cursorRect = {
            tv->cursorX * tv->cellWidth, tv->cursorY * tv->cellHeight,
            tv->cursorX * tv->cellWidth + tv->cellWidth, tv->cursorY * tv->cellHeight + tv->cellHeight
        };
        HBRUSH cursorBrush = CreateSolidBrush(colors->text);
        FrameRect(memDC, &cursorRect, cursorBrush);
        DeleteObject(cursorBrush);
    }

    SelectObject(memDC, fontNormal);
    DeleteObject(fontNormal);
    DeleteObject(fontBold);

    BitBlt(hdc, 0, 0, rc.right, rc.bottom, memDC, 0, 0, SRCCOPY);
    DeleteObject(memBmp);
    DeleteDC(memDC);
    EndPaint(hwnd, &ps);
}

/* ---- Input handlers ---- */
static void on_key(HWND hwnd, TerminalView *tv, WPARAM vk, bool keyDown) {
    if (!keyDown || !tv->pty.alive) return;

    bool ctrl = GetKeyState(VK_CONTROL) & 0x8000;
    bool shift = GetKeyState(VK_SHIFT) & 0x8000;

    /* Ctrl+Shift+C: copy selection */
    if (ctrl && shift && vk == 'C') { copy_selection_to_clipboard(tv); return; }
    /* Ctrl+Shift+V: paste */
    if (ctrl && shift && vk == 'V') { paste_from_clipboard(tv); return; }

    char buf[8]; int len = 0;
    switch (vk) {
    case VK_RETURN:  buf[0]='\r'; len=1; break;
    case VK_BACK:    buf[0]='\x7f'; len=1; break;
    case VK_TAB:     buf[0]='\t'; len=1; break;
    case VK_ESCAPE:  buf[0]='\x1b'; len=1; break;
    case VK_UP:      memcpy(buf,"\x1b[A",3); len=3; break;
    case VK_DOWN:    memcpy(buf,"\x1b[B",3); len=3; break;
    case VK_RIGHT:   memcpy(buf,"\x1b[C",3); len=3; break;
    case VK_LEFT:    memcpy(buf,"\x1b[D",3); len=3; break;
    case VK_HOME:    memcpy(buf,"\x1b[H",3); len=3; break;
    case VK_END:     memcpy(buf,"\x1b[F",3); len=3; break;
    case VK_DELETE:  memcpy(buf,"\x1b[3~",4); len=4; break;
    default: return;
    }
    if (len > 0) conpty_write(&tv->pty, buf, len);
}

static void on_char(HWND hwnd, TerminalView *tv, wchar_t ch) {
    if (!tv->pty.alive) return;
    char utf8[4];
    int len = WideCharToMultiByte(CP_UTF8, 0, &ch, 1, utf8, sizeof(utf8), NULL, NULL);
    if (len > 0) conpty_write(&tv->pty, utf8, len);
}

static int cell_col_from_x(TerminalView *tv, int x) {
    if (tv->cellWidth <= 0) return 0;
    int c = x / tv->cellWidth;
    return c < 0 ? 0 : (c >= tv->cols ? tv->cols-1 : c);
}

static int cell_row_from_y(TerminalView *tv, int y) {
    if (tv->cellHeight <= 0) return 0;
    int r = y / tv->cellHeight;
    return r < 0 ? 0 : (r >= tv->rows ? tv->rows-1 : r);
}

static LRESULT CALLBACK term_wnd_proc(HWND hwnd, UINT msg, WPARAM wParam, LPARAM lParam) {
    TerminalView *tv = (TerminalView *)GetWindowLongPtrW(hwnd, GWLP_USERDATA);

    switch (msg) {
    case WM_CREATE: {
        CREATESTRUCTW *cs = (CREATESTRUCTW *)lParam;
        tv = (TerminalView *)cs->lpCreateParams;
        SetWindowLongPtrW(hwnd, GWLP_USERDATA, (LONG_PTR)tv);
        tv->hwnd = hwnd;
        SetTimer(hwnd, 1, CURSOR_BLINK_MS, NULL);
        return 0;
    }
    case WM_SIZE: {
        if (!tv) break;
        int w = LOWORD(lParam), h = HIWORD(lParam);
        if (tv->cellWidth > 0 && tv->cellHeight > 0 && w > 0 && h > 0) {
            int nc = w / tv->cellWidth, nr = h / tv->cellHeight;
            if (nc<1) nc=1; if (nr<1) nr=1;
            if (nc != tv->cols || nr != tv->rows) {
                tv->cols = nc; tv->rows = nr;
                alloc_cells(tv);
                if (tv->pty.alive) conpty_resize(&tv->pty, nc, nr);
            }
        }
        return 0;
    }
    case WM_PAINT:
        if (tv) on_paint(hwnd, tv);
        else { PAINTSTRUCT ps; BeginPaint(hwnd,&ps); EndPaint(hwnd,&ps); }
        return 0;
    case WM_ERASEBKGND: return 1;
    case WM_KEYDOWN:
        if (tv) on_key(hwnd, tv, wParam, true);
        return 0;
    case WM_CHAR:
        if (tv) on_char(hwnd, tv, (wchar_t)wParam);
        return 0;
    case WM_LBUTTONDOWN:
        if (tv) {
            SetCapture(hwnd);
            tv->selStartCol = cell_col_from_x(tv, LOWORD(lParam));
            tv->selStartRow = cell_row_from_y(tv, HIWORD(lParam));
            tv->selEndCol = tv->selStartCol;
            tv->selEndRow = tv->selStartRow;
            tv->selecting = true;
            tv->hasSelection = false;
            InvalidateRect(hwnd, NULL, FALSE);
        }
        return 0;
    case WM_MOUSEMOVE:
        if (tv && tv->selecting) {
            tv->selEndCol = cell_col_from_x(tv, LOWORD(lParam));
            tv->selEndRow = cell_row_from_y(tv, HIWORD(lParam));
            tv->hasSelection = (tv->selStartCol != tv->selEndCol || tv->selStartRow != tv->selEndRow);
            InvalidateRect(hwnd, NULL, FALSE);
        }
        return 0;
    case WM_LBUTTONUP:
        if (tv && tv->selecting) {
            ReleaseCapture();
            tv->selecting = false;
            tv->selEndCol = cell_col_from_x(tv, LOWORD(lParam));
            tv->selEndRow = cell_row_from_y(tv, HIWORD(lParam));
            tv->hasSelection = (tv->selStartCol != tv->selEndCol || tv->selStartRow != tv->selEndRow);
            InvalidateRect(hwnd, NULL, FALSE);
        }
        return 0;
    case WM_SETFOCUS:
        if (tv) tv->cursorVisible = true;
        return 0;
    case WM_KILLFOCUS:
        if (tv) { tv->cursorVisible = false; InvalidateRect(hwnd, NULL, FALSE); }
        return 0;
    case WM_TIMER:
        if (wParam == 1 && tv && GetFocus() == hwnd) {
            tv->cursorVisible = !tv->cursorVisible;
            InvalidateRect(hwnd, NULL, FALSE);
        }
        return 0;
    case WM_USER + 200:
        InvalidateRect(hwnd, NULL, FALSE);
        return 0;
    case WM_DESTROY:
        if (tv) {
            KillTimer(hwnd, 1);
            conpty_destroy(&tv->pty);
            if (tv->cells) free(tv->cells);
            free(tv);
        }
        return 0;
    }
    return DefWindowProcW(hwnd, msg, wParam, lParam);
}

bool terminal_view_register(HINSTANCE hInstance) {
    WNDCLASSEXW wc = {
        .cbSize = sizeof(WNDCLASSEXW),
        .style = CS_HREDRAW | CS_VREDRAW,
        .lpfnWndProc = term_wnd_proc,
        .hInstance = hInstance,
        .hCursor = LoadCursor(NULL, IDC_IBEAM),
        .hbrBackground = NULL,
        .lpszClassName = TERM_CLASS,
    };
    return RegisterClassExW(&wc) != 0;
}

HWND terminal_view_create(HWND parent, HINSTANCE hInstance, int id) {
    TerminalView *tv = (TerminalView *)calloc(1, sizeof(TerminalView));
    if (!tv) return NULL;

    tv->id = id;
    tv->cols = 80; tv->rows = 24;
    tv->cursorVisible = true;
    tv->fontSize = g_app.terminalFontSize;
    wcscpy(tv->fontFace, L"Cascadia Mono");
    tv->cellWidth = 8; tv->cellHeight = 16;

    const ThemeColors *colors = theme_get_colors(g_app.isDarkMode);
    tv->baseAttr.fg = colors->text;
    tv->baseAttr.bg = colors->background;
    tv->curAttr = tv->baseAttr;

    init_256_palette(tv);
    alloc_cells(tv);

    HWND hwnd = CreateWindowExW(0, TERM_CLASS, NULL,
        WS_CHILD | WS_VISIBLE | WS_TABSTOP,
        0, 0, 100, 100,
        parent, (HMENU)(LONG_PTR)(2000 + id), hInstance, tv);
    return hwnd;
}

TerminalView *terminal_view_from_hwnd(HWND hwnd) {
    return (TerminalView *)GetWindowLongPtrW(hwnd, GWLP_USERDATA);
}

void terminal_view_set_font(TerminalView *tv, const wchar_t *face, int size) {
    if (face) wcsncpy(tv->fontFace, face, 63);
    if (size > 0) tv->fontSize = size;
    InvalidateRect(tv->hwnd, NULL, TRUE);
}

void terminal_view_recalc_size(TerminalView *tv) {
    if (!tv->hwnd) return;
    RECT rc;
    GetClientRect(tv->hwnd, &rc);
    SendMessage(tv->hwnd, WM_SIZE, 0, MAKELPARAM(rc.right, rc.bottom));
}
