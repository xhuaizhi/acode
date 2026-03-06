#include "text_buffer.h"
#include <stdlib.h>
#include <string.h>

#define GAP_SIZE 1024

static void grow_gap(TextBuffer *tb, int needed) {
    int gapSize = tb->gapEnd - tb->gapStart;
    if (gapSize >= needed) return;

    int newCap = tb->capacity + needed + GAP_SIZE;
    wchar_t *newData = (wchar_t *)malloc(newCap * sizeof(wchar_t));
    if (!newData) return;

    int afterGap = tb->capacity - tb->gapEnd;
    memcpy(newData, tb->data, tb->gapStart * sizeof(wchar_t));
    int newGapEnd = newCap - afterGap;
    memcpy(newData + newGapEnd, tb->data + tb->gapEnd, afterGap * sizeof(wchar_t));

    free(tb->data);
    tb->data = newData;
    tb->capacity = newCap;
    tb->gapEnd = newGapEnd;
}

static void move_gap(TextBuffer *tb, int pos) {
    if (pos == tb->gapStart) return;

    if (pos < tb->gapStart) {
        int count = tb->gapStart - pos;
        memmove(tb->data + tb->gapEnd - count, tb->data + pos, count * sizeof(wchar_t));
        tb->gapStart -= count;
        tb->gapEnd -= count;
    } else {
        int count = pos - tb->gapStart;
        memmove(tb->data + tb->gapStart, tb->data + tb->gapEnd, count * sizeof(wchar_t));
        tb->gapStart += count;
        tb->gapEnd += count;
    }
}

void tb_init(TextBuffer *tb, int initialCap) {
    if (initialCap < GAP_SIZE) initialCap = GAP_SIZE;
    tb->data = (wchar_t *)calloc(initialCap, sizeof(wchar_t));
    tb->capacity = initialCap;
    tb->gapStart = 0;
    tb->gapEnd = initialCap;
}

void tb_free(TextBuffer *tb) {
    free(tb->data);
    tb->data = NULL;
    tb->capacity = 0;
    tb->gapStart = 0;
    tb->gapEnd = 0;
}

void tb_set_text(TextBuffer *tb, const wchar_t *text) {
    int len = text ? (int)wcslen(text) : 0;
    int newCap = len + GAP_SIZE;

    free(tb->data);
    tb->data = (wchar_t *)malloc(newCap * sizeof(wchar_t));
    tb->capacity = newCap;

    if (len > 0) memcpy(tb->data, text, len * sizeof(wchar_t));
    tb->gapStart = len;
    tb->gapEnd = newCap;
}

int tb_length(const TextBuffer *tb) {
    return tb->capacity - (tb->gapEnd - tb->gapStart);
}

wchar_t tb_char_at(const TextBuffer *tb, int pos) {
    if (pos < 0 || pos >= tb_length(tb)) return 0;
    if (pos < tb->gapStart) return tb->data[pos];
    return tb->data[tb->gapEnd + (pos - tb->gapStart)];
}

void tb_insert(TextBuffer *tb, int pos, wchar_t ch) {
    tb_insert_text(tb, pos, &ch, 1);
}

void tb_insert_text(TextBuffer *tb, int pos, const wchar_t *text, int len) {
    if (!text || len <= 0) return;
    if (pos < 0) pos = 0;
    if (pos > tb_length(tb)) pos = tb_length(tb);

    move_gap(tb, pos);
    grow_gap(tb, len);

    memcpy(tb->data + tb->gapStart, text, len * sizeof(wchar_t));
    tb->gapStart += len;
}

void tb_delete(TextBuffer *tb, int pos, int count) {
    if (count <= 0 || pos < 0) return;
    int total = tb_length(tb);
    if (pos >= total) return;
    if (pos + count > total) count = total - pos;

    move_gap(tb, pos);
    tb->gapEnd += count;
}

int tb_line_count(const TextBuffer *tb) {
    int count = 1;
    int len = tb_length(tb);
    for (int i = 0; i < len; i++) {
        if (tb_char_at(tb, i) == L'\n') count++;
    }
    return count;
}

int tb_line_start(const TextBuffer *tb, int line) {
    if (line <= 0) return 0;
    int count = 0;
    int len = tb_length(tb);
    for (int i = 0; i < len; i++) {
        if (tb_char_at(tb, i) == L'\n') {
            count++;
            if (count == line) return i + 1;
        }
    }
    return len;
}

int tb_line_of_pos(const TextBuffer *tb, int pos) {
    int line = 0;
    for (int i = 0; i < pos && i < tb_length(tb); i++) {
        if (tb_char_at(tb, i) == L'\n') line++;
    }
    return line;
}

int tb_line_length(const TextBuffer *tb, int line) {
    int start = tb_line_start(tb, line);
    int len = tb_length(tb);
    int end = start;
    while (end < len && tb_char_at(tb, end) != L'\n') end++;
    return end - start;
}

void tb_get_line(const TextBuffer *tb, int line, wchar_t *buf, int bufChars) {
    int start = tb_line_start(tb, line);
    int lineLen = tb_line_length(tb, line);
    int copyLen = lineLen < bufChars - 1 ? lineLen : bufChars - 1;

    for (int i = 0; i < copyLen; i++) {
        buf[i] = tb_char_at(tb, start + i);
    }
    buf[copyLen] = L'\0';
}

wchar_t *tb_to_string(const TextBuffer *tb) {
    int len = tb_length(tb);
    wchar_t *str = (wchar_t *)malloc((len + 1) * sizeof(wchar_t));
    if (!str) return NULL;

    for (int i = 0; i < len; i++) {
        str[i] = tb_char_at(tb, i);
    }
    str[len] = L'\0';
    return str;
}

/* Undo Manager */
static void free_entry(UndoEntry *e) {
    if (!e) return;
    free(e->deleted);
    free(e->inserted);
    free(e);
}

static void free_stack(UndoEntry *stack) {
    while (stack) {
        UndoEntry *next = stack->next;
        free_entry(stack);
        stack = next;
    }
}

void undo_init(UndoManager *um) {
    memset(um, 0, sizeof(UndoManager));
    um->recording = true;
}

void undo_free(UndoManager *um) {
    free_stack(um->undoStack);
    free_stack(um->redoStack);
    um->undoStack = NULL;
    um->redoStack = NULL;
}

void undo_record_insert(UndoManager *um, int pos, const wchar_t *text, int len) {
    if (!um->recording) return;

    /* Clear redo stack on new action */
    free_stack(um->redoStack);
    um->redoStack = NULL;

    UndoEntry *e = (UndoEntry *)calloc(1, sizeof(UndoEntry));
    e->pos = pos;
    e->insLen = len;
    e->inserted = (wchar_t *)malloc(len * sizeof(wchar_t));
    memcpy(e->inserted, text, len * sizeof(wchar_t));
    e->next = um->undoStack;
    um->undoStack = e;
}

void undo_record_delete(UndoManager *um, int pos, const wchar_t *text, int len) {
    if (!um->recording) return;

    free_stack(um->redoStack);
    um->redoStack = NULL;

    UndoEntry *e = (UndoEntry *)calloc(1, sizeof(UndoEntry));
    e->pos = pos;
    e->delLen = len;
    e->deleted = (wchar_t *)malloc(len * sizeof(wchar_t));
    memcpy(e->deleted, text, len * sizeof(wchar_t));
    e->next = um->undoStack;
    um->undoStack = e;
}

bool undo_perform(UndoManager *um, TextBuffer *tb) {
    UndoEntry *e = um->undoStack;
    if (!e) return false;

    um->undoStack = e->next;
    um->recording = false;

    if (e->insLen > 0) {
        tb_delete(tb, e->pos, e->insLen);
    }
    if (e->delLen > 0) {
        tb_insert_text(tb, e->pos, e->deleted, e->delLen);
    }

    um->recording = true;

    /* Push to redo stack */
    e->next = um->redoStack;
    um->redoStack = e;
    return true;
}

bool redo_perform(UndoManager *um, TextBuffer *tb) {
    UndoEntry *e = um->redoStack;
    if (!e) return false;

    um->redoStack = e->next;
    um->recording = false;

    if (e->delLen > 0) {
        tb_delete(tb, e->pos, e->delLen);
    }
    if (e->insLen > 0) {
        tb_insert_text(tb, e->pos, e->inserted, e->insLen);
    }

    um->recording = true;

    e->next = um->undoStack;
    um->undoStack = e;
    return true;
}
