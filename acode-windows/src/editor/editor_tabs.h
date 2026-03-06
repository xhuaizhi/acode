#ifndef ACODE_EDITOR_TABS_H
#define ACODE_EDITOR_TABS_H

#include <windows.h>
#include <stdbool.h>

#define MAX_EDITOR_TABS 32

HWND editor_tabs_create(HWND parent, HINSTANCE hInstance);
void editor_tabs_open_file(const wchar_t *path);
void editor_tabs_close_current(void);
void editor_tabs_close_all(void);
void editor_tabs_save_current(void);
const wchar_t *editor_tabs_current_file(void);
bool editor_tabs_is_modified(void);
int  editor_tabs_get_line_count(void);
void editor_tabs_update_all_fonts(void);

#endif /* ACODE_EDITOR_TABS_H */
