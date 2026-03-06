#ifndef ACODE_TERMINAL_MGR_H
#define ACODE_TERMINAL_MGR_H

#include <windows.h>
#include <stdbool.h>

#define MAX_TERMINALS 32

HWND terminal_mgr_create(HWND parent, HINSTANCE hInstance);
void terminal_mgr_new_tab(void);
void terminal_mgr_close_active(void);
void terminal_mgr_split_vertical(void);
void terminal_mgr_split_horizontal(void);
int  terminal_mgr_count(void);
void terminal_mgr_set_env(const wchar_t *envBlock);
void terminal_mgr_destroy_all(void);
void terminal_mgr_update_all_fonts(void);

/* backward compat */
void terminal_mgr_close_tab(int index);

#endif /* ACODE_TERMINAL_MGR_H */
