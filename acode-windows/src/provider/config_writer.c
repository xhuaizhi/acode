#include "config_writer.h"
#include "../utils/path.h"
#include "../utils/wstr.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <shlobj.h>
#include <cJSON.h>

/* ---------------------------------------------------------------
 * 原子写入：先写 .tmp 文件，再 rename 到目标路径
 * --------------------------------------------------------------- */
static bool write_file_atomic(const wchar_t *path, const char *content) {
    wchar_t tmpPath[MAX_PATH];
    _snwprintf(tmpPath, MAX_PATH, L"%s.tmp", path);

    char pathUtf8[MAX_PATH * 2];
    wstr_to_utf8(tmpPath, pathUtf8, sizeof(pathUtf8));

    FILE *f = fopen(pathUtf8, "wb");
    if (!f) return false;
    fwrite(content, 1, strlen(content), f);
    fclose(f);

    /* rename: 先删目标（Windows rename 不覆盖已存在文件） */
    char dstUtf8[MAX_PATH * 2];
    wstr_to_utf8(path, dstUtf8, sizeof(dstUtf8));
    remove(dstUtf8);
    return rename(pathUtf8, dstUtf8) == 0;
}

/* ---------------------------------------------------------------
 * 读取现有 JSON 文件，返回 cJSON 对象（调用方负责 cJSON_Delete）
 * 文件不存在或解析失败时返回空 JSON 对象 {}
 * --------------------------------------------------------------- */
static cJSON *read_json_file(const wchar_t *path) {
    char pathUtf8[MAX_PATH * 2];
    wstr_to_utf8(path, pathUtf8, sizeof(pathUtf8));

    FILE *f = fopen(pathUtf8, "rb");
    if (!f) return cJSON_CreateObject();

    fseek(f, 0, SEEK_END);
    long size = ftell(f);
    fseek(f, 0, SEEK_SET);

    if (size <= 0 || size > 1024 * 1024) { fclose(f); return cJSON_CreateObject(); }

    char *buf = (char *)malloc(size + 1);
    if (!buf) { fclose(f); return cJSON_CreateObject(); }
    fread(buf, 1, size, f);
    buf[size] = '\0';
    fclose(f);

    cJSON *root = cJSON_Parse(buf);
    free(buf);
    return root ? root : cJSON_CreateObject();
}

/* ---------------------------------------------------------------
 * Claude Code → ~/.claude/settings.json
 * 合并写入：读取现有配置，更新 env 字段，不覆盖用户其他配置
 * --------------------------------------------------------------- */
static bool write_claude_config(const Provider *p) {
    wchar_t home[MAX_PATH];
    path_get_home(home, MAX_PATH);

    wchar_t configDir[MAX_PATH];
    path_join(configDir, MAX_PATH, home, L".claude");
    path_ensure_directory(configDir);

    wchar_t configPath[MAX_PATH];
    path_join(configPath, MAX_PATH, configDir, L"settings.json");

    /* 读取现有配置 */
    cJSON *root = read_json_file(configPath);

    /* 获取或创建 env 对象 */
    cJSON *env = cJSON_GetObjectItem(root, "env");
    if (!env) {
        env = cJSON_CreateObject();
        cJSON_AddItemToObject(root, "env", env);
    }

    /* 写入 API Key */
    if (p->apiKey[0]) {
        cJSON_DeleteItemFromObject(env, "ANTHROPIC_API_KEY");
        cJSON_AddStringToObject(env, "ANTHROPIC_API_KEY", p->apiKey);
    }

    /* 写入/删除 API Base URL */
    cJSON_DeleteItemFromObject(env, "ANTHROPIC_BASE_URL");
    if (p->apiBase[0]) {
        cJSON_AddStringToObject(env, "ANTHROPIC_BASE_URL", p->apiBase);
    }

    /* 写入模型 */
    if (p->model[0]) {
        cJSON_DeleteItemFromObject(root, "model");
        cJSON_AddStringToObject(root, "model", p->model);
    }

    /* 合并 extra_env（跳过 ACODE_ 前缀内部变量） */
    if (p->extraEnv[0] && strcmp(p->extraEnv, "{}") != 0) {
        cJSON *extra = cJSON_Parse(p->extraEnv);
        if (extra && cJSON_IsObject(extra)) {
            cJSON *item = NULL;
            cJSON_ArrayForEach(item, extra) {
                if (strncmp(item->string, "ACODE_", 6) == 0) continue;
                cJSON_DeleteItemFromObject(env, item->string);
                cJSON_AddItemToObject(env, item->string, cJSON_Duplicate(item, 1));
            }
        }
        cJSON_Delete(extra);
    }

    char *out = cJSON_Print(root);
    cJSON_Delete(root);
    if (!out) return false;

    bool ok = write_file_atomic(configPath, out);
    free(out);
    return ok;
}

/* ---------------------------------------------------------------
 * OpenAI Codex → ~/.codex/auth.json + config.toml
 * 第三方端点生成完整 model_providers section（与 Mac 版一致）
 * --------------------------------------------------------------- */
static void normalize_codex_base_url(const char *in, char *out, int outLen) {
    /* 去除尾部 '/' */
    strncpy(out, in, outLen - 1);
    out[outLen - 1] = '\0';
    int len = (int)strlen(out);
    while (len > 0 && out[len - 1] == '/') out[--len] = '\0';

    /* 若不以 /v1 结尾且无路径，自动补 /v1 */
    if (len >= 3 && strcmp(out + len - 3, "/v1") != 0) {
        /* 简单判断：如果路径段为空（只有 scheme://host 或 scheme://host:port） */
        const char *afterScheme = strstr(out, "://");
        if (afterScheme) {
            const char *pathStart = strchr(afterScheme + 3, '/');
            if (!pathStart || strcmp(pathStart, "/") == 0) {
                strncat(out, "/v1", outLen - len - 1);
            }
        }
    }
}

static bool write_openai_config(const Provider *p) {
    wchar_t home[MAX_PATH];
    path_get_home(home, MAX_PATH);

    wchar_t configDir[MAX_PATH];
    path_join(configDir, MAX_PATH, home, L".codex");
    path_ensure_directory(configDir);

    /* 1. auth.json — 合并写入 */
    if (p->apiKey[0]) {
        wchar_t authPath[MAX_PATH];
        path_join(authPath, MAX_PATH, configDir, L"auth.json");

        cJSON *auth = read_json_file(authPath);
        cJSON_DeleteItemFromObject(auth, "OPENAI_API_KEY");
        cJSON_AddStringToObject(auth, "OPENAI_API_KEY", p->apiKey);

        char *out = cJSON_Print(auth);
        cJSON_Delete(auth);
        if (out) {
            write_file_atomic(authPath, out);
            free(out);
        }
    }

    /* 2. config.toml */
    wchar_t tomlPath[MAX_PATH];
    path_join(tomlPath, MAX_PATH, configDir, L"config.toml");

    const char *model = p->model[0] ? p->model : "o4-mini";
    char toml[2048];

    if (!p->apiBase[0]) {
        /* 官方端点：简单格式 */
        snprintf(toml, sizeof(toml), "model = \"%s\"\n", model);
    } else {
        /* 第三方端点：完整 model_providers section */
        char baseUrl[512];
        normalize_codex_base_url(p->apiBase, baseUrl, sizeof(baseUrl));
        snprintf(toml, sizeof(toml),
            "model_provider = \"acode_provider\"\n"
            "model = \"%s\"\n"
            "disable_response_storage = true\n"
            "\n"
            "[model_providers.acode_provider]\n"
            "name = \"%s\"\n"
            "base_url = \"%s\"\n"
            "wire_api = \"responses\"\n"
            "requires_openai_auth = true\n",
            model, p->name, baseUrl);
    }

    return write_file_atomic(tomlPath, toml);
}

/* ---------------------------------------------------------------
 * Gemini CLI → ~/.gemini/.env + settings.json
 * 合并写入 .env，不覆盖非托管字段；写 settings.json 认证类型
 * --------------------------------------------------------------- */

/* 解析 .env 文件为键值对数组，返回行数 */
typedef struct { char key[256]; char value[1024]; } EnvEntry;

static int parse_env_file(const wchar_t *path, EnvEntry *entries, int maxEntries) {
    char pathUtf8[MAX_PATH * 2];
    wstr_to_utf8(path, pathUtf8, sizeof(pathUtf8));

    FILE *f = fopen(pathUtf8, "rb");
    if (!f) return 0;

    int count = 0;
    char line[2048];
    while (fgets(line, sizeof(line), f) && count < maxEntries) {
        /* 去除换行 */
        int len = (int)strlen(line);
        while (len > 0 && (line[len-1] == '\n' || line[len-1] == '\r')) line[--len] = '\0';

        if (!line[0] || line[0] == '#') continue;
        char *eq = strchr(line, '=');
        if (!eq) continue;

        *eq = '\0';
        /* 去首尾空格 */
        char *k = line; while (*k == ' ') k++;
        int klen = (int)strlen(k); while (klen > 0 && k[klen-1] == ' ') k[--klen] = '\0';
        char *v = eq + 1; while (*v == ' ') v++;

        strncpy(entries[count].key, k, sizeof(entries[count].key) - 1);
        strncpy(entries[count].value, v, sizeof(entries[count].value) - 1);
        count++;
    }
    fclose(f);
    return count;
}

static void env_set(EnvEntry *entries, int *count, int max, const char *key, const char *value) {
    for (int i = 0; i < *count; i++) {
        if (strcmp(entries[i].key, key) == 0) {
            strncpy(entries[i].value, value, sizeof(entries[i].value) - 1);
            return;
        }
    }
    if (*count < max) {
        strncpy(entries[*count].key, key, sizeof(entries[*count].key) - 1);
        strncpy(entries[*count].value, value, sizeof(entries[*count].value) - 1);
        (*count)++;
    }
}

static void env_remove(EnvEntry *entries, int *count, const char *key) {
    for (int i = 0; i < *count; i++) {
        if (strcmp(entries[i].key, key) == 0) {
            for (int j = i; j < *count - 1; j++) entries[j] = entries[j+1];
            (*count)--;
            return;
        }
    }
}

static bool write_gemini_config(const Provider *p) {
    wchar_t home[MAX_PATH];
    path_get_home(home, MAX_PATH);

    wchar_t configDir[MAX_PATH];
    path_join(configDir, MAX_PATH, home, L".gemini");
    path_ensure_directory(configDir);

    /* 1. 合并写入 .env */
    wchar_t envPath[MAX_PATH];
    path_join(envPath, MAX_PATH, configDir, L".env");

    EnvEntry entries[128];
    int count = parse_env_file(envPath, entries, 128);

    if (p->apiKey[0])  env_set(entries, &count, 128, "GEMINI_API_KEY", p->apiKey);
    if (p->apiBase[0]) env_set(entries, &count, 128, "GOOGLE_GEMINI_BASE_URL", p->apiBase);
    else               env_remove(entries, &count, "GOOGLE_GEMINI_BASE_URL");
    if (p->model[0])   env_set(entries, &count, 128, "GEMINI_MODEL", p->model);

    /* 合并 extra_env */
    if (p->extraEnv[0] && strcmp(p->extraEnv, "{}") != 0) {
        cJSON *extra = cJSON_Parse(p->extraEnv);
        if (extra && cJSON_IsObject(extra)) {
            cJSON *item = NULL;
            cJSON_ArrayForEach(item, extra) {
                if (cJSON_IsString(item))
                    env_set(entries, &count, 128, item->string, item->valuestring);
            }
        }
        cJSON_Delete(extra);
    }

    /* 序列化：优先核心键排在前面 */
    char envContent[16384] = "";
    const char *priorityKeys[] = { "GEMINI_API_KEY", "GOOGLE_GEMINI_BASE_URL", "GEMINI_MODEL" };
    for (int k = 0; k < 3; k++) {
        for (int i = 0; i < count; i++) {
            if (strcmp(entries[i].key, priorityKeys[k]) == 0) {
                char line[1280];
                snprintf(line, sizeof(line), "%s=%s\n", entries[i].key, entries[i].value);
                strncat(envContent, line, sizeof(envContent) - strlen(envContent) - 1);
                break;
            }
        }
    }
    for (int i = 0; i < count; i++) {
        bool isPriority = false;
        for (int k = 0; k < 3; k++)
            if (strcmp(entries[i].key, priorityKeys[k]) == 0) { isPriority = true; break; }
        if (!isPriority) {
            char line[1280];
            snprintf(line, sizeof(line), "%s=%s\n", entries[i].key, entries[i].value);
            strncat(envContent, line, sizeof(envContent) - strlen(envContent) - 1);
        }
    }
    write_file_atomic(envPath, envContent);

    /* 2. 写 settings.json — 设置认证类型（仅当有 API Key 时） */
    if (p->apiKey[0]) {
        wchar_t settingsPath[MAX_PATH];
        path_join(settingsPath, MAX_PATH, configDir, L"settings.json");

        cJSON *root = read_json_file(settingsPath);

        cJSON *security = cJSON_GetObjectItem(root, "security");
        if (!security) {
            security = cJSON_CreateObject();
            cJSON_AddItemToObject(root, "security", security);
        }
        cJSON *auth = cJSON_GetObjectItem(security, "auth");
        if (!auth) {
            auth = cJSON_CreateObject();
            cJSON_AddItemToObject(security, "auth", auth);
        }
        cJSON_DeleteItemFromObject(auth, "selectedType");
        cJSON_AddStringToObject(auth, "selectedType", "gemini-api-key");

        char *out = cJSON_Print(root);
        cJSON_Delete(root);
        if (out) {
            write_file_atomic(settingsPath, out);
            free(out);
        }
    }

    return true;
}

bool config_writer_write(const Provider *p) {
    if (!p) return false;

    if (strcmp(p->tool, "claude_code") == 0)
        return write_claude_config(p);
    if (strcmp(p->tool, "openai") == 0)
        return write_openai_config(p);
    if (strcmp(p->tool, "gemini") == 0)
        return write_gemini_config(p);

    return false;
}
