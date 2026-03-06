#ifndef ACODE_TEXT_BUFFER_H
#define ACODE_TEXT_BUFFER_H

#include <windows.h>
#include <stdbool.h>

/* Gap buffer for efficient text editing */
typedef struct {
    wchar_t *data;
    int      capacity;
    int      gapStart;
    int      gapEnd;
} TextBuffer;

void    tb_init(TextBuffer *tb, int initialCap);
void    tb_free(TextBuffer *tb);
void    tb_set_text(TextBuffer *tb, const wchar_t *text);
int     tb_length(const TextBuffer *tb);
wchar_t tb_char_at(const TextBuffer *tb, int pos);
void    tb_insert(TextBuffer *tb, int pos, wchar_t ch);
void    tb_insert_text(TextBuffer *tb, int pos, const wchar_t *text, int len);
void    tb_delete(TextBuffer *tb, int pos, int count);
int     tb_line_count(const TextBuffer *tb);
int     tb_line_start(const TextBuffer *tb, int line);
int     tb_line_of_pos(const TextBuffer *tb, int pos);
int     tb_line_length(const TextBuffer *tb, int line);
void    tb_get_line(const TextBuffer *tb, int line, wchar_t *buf, int bufChars);
wchar_t *tb_to_string(const TextBuffer *tb);

/* Undo support */
typedef struct UndoEntry {
    int     pos;
    int     delLen;
    wchar_t *deleted;
    int     insLen;
    wchar_t *inserted;
    struct UndoEntry *next;
} UndoEntry;

typedef struct {
    UndoEntry *undoStack;
    UndoEntry *redoStack;
    bool       recording;
} UndoManager;

void undo_init(UndoManager *um);
void undo_free(UndoManager *um);
void undo_record_insert(UndoManager *um, int pos, const wchar_t *text, int len);
void undo_record_delete(UndoManager *um, int pos, const wchar_t *text, int len);
bool undo_perform(UndoManager *um, TextBuffer *tb);
bool redo_perform(UndoManager *um, TextBuffer *tb);

#endif /* ACODE_TEXT_BUFFER_H */
