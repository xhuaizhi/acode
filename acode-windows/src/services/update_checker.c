#include "update_checker.h"
#include "../app.h"
#include "../utils/wstr.h"
#include <winhttp.h>
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <cJSON.h>

#pragma comment(lib, "winhttp.lib")

/* ACode 自建更新服务器 */
#define UPDATE_API_HOST  L"acode.anna.tf"
#define UPDATE_API_PORT  INTERNET_DEFAULT_HTTPS_PORT
#define UPDATE_API_FLAGS WINHTTP_FLAG_SECURE

bool update_check(UpdateCheckResult *result) {
    memset(result, 0, sizeof(UpdateCheckResult));

    /* Build query path with current version */
    wchar_t path[256];
    _snwprintf(path, 256, L"/api/v1/update/check?version=%s&platform=windows", ACODE_VERSION);

    HINTERNET hSession = WinHttpOpen(L"ACode/1.0",
        WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, NULL, NULL, 0);
    if (!hSession) return false;

    HINTERNET hConnect = WinHttpConnect(hSession, UPDATE_API_HOST,
        UPDATE_API_PORT, 0);
    if (!hConnect) { WinHttpCloseHandle(hSession); return false; }

    HINTERNET hRequest = WinHttpOpenRequest(hConnect, L"GET",
        path, NULL, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES,
        UPDATE_API_FLAGS);
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

    /* Verify HTTP 200 */
    DWORD statusCode = 0, statusSize = sizeof(statusCode);
    WinHttpQueryHeaders(hRequest, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
        NULL, &statusCode, &statusSize, NULL);
    if (statusCode != 200) {
        WinHttpCloseHandle(hRequest);
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        return false;
    }

    /* Read response body */
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

    /* Parse self-hosted API response */
    cJSON *root = cJSON_Parse(body);
    free(body);
    if (!root) return false;

    cJSON *hasUpdate = cJSON_GetObjectItem(root, "has_update");
    result->hasUpdate = hasUpdate && cJSON_IsTrue(hasUpdate);

    if (result->hasUpdate) {
        cJSON *ver = cJSON_GetObjectItem(root, "version");
        if (ver && cJSON_IsString(ver))
            wstr_from_utf8(ver->valuestring, result->latestVersion, 32);

        cJSON *notes = cJSON_GetObjectItem(root, "notes");
        if (notes && cJSON_IsString(notes))
            wstr_from_utf8(notes->valuestring, result->releaseNotes, 4096);

        cJSON *dlUrl = cJSON_GetObjectItem(root, "download_url");
        if (dlUrl && cJSON_IsString(dlUrl))
            wstr_from_utf8(dlUrl->valuestring, result->downloadUrl, 512);
    }

    cJSON_Delete(root);
    return true;
}

bool update_download(UpdateCheckResult *result) {
    if (!result->hasUpdate || !result->downloadUrl[0]) return false;

    /* Parse host and path from downloadUrl */
    URL_COMPONENTS uc = { .dwStructSize = sizeof(uc) };
    wchar_t host[256] = {0}, urlPath[512] = {0};
    uc.lpszHostName = host;   uc.dwHostNameLength = 256;
    uc.lpszUrlPath  = urlPath; uc.dwUrlPathLength  = 512;

    if (!WinHttpCrackUrl(result->downloadUrl, 0, 0, &uc)) return false;

    DWORD flags = (uc.nScheme == INTERNET_SCHEME_HTTPS) ? WINHTTP_FLAG_SECURE : 0;

    HINTERNET hSession = WinHttpOpen(L"ACode/1.0",
        WINHTTP_ACCESS_TYPE_DEFAULT_PROXY, NULL, NULL, 0);
    if (!hSession) return false;

    HINTERNET hConnect = WinHttpConnect(hSession, host, uc.nPort, 0);
    if (!hConnect) { WinHttpCloseHandle(hSession); return false; }

    HINTERNET hRequest = WinHttpOpenRequest(hConnect, L"GET",
        urlPath, NULL, WINHTTP_NO_REFERER, WINHTTP_DEFAULT_ACCEPT_TYPES, flags);
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

    /* Verify HTTP 200 before downloading */
    DWORD statusCode = 0, statusSize = sizeof(statusCode);
    WinHttpQueryHeaders(hRequest, WINHTTP_QUERY_STATUS_CODE | WINHTTP_QUERY_FLAG_NUMBER,
        NULL, &statusCode, &statusSize, NULL);
    if (statusCode != 200) {
        WinHttpCloseHandle(hRequest);
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        return false;
    }

    /* Build temp file path */
    wchar_t tempDir[MAX_PATH];
    GetTempPathW(MAX_PATH, tempDir);
    _snwprintf(result->localPath, MAX_PATH, L"%sACode_v%s_setup.exe", tempDir, result->latestVersion);

    HANDLE hFile = CreateFileW(result->localPath, GENERIC_WRITE, 0, NULL,
        CREATE_ALWAYS, FILE_ATTRIBUTE_NORMAL, NULL);
    if (hFile == INVALID_HANDLE_VALUE) {
        WinHttpCloseHandle(hRequest);
        WinHttpCloseHandle(hConnect);
        WinHttpCloseHandle(hSession);
        return false;
    }

    char buf[8192];
    DWORD bytesRead, bytesWritten;
    bool ok = true;

    while (WinHttpReadData(hRequest, buf, sizeof(buf), &bytesRead) && bytesRead > 0) {
        if (!WriteFile(hFile, buf, bytesRead, &bytesWritten, NULL)) {
            ok = false;
            break;
        }
    }

    CloseHandle(hFile);
    WinHttpCloseHandle(hRequest);
    WinHttpCloseHandle(hConnect);
    WinHttpCloseHandle(hSession);

    if (!ok) {
        DeleteFileW(result->localPath);
        result->localPath[0] = L'\0';
        return false;
    }

    result->downloaded = true;
    return true;
}
