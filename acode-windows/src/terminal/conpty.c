#include "conpty.h"
#include <stdio.h>
#include <stdlib.h>
#include <process.h>

static DWORD WINAPI read_thread_proc(LPVOID param) {
    ConPTY *pty = (ConPTY *)param;
    char buf[4096];
    DWORD bytesRead;

    while (pty->alive) {
        BOOL ok = ReadFile(pty->hPipeIn, buf, sizeof(buf), &bytesRead, NULL);
        if (!ok || bytesRead == 0) {
            pty->alive = false;
            break;
        }
        if (pty->onOutput) {
            pty->onOutput(pty, buf, (int)bytesRead, pty->outputCtx);
        }
    }
    return 0;
}

static wchar_t *build_env_block(const wchar_t *extraEnv) {
    /* Get current environment and append extra variables */
    wchar_t *currentEnv = GetEnvironmentStringsW();
    if (!currentEnv) return NULL;

    /* Calculate current env size */
    size_t currentLen = 0;
    const wchar_t *p = currentEnv;
    while (*p) {
        size_t entryLen = wcslen(p) + 1;
        currentLen += entryLen;
        p += entryLen;
    }

    /* Parse extra env (format: "KEY=VALUE\nKEY2=VALUE2\n") */
    size_t extraLen = 0;
    if (extraEnv) extraLen = wcslen(extraEnv);

    /* Allocate new block: current + extra + double null */
    size_t totalSize = (currentLen + extraLen + 256) * sizeof(wchar_t);
    wchar_t *newEnv = (wchar_t *)malloc(totalSize);
    if (!newEnv) {
        FreeEnvironmentStringsW(currentEnv);
        return NULL;
    }

    /* Copy current env */
    memcpy(newEnv, currentEnv, currentLen * sizeof(wchar_t));
    FreeEnvironmentStringsW(currentEnv);

    /* Append extra env entries (newline-separated -> null-separated) */
    wchar_t *dst = newEnv + currentLen;
    if (extraEnv && *extraEnv) {
        const wchar_t *src = extraEnv;
        while (*src) {
            const wchar_t *lineEnd = wcschr(src, L'\n');
            size_t lineLen = lineEnd ? (size_t)(lineEnd - src) : wcslen(src);
            if (lineLen > 0 && wcschr(src, L'=') != NULL) {
                memcpy(dst, src, lineLen * sizeof(wchar_t));
                dst[lineLen] = L'\0';
                dst += lineLen + 1;
            }
            src += lineLen;
            if (*src == L'\n') src++;
        }
    }

    /* Double null terminator */
    *dst = L'\0';

    return newEnv;
}

bool conpty_create(ConPTY *pty, const wchar_t *shell, const wchar_t *cwd,
                   const wchar_t *env, int cols, int rows) {
    memset(pty, 0, sizeof(ConPTY));
    pty->size.X = (SHORT)cols;
    pty->size.Y = (SHORT)rows;

    /* Create pipes */
    HANDLE hPipeInRead, hPipeInWrite;
    HANDLE hPipeOutRead, hPipeOutWrite;

    if (!CreatePipe(&hPipeInRead, &hPipeInWrite, NULL, 0)) return false;
    if (!CreatePipe(&hPipeOutRead, &hPipeOutWrite, NULL, 0)) {
        CloseHandle(hPipeInRead);
        CloseHandle(hPipeInWrite);
        return false;
    }

    /* Create pseudo console */
    COORD size = { (SHORT)cols, (SHORT)rows };
    HRESULT hr = CreatePseudoConsole(size, hPipeOutRead, hPipeInWrite, 0, &pty->hPC);
    if (FAILED(hr)) {
        CloseHandle(hPipeInRead);
        CloseHandle(hPipeInWrite);
        CloseHandle(hPipeOutRead);
        CloseHandle(hPipeOutWrite);
        return false;
    }

    /* Prepare startup info with pseudo console */
    SIZE_T attrListSize = 0;
    InitializeProcThreadAttributeList(NULL, 1, 0, &attrListSize);
    LPPROC_THREAD_ATTRIBUTE_LIST attrList = (LPPROC_THREAD_ATTRIBUTE_LIST)malloc(attrListSize);
    if (!attrList) goto fail;

    if (!InitializeProcThreadAttributeList(attrList, 1, 0, &attrListSize)) goto fail;

    if (!UpdateProcThreadAttribute(attrList, 0,
            PROC_THREAD_ATTRIBUTE_PSEUDOCONSOLE, pty->hPC, sizeof(HPCON), NULL, NULL))
        goto fail;

    STARTUPINFOEXW siEx = {0};
    siEx.StartupInfo.cb = sizeof(STARTUPINFOEXW);
    siEx.lpAttributeList = attrList;

    /* Build environment block */
    wchar_t *envBlock = build_env_block(env);

    /* Create process */
    wchar_t cmdLine[MAX_PATH + 32];
    _snwprintf(cmdLine, _countof(cmdLine), L"\"%s\"", shell);

    PROCESS_INFORMATION pi = {0};
    BOOL ok = CreateProcessW(
        NULL, cmdLine, NULL, NULL, FALSE,
        EXTENDED_STARTUPINFO_PRESENT | CREATE_UNICODE_ENVIRONMENT,
        envBlock, cwd, &siEx.StartupInfo, &pi
    );

    free(envBlock);
    DeleteProcThreadAttributeList(attrList);
    free(attrList);

    if (!ok) goto fail;

    /* Close pipe ends owned by the child */
    CloseHandle(hPipeOutRead);
    CloseHandle(hPipeInWrite);

    pty->hPipeIn = hPipeInRead;
    pty->hPipeOut = hPipeOutWrite;
    pty->hProcess = pi.hProcess;
    pty->hThread = pi.hThread;
    pty->alive = true;

    /* Start read thread */
    pty->hReadThread = CreateThread(NULL, 0, read_thread_proc, pty, 0, NULL);

    return true;

fail:
    if (pty->hPC) ClosePseudoConsole(pty->hPC);
    CloseHandle(hPipeInRead);
    CloseHandle(hPipeInWrite);
    CloseHandle(hPipeOutRead);
    CloseHandle(hPipeOutWrite);
    if (attrList) free(attrList);
    return false;
}

void conpty_destroy(ConPTY *pty) {
    pty->alive = false;

    if (pty->hPC) {
        ClosePseudoConsole(pty->hPC);
        pty->hPC = NULL;
    }

    if (pty->hProcess) {
        TerminateProcess(pty->hProcess, 0);
        WaitForSingleObject(pty->hProcess, 1000);
        CloseHandle(pty->hProcess);
        pty->hProcess = NULL;
    }

    if (pty->hThread) {
        CloseHandle(pty->hThread);
        pty->hThread = NULL;
    }

    if (pty->hReadThread) {
        WaitForSingleObject(pty->hReadThread, 2000);
        CloseHandle(pty->hReadThread);
        pty->hReadThread = NULL;
    }

    if (pty->hPipeIn) { CloseHandle(pty->hPipeIn); pty->hPipeIn = NULL; }
    if (pty->hPipeOut) { CloseHandle(pty->hPipeOut); pty->hPipeOut = NULL; }
}

bool conpty_write(ConPTY *pty, const char *data, int len) {
    if (!pty->alive || !pty->hPipeOut) return false;
    DWORD written;
    return WriteFile(pty->hPipeOut, data, len, &written, NULL);
}

bool conpty_resize(ConPTY *pty, int cols, int rows) {
    if (!pty->hPC) return false;
    COORD size = { (SHORT)cols, (SHORT)rows };
    pty->size = size;
    return SUCCEEDED(ResizePseudoConsole(pty->hPC, size));
}

bool conpty_is_alive(ConPTY *pty) {
    if (!pty->alive) return false;
    DWORD exitCode;
    if (GetExitCodeProcess(pty->hProcess, &exitCode)) {
        if (exitCode != STILL_ACTIVE) {
            pty->alive = false;
            return false;
        }
    }
    return true;
}
