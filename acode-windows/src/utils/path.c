#include "path.h"
#include <shlobj.h>
#include <shlwapi.h>
#include <stdio.h>

#pragma comment(lib, "shlwapi.lib")

bool path_find_executable(const wchar_t *name, wchar_t *buf, int bufChars) {
    DWORD result = SearchPathW(NULL, name, NULL, bufChars, buf, NULL);
    return result > 0 && result < (DWORD)bufChars;
}

bool path_exists(const wchar_t *path) {
    DWORD attrs = GetFileAttributesW(path);
    return attrs != INVALID_FILE_ATTRIBUTES;
}

bool path_is_directory(const wchar_t *path) {
    DWORD attrs = GetFileAttributesW(path);
    return attrs != INVALID_FILE_ATTRIBUTES && (attrs & FILE_ATTRIBUTE_DIRECTORY);
}

bool path_ensure_directory(const wchar_t *path) {
    if (path_is_directory(path)) return true;
    return CreateDirectoryW(path, NULL) || GetLastError() == ERROR_ALREADY_EXISTS;
}

const wchar_t *path_extension(const wchar_t *path) {
    const wchar_t *ext = PathFindExtensionW(path);
    if (ext && *ext == L'.') return ext + 1;
    return L"";
}

const wchar_t *path_filename(const wchar_t *path) {
    return PathFindFileNameW(path);
}

void path_join(wchar_t *buf, int bufChars, const wchar_t *base, const wchar_t *child) {
    _snwprintf(buf, bufChars, L"%s\\%s", base, child);
    buf[bufChars - 1] = L'\0';
}

void path_get_home(wchar_t *buf, int bufChars) {
    wchar_t *folderPath = NULL;
    if (SUCCEEDED(SHGetKnownFolderPath(&FOLDERID_Profile, 0, NULL, &folderPath))) {
        wcsncpy(buf, folderPath, bufChars);
        buf[bufChars - 1] = L'\0';
        CoTaskMemFree(folderPath);
    } else {
        wcsncpy(buf, L"C:\\Users\\Default", bufChars);
    }
}
