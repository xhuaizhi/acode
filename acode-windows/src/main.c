#include <windows.h>
#include <commctrl.h>
#include <ole2.h>
#include "app.h"
#include "window/main_window.h"
#include "database/database.h"
#include "settings/settings_window.h"
#include "explorer/file_tree.h"
#include "provider/provider_service.h"
#include "terminal/terminal_mgr.h"
#include "editor/editor_tabs.h"

#pragma comment(lib, "comctl32.lib")
#pragma comment(lib, "ole32.lib")
#pragma comment(linker, "/manifestdependency:\"type='win32' name='Microsoft.Windows.Common-Controls' version='6.0.0.0' processorArchitecture='*' publicKeyToken='6595b64144ccf1df' language='*'\"")

static HACCEL s_hAccel = NULL;

static void handle_open_folder(HWND hwnd) {
    IFileDialog *pfd = NULL;
    HRESULT hr = CoCreateInstance(
        &CLSID_FileOpenDialog, NULL, CLSCTX_INPROC_SERVER,
        &IID_IFileOpenDialog, (void **)&pfd
    );
    if (FAILED(hr) || !pfd) return;

    DWORD options;
    pfd->lpVtbl->GetOptions(pfd, &options);
    pfd->lpVtbl->SetOptions(pfd, options | FOS_PICKFOLDERS);
    pfd->lpVtbl->SetTitle(pfd, L"\u6253\u5F00\u6587\u4EF6\u5939");

    hr = pfd->lpVtbl->Show(pfd, hwnd);
    if (SUCCEEDED(hr)) {
        IShellItem *psi = NULL;
        hr = pfd->lpVtbl->GetResult(pfd, &psi);
        if (SUCCEEDED(hr) && psi) {
            LPWSTR path = NULL;
            psi->lpVtbl->GetDisplayName(psi, SIGDN_FILESYSPATH, &path);
            if (path) {
                /* Clear old project's editor tabs (matches Mac switchProject) */
                editor_tabs_close_all();
                file_tree_open_folder(path);
                /* Persist last project path */
                wcscpy(g_app.lastProjectPath, path);
                app_save_settings();
                CoTaskMemFree(path);
            }
            psi->lpVtbl->Release(psi);
        }
    }

    pfd->lpVtbl->Release(pfd);
}

static void handle_keyboard(HWND hwnd, MSG *msg) {
    if (msg->message == WM_KEYDOWN) {
        bool ctrl = GetKeyState(VK_CONTROL) & 0x8000;
        bool shift = GetKeyState(VK_SHIFT) & 0x8000;

        if (ctrl && !shift && msg->wParam == 'O') {
            handle_open_folder(hwnd);
            return;
        }
        if (ctrl && !shift && msg->wParam == 'T') {
            terminal_mgr_new_tab();
            return;
        }
        if (ctrl && !shift && msg->wParam == 'D') {
            terminal_mgr_split_vertical();
            return;
        }
        if (ctrl && shift && msg->wParam == 'D') {
            terminal_mgr_split_horizontal();
            return;
        }
        if (msg->wParam == VK_ESCAPE && settings_is_visible()) {
            settings_hide();
            return;
        }
        if (ctrl && msg->wParam == VK_OEM_COMMA) {
            if (!settings_is_visible()) {
                settings_show(hwnd);
            } else {
                settings_hide();
            }
            return;
        }
    }
}

int WINAPI wWinMain(HINSTANCE hInstance, HINSTANCE hPrevInstance,
                    LPWSTR lpCmdLine, int nCmdShow) {
    (void)hPrevInstance;
    (void)lpCmdLine;

    /* Initialize COM */
    CoInitializeEx(NULL, COINIT_APARTMENTTHREADED | COINIT_DISABLE_OLE1DDE);

    /* Initialize Common Controls */
    INITCOMMONCONTROLSEX icc = {
        .dwSize = sizeof(INITCOMMONCONTROLSEX),
        .dwICC = ICC_TAB_CLASSES | ICC_TREEVIEW_CLASSES | ICC_LISTVIEW_CLASSES | ICC_BAR_CLASSES
    };
    InitCommonControlsEx(&icc);

    /* Initialize app state */
    app_init(hInstance);
    app_load_settings();
    g_app.isDarkMode = app_is_dark_mode();

    /* Open database */
    db_open(g_app.dbPath);

    /* Register and create main window */
    if (!main_window_register(hInstance)) {
        MessageBoxW(NULL, L"\u7A97\u53E3\u6CE8\u518C\u5931\u8D25", L"ACode", MB_ICONERROR);
        return 1;
    }

    HWND hwnd = main_window_create(hInstance);
    if (!hwnd) {
        MessageBoxW(NULL, L"\u7A97\u53E3\u521B\u5EFA\u5931\u8D25", L"ACode", MB_ICONERROR);
        return 1;
    }

    g_app.hMainWnd = hwnd;

    /* Restore last project folder (matches Mac onAppear) */
    if (g_app.lastProjectPath[0]) {
        DWORD attr = GetFileAttributesW(g_app.lastProjectPath);
        if (attr != INVALID_FILE_ATTRIBUTES && (attr & FILE_ATTRIBUTE_DIRECTORY))
            file_tree_open_folder(g_app.lastProjectPath);
    }

    /* Generate initial provider environment */
    wchar_t envBlock[8192] = {0};
    provider_service_generate_env(envBlock, 8192);
    terminal_mgr_set_env(envBlock);

    ShowWindow(hwnd, nCmdShow);
    UpdateWindow(hwnd);

    /* Message loop */
    MSG msg;
    while (GetMessageW(&msg, NULL, 0, 0)) {
        handle_keyboard(hwnd, &msg);
        TranslateMessage(&msg);
        DispatchMessageW(&msg);
    }

    /* Cleanup */
    db_close();
    app_shutdown();
    CoUninitialize();

    return (int)msg.wParam;
}
