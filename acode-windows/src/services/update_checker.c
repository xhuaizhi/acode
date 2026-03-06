#include "update_checker.h"
#include "../app.h"
#include "../utils/wstr.h"
#include <winhttp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <cJSON.h>

#pragma comment(lib, "winhttp.lib")

static int compare_versions(const wchar_t *remote, const wchar_t *local) {
    int rv[3] = {0}, lv[3] = {0};
    swscanf(remote, L"%d.%d.%d", &rv[0], &rv[1], &rv[2]);
    swscanf(local, L"%d.%d.%d", &lv[0], &lv[1], &lv[2]);

    for (int i = 0; i < 3; i++) {
        if (rv[i] > lv[i]) return 1;
        if (rv[i] < lv[i]) return -1;
    }
    return 0;
}

bool update_check(UpdateCheckResult *result) {
    memset(result, 0, sizeof(UpdateCheckResult));

    HINTERNET hSession = WinHttpOpen(L"ACode/1.0",
        WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, NULL, NULL, 0);
    if (!hSession) return false;

    HINTERNET hConnect = WinHttpConnect(hSession, L"api.github.com",
        INTERNET_DEFAULT_HTTPS_PORT, 0);
    if (!hConnect) { WinHttpCloseHandle(hSession); return false; }

    HINTERNET hRequest = WinHttpOpenRequest(hConnect, L"GET",
        L"/repos/" ACODE_GITHUB_REPO L"/releases/latest",
        NULL, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES,
        WINHTTP_FLAG_SECURE);
    if (!hRequest) {
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        return false;
    }

    BOOL sent = WinHttpSendRequest(hRequest, WINHTTP_NO_ADDITIONAL_HEADERS, 0,
        WINHTTP_NO_REQUEST_DATA, 0, 0, 0);
    if (!sent || !WinHttpReceiveResponse(hRequest, NULL)) {
        WinHttpCloseHandle(hRequest);
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        return false;
    }

    /* Read response */
    char *body = NULL;
    DWORD totalSize = 0;
    DWORD bytesRead;
    char buf[4096];

    while (WinHttpReadData(hRequest, buf, sizeof(buf), &bytesRead) && bytesRead > 0) {
        body = (char *)realloc(body, totalSize + bytesRead + 1);
        memcpy(body + totalSize, buf, bytesRead);
        totalSize += bytesRead;
    }

    WinHttpCloseHandle(hRequest);
    WinHttpCloseHandle(hConnect);
    WinHttpCloseHandle(hSession);

    if (!body) return false;
    body[totalSize] = '\0';

    /* Parse JSON */
    cJSON *root = cJSON_Parse(body);
    free(body);
    if (!root) return false;

    cJSON *tagName = cJSON_GetObjectItem(root, "tag_name");
    if (tagName && cJSON_IsString(tagName)) {
        const char *ver = tagName->valuestring;
        if (ver[0] == 'v') ver++;
        wstr_from_utf8(ver, result->latestVersion, 32);
    }

    cJSON *bodyText = cJSON_GetObjectItem(root, "body");
    if (bodyText && cJSON_IsString(bodyText)) {
        wstr_from_utf8(bodyText->valuestring, result->releaseNotes, 4096);
    }

    /* Find Windows download asset */
    cJSON *assets = cJSON_GetObjectItem(root, "assets");
    if (assets && cJSON_IsArray(assets)) {
        cJSON *asset;
        cJSON_ArrayForEach(asset, assets) {
            cJSON *name = cJSON_GetObjectItem(asset, "name");
            cJSON *url = cJSON_GetObjectItem(asset, "browser_download_url");
            if (name && url && cJSON_IsString(name) && cJSON_IsString(url)) {
                if (strstr(name->valuestring, "windows") || strstr(name->valuestring, ".exe") || strstr(name->valuestring, ".msi")) {
                    wstr_from_utf8(url->valuestring, result->downloadUrl, 512);
                    break;
                }
            }
        }
    }

    result->hasUpdate = compare_versions(result->latestVersion, ACODE_VERSION) > 0;

    cJSON_Delete(root);
    return true;
}
