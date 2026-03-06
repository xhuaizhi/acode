#ifndef ACODE_UPDATE_CHECKER_H
#define ACODE_UPDATE_CHECKER_H

#include <windows.h>
#include <stdbool.h>

typedef struct {
    wchar_t latestVersion[32];
    wchar_t downloadUrl[512];
    wchar_t releaseNotes[4096];
    bool    hasUpdate;
} UpdateCheckResult;

bool update_check(UpdateCheckResult *result);

#endif /* ACODE_UPDATE_CHECKER_H */
