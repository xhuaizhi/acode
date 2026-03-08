#include "app.h"
#include "utils/theme.h"
#include "utils/path.h"
#include "utils/wstr.h"
#include <shlobj.h>
#include <shlwapi.h>
#include <stdio.h>
#include <stdlib.h>
#include <cJSON.h>

AppState g_app = {0};

static void init_paths(void) {
    app_get_appdata_path(g_app.appDataPath, MAX_PATH);

    /* Ensure ACode directory exists */
    CreateDirectoryW(g_app.appDataPath, NULL);

    /* Database path */
    swprintf(g_app.dbPath, MAX_PATH, L"%s\\acode.db", g_app.appDataPath);
}

static void set_defaults(void) {
    g_app.sidebarVisible = true;
    g_app.terminalVisible = true;
    g_app.sidebarRatio = ACODE_SIDEBAR_DEFAULT_RATIO;
    g_app.terminalRatio = ACODE_TERMINAL_DEFAULT_RATIO;
    g_app.theme = THEME_SYSTEM;
    g_app.terminalFontSize = 14;
    g_app.editorFontSize = 15;
    g_app.settingsOpen = false;
    g_app.settingsTab = SETTINGS_TAB_GENERAL;

    g_app.lastProjectPath[0] = L'\0';
    g_app.lastTerminalCount = 1;

    /* Default shell: PowerShell or cmd */
    wchar_t pwsh[MAX_PATH];
    if (path_find_executable(L"pwsh.exe", pwsh, MAX_PATH)) {
        wcscpy(g_app.defaultShell, pwsh);
    } else {
        wcscpy(g_app.defaultShell, L"cmd.exe");
    }
}

void app_init(HINSTANCE hInstance) {
    g_app.hInstance = hInstance;
    set_defaults();
    init_paths();
    g_app.isDarkMode = app_is_dark_mode();
}

void app_shutdown(void) {
    app_save_settings();
}

bool app_is_dark_mode(void) {
    if (g_app.theme == THEME_LIGHT) return false;
    if (g_app.theme == THEME_DARK) return true;
    return theme_system_is_dark();
}

void app_get_appdata_path(wchar_t *buf, int bufLen) {
    wchar_t *folderPath = NULL;
    if (SUCCEEDED(SHGetKnownFolderPath(&FOLDERID_LocalAppData, 0, NULL, &folderPath))) {
        swprintf(buf, bufLen, L"%s\\ACode", folderPath);
        CoTaskMemFree(folderPath);
    } else {
        swprintf(buf, bufLen, L"C:\\ACode");
    }
}

void app_save_settings(void) {
    /* Save settings to AppData/ACode/settings.json via cJSON */
    wchar_t settingsPath[MAX_PATH];
    swprintf(settingsPath, MAX_PATH, L"%s\\settings.json", g_app.appDataPath);

    char shellUtf8[MAX_PATH * 2];
    wstr_to_utf8(g_app.defaultShell, shellUtf8, sizeof(shellUtf8));

    char lastProjectUtf8[MAX_PATH * 2] = {0};
    wstr_to_utf8(g_app.lastProjectPath, lastProjectUtf8, sizeof(lastProjectUtf8));

    /* Use cJSON to properly escape backslashes in Windows paths */
    cJSON *root = cJSON_CreateObject();
    if (!root) return;

    cJSON_AddNumberToObject(root, "theme", (int)g_app.theme);
    cJSON_AddNumberToObject(root, "terminalFontSize", g_app.terminalFontSize);
    cJSON_AddNumberToObject(root, "editorFontSize", g_app.editorFontSize);
    cJSON_AddStringToObject(root, "defaultShell", shellUtf8);
    cJSON_AddBoolToObject(root, "sidebarVisible", g_app.sidebarVisible);
    cJSON_AddBoolToObject(root, "terminalVisible", g_app.terminalVisible);
    cJSON_AddNumberToObject(root, "sidebarRatio", (double)g_app.sidebarRatio);
    cJSON_AddNumberToObject(root, "terminalRatio", (double)g_app.terminalRatio);
    cJSON_AddStringToObject(root, "lastProjectPath", lastProjectUtf8);
    cJSON_AddNumberToObject(root, "lastTerminalCount", g_app.lastTerminalCount);

    char *json = cJSON_Print(root);
    cJSON_Delete(root);
    if (!json) return;

    char pathUtf8[MAX_PATH * 2];
    wstr_to_utf8(settingsPath, pathUtf8, sizeof(pathUtf8));

    FILE *f = fopen(pathUtf8, "wb");
    if (f) {
        fwrite(json, 1, strlen(json), f);
        fclose(f);
    }
    free(json);
}

void app_load_settings(void) {
    wchar_t settingsPath[MAX_PATH];
    swprintf(settingsPath, MAX_PATH, L"%s\\settings.json", g_app.appDataPath);

    char pathUtf8[MAX_PATH * 2];
    wstr_to_utf8(settingsPath, pathUtf8, sizeof(pathUtf8));

    FILE *f = fopen(pathUtf8, "rb");
    if (!f) return;

    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len <= 0 || len > 65536) { fclose(f); return; }

    char *buf = (char *)malloc(len + 1);
    if (!buf) { fclose(f); return; }
    fread(buf, 1, len, f);
    buf[len] = '\0';
    fclose(f);

    /* Minimal JSON parse using cJSON */
    cJSON *root = cJSON_Parse(buf);
    if (root) {
        cJSON *item;
        if ((item = cJSON_GetObjectItem(root, "theme")) && cJSON_IsNumber(item))
            g_app.theme = (AppTheme)item->valueint;
        if ((item = cJSON_GetObjectItem(root, "terminalFontSize")) && cJSON_IsNumber(item))
            g_app.terminalFontSize = item->valueint;
        if ((item = cJSON_GetObjectItem(root, "editorFontSize")) && cJSON_IsNumber(item))
            g_app.editorFontSize = item->valueint;
        if ((item = cJSON_GetObjectItem(root, "defaultShell")) && cJSON_IsString(item)) {
            wchar_t wbuf[MAX_PATH];
            wstr_from_utf8(item->valuestring, wbuf, MAX_PATH);
            wcscpy(g_app.defaultShell, wbuf);
        }
        if ((item = cJSON_GetObjectItem(root, "sidebarVisible")) && cJSON_IsBool(item))
            g_app.sidebarVisible = cJSON_IsTrue(item);
        if ((item = cJSON_GetObjectItem(root, "terminalVisible")) && cJSON_IsBool(item))
            g_app.terminalVisible = cJSON_IsTrue(item);
        if ((item = cJSON_GetObjectItem(root, "sidebarRatio")) && cJSON_IsNumber(item))
            g_app.sidebarRatio = (float)item->valuedouble;
        if ((item = cJSON_GetObjectItem(root, "terminalRatio")) && cJSON_IsNumber(item))
            g_app.terminalRatio = (float)item->valuedouble;
        if ((item = cJSON_GetObjectItem(root, "lastProjectPath")) && cJSON_IsString(item)) {
            wchar_t wbuf[MAX_PATH];
            wstr_from_utf8(item->valuestring, wbuf, MAX_PATH);
            wcscpy(g_app.lastProjectPath, wbuf);
        }
        if ((item = cJSON_GetObjectItem(root, "lastTerminalCount")) && cJSON_IsNumber(item))
            g_app.lastTerminalCount = item->valueint;

        cJSON_Delete(root);
    }
    free(buf);
}
