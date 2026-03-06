#ifndef ACODE_FILE_TREE_H
#define ACODE_FILE_TREE_H

#include <windows.h>
#include <stdbool.h>

HWND file_tree_create(HWND parent, HINSTANCE hInstance);
void file_tree_open_folder(const wchar_t *path);
void file_tree_refresh(void);
const wchar_t *file_tree_get_root_path(void);

#endif /* ACODE_FILE_TREE_H */
