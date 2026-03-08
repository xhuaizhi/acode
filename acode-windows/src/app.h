#ifndef ACODE_APP_H
#define ACODE_APP_H

#include <windows.h>
#include <stdbool.h>

#define ACODE_APP_NAME       L"ACode"
#define ACODE_VERSION        L"1.0.0"
#define ACODE_BUILD          L"1"
#define ACODE_BUNDLE_ID      L"com.acode.windows"
#define ACODE_QQ_GROUP       L"1076321843"

#define ACODE_MIN_WIDTH      900
#define ACODE_MIN_HEIGHT     600
#define ACODE_DEFAULT_WIDTH  1200
#define ACODE_DEFAULT_HEIGHT 800

/* Layout ratios (0.0 - 1.0) */
#define ACODE_SIDEBAR_DEFAULT_RATIO   0.18f
#define ACODE_TERMINAL_DEFAULT_RATIO  0.65f

typedef enum {
    THEME_SYSTEM,
    THEME_LIGHT,
    THEME_DARK
} AppTheme;

typedef enum {
    SETTINGS_TAB_GENERAL,
    SETTINGS_TAB_CLAUDE,
    SETTINGS_TAB_OPENAI,
    SETTINGS_TAB_GEMINI,
    SETTINGS_TAB_MCP,
    SETTINGS_TAB_SKILLS,
    SETTINGS_TAB_USAGE,
    SETTINGS_TAB_ABOUT,
    SETTINGS_TAB_COUNT
} SettingsTab;

typedef struct {
    HINSTANCE   hInstance;
    HWND        hMainWnd;

    /* Layout */
    bool        sidebarVisible;
    bool        terminalVisible;
    float       sidebarRatio;
    float       terminalRatio;

    /* Settings */
    AppTheme    theme;
    int         terminalFontSize;
    int         editorFontSize;
    wchar_t     defaultShell[MAX_PATH];

    /* State */
    bool        settingsOpen;
    SettingsTab settingsTab;
    bool        isDarkMode;

    /* Paths */
    wchar_t     appDataPath[MAX_PATH];
    wchar_t     dbPath[MAX_PATH];

    /* Active provider tool */
    wchar_t     activeProviderTool[64];

    /* Persistence */
    wchar_t     lastProjectPath[MAX_PATH];
    int         lastTerminalCount;

} AppState;

/* Global app state */
extern AppState g_app;

void app_init(HINSTANCE hInstance);
void app_shutdown(void);
void app_save_settings(void);
void app_load_settings(void);
bool app_is_dark_mode(void);
void app_get_appdata_path(wchar_t *buf, int bufLen);

#endif /* ACODE_APP_H */
