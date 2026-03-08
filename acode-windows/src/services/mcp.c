#include "mcp.h"
#include "../utils/wstr.h"
#include <shlobj.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "cJSON.h"

/* ---------------------------------------------------------------
 * Config file paths
 * --------------------------------------------------------------- */
static void get_home_dir(wchar_t *buf, int bufLen) {
    SHGetFolderPathW(NULL, CSIDL_PROFILE, NULL, 0, buf);
}

static void get_codex_config_path(wchar_t *buf, int bufLen) {
    get_home_dir(buf, bufLen);
    wcscat_s(buf, bufLen, L"\\.codex\\config.toml");
}

static void get_claude_root_path(wchar_t *buf, int bufLen) {
    get_home_dir(buf, bufLen);
    wcscat_s(buf, bufLen, L"\\.claude.json");
}

static void get_claude_settings_path(wchar_t *buf, int bufLen) {
    get_home_dir(buf, bufLen);
    wcscat_s(buf, bufLen, L"\\.claude\\settings.json");
}

static void get_gemini_settings_path(wchar_t *buf, int bufLen) {
    get_home_dir(buf, bufLen);
    wcscat_s(buf, bufLen, L"\\.gemini\\settings.json");
}

/* ---------------------------------------------------------------
 * File helpers
 * --------------------------------------------------------------- */
static char *read_file_utf8(const wchar_t *path) {
    FILE *f = _wfopen(path, L"rb");
    if (!f) return NULL;
    fseek(f, 0, SEEK_END);
    long len = ftell(f);
    fseek(f, 0, SEEK_SET);
    if (len <= 0) { fclose(f); return NULL; }
    char *buf = (char *)malloc(len + 1);
    if (!buf) { fclose(f); return NULL; }
    fread(buf, 1, len, f);
    buf[len] = '\0';
    fclose(f);
    return buf;
}

static bool write_file_utf8(const wchar_t *path, const char *content) {
    /* Ensure parent directory exists */
    wchar_t dir[MAX_PATH];
    wcscpy_s(dir, MAX_PATH, path);
    wchar_t *lastSlash = wcsrchr(dir, L'\\');
    if (!lastSlash) lastSlash = wcsrchr(dir, L'/');
    if (lastSlash) {
        *lastSlash = L'\0';
        SHCreateDirectoryExW(NULL, dir, NULL);
    }

    FILE *f = _wfopen(path, L"wb");
    if (!f) return false;
    size_t len = strlen(content);
    fwrite(content, 1, len, f);
    fclose(f);
    return true;
}

/* ---------------------------------------------------------------
 * JSON config read/write
 * --------------------------------------------------------------- */
static int read_json_mcp_servers(const wchar_t *path, MCPServer *out, int maxCount, const char *sourceName) {
    char *content = read_file_utf8(path);
    if (!content) return 0;

    cJSON *root = cJSON_Parse(content);
    free(content);
    if (!root) return 0;

    cJSON *servers = cJSON_GetObjectItem(root, "mcpServers");
    if (!servers || !cJSON_IsObject(servers)) {
        cJSON_Delete(root);
        return 0;
    }

    int count = 0;
    cJSON *server = NULL;
    cJSON_ArrayForEach(server, servers) {
        if (count >= maxCount) break;
        const char *id = server->string;
        if (!id || !id[0]) continue;

        MCPServer *s = &out[count];
        memset(s, 0, sizeof(MCPServer));
        strncpy_s(s->id, MCP_MAX_ID_LEN, id, _TRUNCATE);

        /* Parse command/args or url */
        cJSON *cmd = cJSON_GetObjectItem(server, "command");
        cJSON *url = cJSON_GetObjectItem(server, "url");
        cJSON *httpUrl = cJSON_GetObjectItem(server, "httpUrl");
        cJSON *type = cJSON_GetObjectItem(server, "type");

        if (cmd && cJSON_IsString(cmd)) {
            s->transport = MCP_TRANSPORT_STDIO;
            strncpy_s(s->command, MCP_MAX_CMD_LEN, cmd->valuestring, _TRUNCATE);
            strncpy_s(s->summary, MCP_MAX_CMD_LEN, cmd->valuestring, _TRUNCATE);

            cJSON *args = cJSON_GetObjectItem(server, "args");
            if (args && cJSON_IsArray(args)) {
                int argIdx = 0;
                cJSON *arg = NULL;
                cJSON_ArrayForEach(arg, args) {
                    if (argIdx >= MCP_MAX_ARGS) break;
                    if (cJSON_IsString(arg)) {
                        strncpy_s(s->args[argIdx], MCP_MAX_ARG_LEN, arg->valuestring, _TRUNCATE);
                        argIdx++;
                    }
                }
                s->argCount = argIdx;
            }
        } else if (url && cJSON_IsString(url)) {
            if (type && cJSON_IsString(type) && _stricmp(type->valuestring, "http") == 0)
                s->transport = MCP_TRANSPORT_HTTP;
            else
                s->transport = MCP_TRANSPORT_SSE;
            strncpy_s(s->url, MCP_MAX_URL_LEN, url->valuestring, _TRUNCATE);
            strncpy_s(s->summary, MCP_MAX_CMD_LEN, url->valuestring, _TRUNCATE);
        } else if (httpUrl && cJSON_IsString(httpUrl)) {
            s->transport = MCP_TRANSPORT_HTTP;
            strncpy_s(s->url, MCP_MAX_URL_LEN, httpUrl->valuestring, _TRUNCATE);
            strncpy_s(s->summary, MCP_MAX_CMD_LEN, httpUrl->valuestring, _TRUNCATE);
        } else {
            s->transport = MCP_TRANSPORT_UNKNOWN;
            strncpy_s(s->summary, MCP_MAX_CMD_LEN, "configured", _TRUNCATE);
        }

        /* Add source */
        strncpy_s(s->sources[0], 16, sourceName, _TRUNCATE);
        s->sourceCount = 1;

        count++;
    }

    cJSON_Delete(root);
    return count;
}

static bool upsert_json_mcp_server(const wchar_t *path, const char *id, const MCPFormData *data) {
    cJSON *root = NULL;
    char *content = read_file_utf8(path);
    if (content) {
        root = cJSON_Parse(content);
        free(content);
    }
    if (!root) root = cJSON_CreateObject();

    cJSON *servers = cJSON_GetObjectItem(root, "mcpServers");
    if (!servers) {
        servers = cJSON_CreateObject();
        cJSON_AddItemToObject(root, "mcpServers", servers);
    }

    /* Remove existing */
    cJSON_DeleteItemFromObject(servers, id);

    /* Build spec */
    cJSON *spec = cJSON_CreateObject();
    if (data->transport == MCP_TRANSPORT_STDIO) {
        cJSON_AddStringToObject(spec, "command", data->command);
        if (data->argCount > 0) {
            cJSON *args = cJSON_CreateArray();
            for (int i = 0; i < data->argCount; i++)
                cJSON_AddItemToArray(args, cJSON_CreateString(data->args[i]));
            cJSON_AddItemToObject(spec, "args", args);
        }
    } else {
        const char *typeStr = (data->transport == MCP_TRANSPORT_HTTP) ? "http" : "sse";
        cJSON_AddStringToObject(spec, "type", typeStr);
        cJSON_AddStringToObject(spec, "url", data->url);
    }

    cJSON_AddItemToObject(servers, id, spec);

    char *output = cJSON_Print(root);
    cJSON_Delete(root);
    if (!output) return false;

    bool ok = write_file_utf8(path, output);
    free(output);
    return ok;
}

static bool remove_json_mcp_server(const wchar_t *path, const char *id) {
    char *content = read_file_utf8(path);
    if (!content) return true; /* file doesn't exist, nothing to remove */

    cJSON *root = cJSON_Parse(content);
    free(content);
    if (!root) return true;

    cJSON *servers = cJSON_GetObjectItem(root, "mcpServers");
    if (!servers) { cJSON_Delete(root); return true; }

    cJSON_DeleteItemFromObject(servers, id);

    /* If mcpServers is empty, remove it */
    if (cJSON_GetArraySize(servers) == 0)
        cJSON_DeleteItemFromObject(root, "mcpServers");

    char *output = cJSON_Print(root);
    cJSON_Delete(root);
    if (!output) return false;

    bool ok = write_file_utf8(path, output);
    free(output);
    return ok;
}

/* ---------------------------------------------------------------
 * TOML config read/write (simple parser for [mcp_servers.xxx])
 * --------------------------------------------------------------- */
static int read_codex_mcp_servers(MCPServer *out, int maxCount) {
    wchar_t path[MAX_PATH];
    get_codex_config_path(path, MAX_PATH);

    char *content = read_file_utf8(path);
    if (!content) return 0;

    int count = 0;
    char *line = content;
    MCPServer *cur = NULL;

    while (line && *line && count < maxCount) {
        char *eol = strchr(line, '\n');
        char lineBuf[1024];
        int lineLen = eol ? (int)(eol - line) : (int)strlen(line);
        if (lineLen >= (int)sizeof(lineBuf)) lineLen = sizeof(lineBuf) - 1;
        memcpy(lineBuf, line, lineLen);
        lineBuf[lineLen] = '\0';

        /* Trim \r */
        int lb = (int)strlen(lineBuf);
        while (lb > 0 && (lineBuf[lb-1] == '\r' || lineBuf[lb-1] == '\n')) lineBuf[--lb] = '\0';

        /* Check for [mcp_servers.xxx] section header */
        if (lineBuf[0] == '[') {
            const char *prefix = "[mcp_servers.";
            int prefixLen = (int)strlen(prefix);
            if (strncmp(lineBuf, prefix, prefixLen) == 0 && lineBuf[lb-1] == ']') {
                char serverName[MCP_MAX_ID_LEN];
                int nameLen = lb - 1 - prefixLen;
                if (nameLen > 0 && nameLen < MCP_MAX_ID_LEN) {
                    memcpy(serverName, lineBuf + prefixLen, nameLen);
                    serverName[nameLen] = '\0';

                    cur = &out[count];
                    memset(cur, 0, sizeof(MCPServer));
                    strncpy_s(cur->id, MCP_MAX_ID_LEN, serverName, _TRUNCATE);
                    cur->transport = MCP_TRANSPORT_STDIO;
                    strncpy_s(cur->sources[0], 16, "codex", _TRUNCATE);
                    cur->sourceCount = 1;
                    count++;
                }
            } else if (cur) {
                /* Another section, stop current server */
                cur = NULL;
            }
        } else if (cur && strchr(lineBuf, '=')) {
            /* Parse key = value */
            char *eq = strchr(lineBuf, '=');
            *eq = '\0';
            char *key = lineBuf;
            char *val = eq + 1;

            /* Trim */
            while (*key == ' ' || *key == '\t') key++;
            int kl = (int)strlen(key);
            while (kl > 0 && (key[kl-1] == ' ' || key[kl-1] == '\t')) key[--kl] = '\0';

            while (*val == ' ' || *val == '\t') val++;
            int vl = (int)strlen(val);
            while (vl > 0 && (val[vl-1] == ' ' || val[vl-1] == '\t')) val[--vl] = '\0';

            if (strcmp(key, "command") == 0 && val[0] == '"') {
                /* Remove quotes */
                val++; vl--;
                if (vl > 0 && val[vl-1] == '"') val[vl-1] = '\0';
                strncpy_s(cur->command, MCP_MAX_CMD_LEN, val, _TRUNCATE);
                strncpy_s(cur->summary, MCP_MAX_CMD_LEN, val, _TRUNCATE);
            } else if (strcmp(key, "args") == 0 && val[0] == '[') {
                /* Simple array parse: ["a", "b"] */
                char *p = val + 1;
                int argIdx = 0;
                while (*p && *p != ']' && argIdx < MCP_MAX_ARGS) {
                    while (*p == ' ' || *p == ',') p++;
                    if (*p == '"') {
                        p++;
                        char *end = strchr(p, '"');
                        if (end) {
                            int al = (int)(end - p);
                            if (al < MCP_MAX_ARG_LEN) {
                                memcpy(cur->args[argIdx], p, al);
                                cur->args[argIdx][al] = '\0';
                                argIdx++;
                            }
                            p = end + 1;
                        } else break;
                    } else break;
                }
                cur->argCount = argIdx;
            } else if (strcmp(key, "type") == 0 && val[0] == '"') {
                val++; vl--;
                if (vl > 0 && val[vl-1] == '"') val[vl-1] = '\0';
                if (_stricmp(val, "http") == 0) cur->transport = MCP_TRANSPORT_HTTP;
                else if (_stricmp(val, "sse") == 0) cur->transport = MCP_TRANSPORT_SSE;
            } else if (strcmp(key, "url") == 0 && val[0] == '"') {
                val++; vl--;
                if (vl > 0 && val[vl-1] == '"') val[vl-1] = '\0';
                strncpy_s(cur->url, MCP_MAX_URL_LEN, val, _TRUNCATE);
                strncpy_s(cur->summary, MCP_MAX_CMD_LEN, val, _TRUNCATE);
            }
        }

        line = eol ? eol + 1 : NULL;
    }

    free(content);
    return count;
}

/* Escape a string for TOML */
static void toml_escape(char *out, int outLen, const char *in) {
    int j = 0;
    for (int i = 0; in[i] && j < outLen - 2; i++) {
        if (in[i] == '\\' || in[i] == '"') {
            out[j++] = '\\';
        }
        out[j++] = in[i];
    }
    out[j] = '\0';
}

/* Remove a [section] from TOML content */
static char *toml_remove_section(const char *content, const char *sectionName) {
    int contentLen = (int)strlen(content);
    char *result = (char *)malloc(contentLen + 1);
    if (!result) return NULL;

    char header[256];
    _snprintf_s(header, 256, _TRUNCATE, "[%s]", sectionName);

    const char *line = content;
    int outPos = 0;
    bool skipping = false;

    while (line && *line) {
        const char *eol = strchr(line, '\n');
        int lineLen = eol ? (int)(eol - line + 1) : (int)strlen(line);

        /* Check if line starts with our header */
        char lineBuf[512];
        int copyLen = lineLen < 511 ? lineLen : 511;
        memcpy(lineBuf, line, copyLen);
        lineBuf[copyLen] = '\0';
        /* Trim trailing whitespace */
        int lb = (int)strlen(lineBuf);
        while (lb > 0 && (lineBuf[lb-1] == '\r' || lineBuf[lb-1] == '\n' || lineBuf[lb-1] == ' ')) lb--;
        lineBuf[lb] = '\0';

        if (strcmp(lineBuf, header) == 0) {
            skipping = true;
        } else if (skipping && lineBuf[0] == '[') {
            skipping = false;
        }

        if (!skipping) {
            memcpy(result + outPos, line, lineLen);
            outPos += lineLen;
        }

        line = eol ? eol + 1 : NULL;
    }

    result[outPos] = '\0';

    /* Trim trailing newlines */
    while (outPos > 0 && (result[outPos-1] == '\n' || result[outPos-1] == '\r'))
        result[--outPos] = '\0';

    return result;
}

static bool upsert_codex_mcp_server(const char *id, const MCPFormData *data) {
    wchar_t path[MAX_PATH];
    get_codex_config_path(path, MAX_PATH);

    char *content = read_file_utf8(path);
    if (!content) {
        content = _strdup("");
        if (!content) return false;
    }

    /* Remove existing section */
    char sectionName[256];
    _snprintf_s(sectionName, 256, _TRUNCATE, "mcp_servers.%s", id);
    char *cleaned = toml_remove_section(content, sectionName);
    free(content);
    if (!cleaned) return false;

    /* Build new section */
    char section[4096];
    int pos = 0;
    pos += _snprintf_s(section + pos, 4096 - pos, _TRUNCATE, "\n[mcp_servers.%s]\n", id);

    if (data->transport == MCP_TRANSPORT_STDIO) {
        char escaped[MCP_MAX_CMD_LEN];
        toml_escape(escaped, MCP_MAX_CMD_LEN, data->command);
        pos += _snprintf_s(section + pos, 4096 - pos, _TRUNCATE, "command = \"%s\"\n", escaped);

        if (data->argCount > 0) {
            pos += _snprintf_s(section + pos, 4096 - pos, _TRUNCATE, "args = [");
            for (int i = 0; i < data->argCount; i++) {
                char escapedArg[MCP_MAX_ARG_LEN];
                toml_escape(escapedArg, MCP_MAX_ARG_LEN, data->args[i]);
                if (i > 0) pos += _snprintf_s(section + pos, 4096 - pos, _TRUNCATE, ", ");
                pos += _snprintf_s(section + pos, 4096 - pos, _TRUNCATE, "\"%s\"", escapedArg);
            }
            pos += _snprintf_s(section + pos, 4096 - pos, _TRUNCATE, "]\n");
        }
    } else {
        const char *typeStr = (data->transport == MCP_TRANSPORT_HTTP) ? "http" : "sse";
        pos += _snprintf_s(section + pos, 4096 - pos, _TRUNCATE, "type = \"%s\"\n", typeStr);
        char escaped[MCP_MAX_URL_LEN];
        toml_escape(escaped, MCP_MAX_URL_LEN, data->url);
        pos += _snprintf_s(section + pos, 4096 - pos, _TRUNCATE, "url = \"%s\"\n", escaped);
    }

    /* Concatenate */
    int totalLen = (int)strlen(cleaned) + pos + 2;
    char *output = (char *)malloc(totalLen);
    if (!output) { free(cleaned); return false; }
    _snprintf_s(output, totalLen, _TRUNCATE, "%s%s", cleaned, section);
    free(cleaned);

    bool ok = write_file_utf8(path, output);
    free(output);
    return ok;
}

static bool remove_codex_mcp_server(const char *id) {
    wchar_t path[MAX_PATH];
    get_codex_config_path(path, MAX_PATH);

    char *content = read_file_utf8(path);
    if (!content) return true;

    char sectionName[256];
    _snprintf_s(sectionName, 256, _TRUNCATE, "mcp_servers.%s", id);
    char *cleaned = toml_remove_section(content, sectionName);
    free(content);
    if (!cleaned) return false;

    bool ok = write_file_utf8(path, cleaned);
    free(cleaned);
    return ok;
}

/* ---------------------------------------------------------------
 * Merge servers from all sources
 * --------------------------------------------------------------- */
static void merge_server(MCPServer *merged, int *mergedCount, int maxCount,
                         const MCPServer *src, const char *source) {
    /* Check if already exists */
    for (int i = 0; i < *mergedCount; i++) {
        if (strcmp(merged[i].id, src->id) == 0) {
            /* Add source if not already present */
            for (int j = 0; j < merged[i].sourceCount; j++) {
                if (strcmp(merged[i].sources[j], source) == 0) return;
            }
            if (merged[i].sourceCount < MCP_MAX_SOURCES) {
                strncpy_s(merged[i].sources[merged[i].sourceCount], 16, source, _TRUNCATE);
                merged[i].sourceCount++;
            }
            return;
        }
    }

    /* New server */
    if (*mergedCount >= maxCount) return;
    memcpy(&merged[*mergedCount], src, sizeof(MCPServer));
    /* Ensure source is set */
    merged[*mergedCount].sourceCount = 1;
    strncpy_s(merged[*mergedCount].sources[0], 16, source, _TRUNCATE);
    (*mergedCount)++;
}

/* ---------------------------------------------------------------
 * Public API
 * --------------------------------------------------------------- */
int mcp_list_servers(MCPServer *out, int maxCount) {
    int mergedCount = 0;

    /* Codex TOML */
    MCPServer codexBuf[MCP_MAX_SERVERS];
    int codexCount = read_codex_mcp_servers(codexBuf, MCP_MAX_SERVERS);
    for (int i = 0; i < codexCount; i++)
        merge_server(out, &mergedCount, maxCount, &codexBuf[i], "codex");

    /* Claude .claude.json */
    wchar_t claudeRoot[MAX_PATH];
    get_claude_root_path(claudeRoot, MAX_PATH);
    MCPServer claudeBuf[MCP_MAX_SERVERS];
    int claudeCount = read_json_mcp_servers(claudeRoot, claudeBuf, MCP_MAX_SERVERS, "claude");
    for (int i = 0; i < claudeCount; i++)
        merge_server(out, &mergedCount, maxCount, &claudeBuf[i], "claude");

    /* Claude settings */
    wchar_t claudeSettings[MAX_PATH];
    get_claude_settings_path(claudeSettings, MAX_PATH);
    MCPServer claudeSetBuf[MCP_MAX_SERVERS];
    int claudeSetCount = read_json_mcp_servers(claudeSettings, claudeSetBuf, MCP_MAX_SERVERS, "claude");
    for (int i = 0; i < claudeSetCount; i++)
        merge_server(out, &mergedCount, maxCount, &claudeSetBuf[i], "claude");

    /* Gemini */
    wchar_t gemini[MAX_PATH];
    get_gemini_settings_path(gemini, MAX_PATH);
    MCPServer geminiBuf[MCP_MAX_SERVERS];
    int geminiCount = read_json_mcp_servers(gemini, geminiBuf, MCP_MAX_SERVERS, "gemini");
    for (int i = 0; i < geminiCount; i++)
        merge_server(out, &mergedCount, maxCount, &geminiBuf[i], "gemini");

    /* Sort by id */
    for (int i = 0; i < mergedCount - 1; i++)
        for (int j = i + 1; j < mergedCount; j++)
            if (strcmp(out[i].id, out[j].id) > 0) {
                MCPServer tmp = out[i]; out[i] = out[j]; out[j] = tmp;
            }

    return mergedCount;
}

bool mcp_upsert_server(const MCPFormData *data) {
    if (!data || !data->id[0]) return false;

    wchar_t claudeRoot[MAX_PATH], claudeSettings[MAX_PATH], gemini[MAX_PATH];
    get_claude_root_path(claudeRoot, MAX_PATH);
    get_claude_settings_path(claudeSettings, MAX_PATH);
    get_gemini_settings_path(gemini, MAX_PATH);

    /* Write to all config files */
    bool ok = true;
    ok = upsert_codex_mcp_server(data->id, data) && ok;
    ok = upsert_json_mcp_server(claudeRoot, data->id, data) && ok;
    ok = upsert_json_mcp_server(claudeSettings, data->id, data) && ok;
    ok = upsert_json_mcp_server(gemini, data->id, data) && ok;
    return ok;
}

bool mcp_delete_server(const char *id) {
    if (!id || !id[0]) return false;

    wchar_t claudeRoot[MAX_PATH], claudeSettings[MAX_PATH], gemini[MAX_PATH];
    get_claude_root_path(claudeRoot, MAX_PATH);
    get_claude_settings_path(claudeSettings, MAX_PATH);
    get_gemini_settings_path(gemini, MAX_PATH);

    remove_codex_mcp_server(id);
    remove_json_mcp_server(claudeRoot, id);
    remove_json_mcp_server(claudeSettings, id);
    remove_json_mcp_server(gemini, id);
    return true;
}

bool mcp_toggle_app(const char *app, const char *id, bool enabled) {
    if (!app || !id || !id[0]) return false;

    /* Find existing server to get spec */
    MCPServer servers[MCP_MAX_SERVERS];
    int count = mcp_list_servers(servers, MCP_MAX_SERVERS);
    MCPServer *found = NULL;
    for (int i = 0; i < count; i++) {
        if (strcmp(servers[i].id, id) == 0) { found = &servers[i]; break; }
    }
    if (!found) return false;

    MCPFormData data;
    memset(&data, 0, sizeof(data));
    strncpy_s(data.id, MCP_MAX_ID_LEN, found->id, _TRUNCATE);
    data.transport = found->transport;
    strncpy_s(data.command, MCP_MAX_CMD_LEN, found->command, _TRUNCATE);
    memcpy(data.args, found->args, sizeof(data.args));
    data.argCount = found->argCount;
    strncpy_s(data.url, MCP_MAX_URL_LEN, found->url, _TRUNCATE);

    if (strcmp(app, "claude") == 0) {
        wchar_t p1[MAX_PATH], p2[MAX_PATH];
        get_claude_root_path(p1, MAX_PATH);
        get_claude_settings_path(p2, MAX_PATH);
        if (enabled) {
            upsert_json_mcp_server(p1, id, &data);
            upsert_json_mcp_server(p2, id, &data);
        } else {
            remove_json_mcp_server(p1, id);
            remove_json_mcp_server(p2, id);
        }
    } else if (strcmp(app, "codex") == 0) {
        if (enabled) upsert_codex_mcp_server(id, &data);
        else remove_codex_mcp_server(id);
    } else if (strcmp(app, "gemini") == 0) {
        wchar_t p[MAX_PATH];
        get_gemini_settings_path(p, MAX_PATH);
        if (enabled) upsert_json_mcp_server(p, id, &data);
        else remove_json_mcp_server(p, id);
    }

    return true;
}

/* ---------------------------------------------------------------
 * Presets
 * --------------------------------------------------------------- */
static const MCPPreset s_presets[] = {
    {
        "fetch", "mcp-server-fetch",
        "\xe9\x80\x9a\xe8\xbf\x87 HTTP \xe8\x8e\xb7\xe5\x8f\x96\xe7\xbd\x91\xe9\xa1\xb5\xe5\x86\x85\xe5\xae\xb9\xe5\xb9\xb6\xe6\x8f\x90\xe5\x8f\x96\xe6\x96\x87\xe6\x9c\xac\xe3\x80\x82",
        "stdio", "uvx", { "mcp-server-fetch" }, 1
    },
    {
        "time", "@modelcontextprotocol/server-time",
        "\xe8\x8e\xb7\xe5\x8f\x96\xe5\xbd\x93\xe5\x89\x8d\xe6\x97\xb6\xe9\x97\xb4\xe5\x92\x8c\xe6\x97\xb6\xe5\x8c\xba\xe8\xbd\xac\xe6\x8d\xa2\xe3\x80\x82",
        "stdio", "npx", { "-y", "@modelcontextprotocol/server-time" }, 2
    },
    {
        "memory", "@modelcontextprotocol/server-memory",
        "\xe5\x9f\xba\xe4\xba\x8e\xe7\x9f\xa5\xe8\xaf\x86\xe5\x9b\xbe\xe8\xb0\xb1\xe7\x9a\x84\xe6\x8c\x81\xe4\xb9\x85\xe5\x8c\x96\xe8\xae\xb0\xe5\xbf\x86\xe5\xad\x98\xe5\x82\xa8\xe3\x80\x82",
        "stdio", "npx", { "-y", "@modelcontextprotocol/server-memory" }, 2
    },
    {
        "sequential-thinking", "@modelcontextprotocol/server-sequential-thinking",
        "\xe9\x80\x90\xe6\xad\xa5\xe6\x8e\xa8\xe7\x90\x86\xe4\xb8\x8e\xe7\xbb\x93\xe6\x9e\x84\xe5\x8c\x96\xe6\x80\x9d\xe8\x80\x83\xe3\x80\x82",
        "stdio", "npx", { "-y", "@modelcontextprotocol/server-sequential-thinking" }, 2
    },
    {
        "context7", "@upstash/context7-mcp",
        "\xe4\xbb\x8e\xe6\x96\x87\xe6\xa1\xa3\xe5\xba\x93\xe4\xb8\xad\xe6\xa3\x80\xe7\xb4\xa2\xe4\xbb\xa3\xe7\xa0\x81\xe4\xb8\x8a\xe4\xb8\x8b\xe6\x96\x87\xe5\x92\x8c\xe7\xa4\xba\xe4\xbe\x8b\xe3\x80\x82",
        "stdio", "npx", { "-y", "@upstash/context7-mcp" }, 2
    },
};

const MCPPreset *mcp_get_presets(int *count) {
    if (count) *count = sizeof(s_presets) / sizeof(s_presets[0]);
    return s_presets;
}
