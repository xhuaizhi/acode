#ifndef ACODE_PATH_H
#define ACODE_PATH_H

#include <windows.h>
#include <stdbool.h>

bool path_find_executable(const wchar_t *name, wchar_t *buf, int bufChars);
bool path_exists(const wchar_t *path);
bool path_is_directory(const wchar_t *path);
bool path_ensure_directory(const wchar_t *path);
const wchar_t *path_extension(const wchar_t *path);
const wchar_t *path_filename(const wchar_t *path);
void path_join(wchar_t *buf, int bufChars, const wchar_t *base, const wchar_t *child);
void path_get_home(wchar_t *buf, int bufChars);

#endif /* ACODE_PATH_H */
