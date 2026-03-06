#ifndef ACODE_CONPTY_H
#define ACODE_CONPTY_H

#include <windows.h>
#include <stdbool.h>

typedef struct ConPTY {
    HPCON       hPC;
    HANDLE      hPipeIn;       /* Read from this (terminal output) */
    HANDLE      hPipeOut;      /* Write to this (terminal input) */
    HANDLE      hProcess;
    HANDLE      hThread;
    HANDLE      hReadThread;
    COORD       size;
    bool        alive;

    /* Callback for output data */
    void (*onOutput)(struct ConPTY *pty, const char *data, int len, void *ctx);
    void *outputCtx;
} ConPTY;

bool conpty_create(ConPTY *pty, const wchar_t *shell, const wchar_t *cwd,
                   const wchar_t *env, int cols, int rows);
void conpty_destroy(ConPTY *pty);
bool conpty_write(ConPTY *pty, const char *data, int len);
bool conpty_resize(ConPTY *pty, int cols, int rows);
bool conpty_is_alive(ConPTY *pty);

#endif /* ACODE_CONPTY_H */
