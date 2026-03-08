#include "skills.h"
#include "../app.h"
#include <shlobj.h>
#include <stdio.h>
#include <string.h>
#include <stdlib.h>
#include "cJSON.h"

/* ---------------------------------------------------------------
 * Storage paths
 * --------------------------------------------------------------- */
static void get_skills_index_path(wchar_t *buf, int bufLen) {
    wcscpy_s(buf, bufLen, g_app.appDataPath);
    wcscat_s(buf, bufLen, L"\\skills\\index.json");
}

static void get_home_dir(wchar_t *buf, int bufLen) {
    SHGetFolderPathW(NULL, CSIDL_PROFILE, NULL, 0, buf);
}

static void get_claude_instructions_path(wchar_t *buf, int bufLen) {
    get_home_dir(buf, bufLen);
    wcscat_s(buf, bufLen, L"\\.claude\\CLAUDE.md");
}

static void get_codex_instructions_path(wchar_t *buf, int bufLen) {
    get_home_dir(buf, bufLen);
    wcscat_s(buf, bufLen, L"\\.codex\\instructions.md");
}

static void get_gemini_instructions_path(wchar_t *buf, int bufLen) {
    get_home_dir(buf, bufLen);
    wcscat_s(buf, bufLen, L"\\.gemini\\GEMINI.md");
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
 * JSON persistence
 * --------------------------------------------------------------- */
static cJSON *skill_to_json(const Skill *s) {
    cJSON *obj = cJSON_CreateObject();
    cJSON_AddStringToObject(obj, "id", s->id);
    cJSON_AddStringToObject(obj, "name", s->name);
    cJSON_AddStringToObject(obj, "description", s->description);
    cJSON_AddStringToObject(obj, "content", s->content);

    cJSON *apps = cJSON_CreateArray();
    if (s->enabledClaude) cJSON_AddItemToArray(apps, cJSON_CreateString("claude"));
    if (s->enabledCodex)  cJSON_AddItemToArray(apps, cJSON_CreateString("codex"));
    if (s->enabledGemini) cJSON_AddItemToArray(apps, cJSON_CreateString("gemini"));
    cJSON_AddItemToObject(obj, "enabledApps", apps);
    return obj;
}

static void json_to_skill(const cJSON *obj, Skill *s) {
    memset(s, 0, sizeof(Skill));
    cJSON *id   = cJSON_GetObjectItem(obj, "id");
    cJSON *name = cJSON_GetObjectItem(obj, "name");
    cJSON *desc = cJSON_GetObjectItem(obj, "description");
    cJSON *cont = cJSON_GetObjectItem(obj, "content");
    cJSON *apps = cJSON_GetObjectItem(obj, "enabledApps");

    if (id && cJSON_IsString(id))     strncpy_s(s->id, SKILL_MAX_ID_LEN, id->valuestring, _TRUNCATE);
    if (name && cJSON_IsString(name)) strncpy_s(s->name, SKILL_MAX_NAME_LEN, name->valuestring, _TRUNCATE);
    if (desc && cJSON_IsString(desc)) strncpy_s(s->description, SKILL_MAX_DESC_LEN, desc->valuestring, _TRUNCATE);
    if (cont && cJSON_IsString(cont)) strncpy_s(s->content, SKILL_MAX_CONTENT, cont->valuestring, _TRUNCATE);

    if (apps && cJSON_IsArray(apps)) {
        cJSON *item = NULL;
        cJSON_ArrayForEach(item, apps) {
            if (!cJSON_IsString(item)) continue;
            if (strcmp(item->valuestring, "claude") == 0) s->enabledClaude = true;
            else if (strcmp(item->valuestring, "codex") == 0) s->enabledCodex = true;
            else if (strcmp(item->valuestring, "gemini") == 0) s->enabledGemini = true;
        }
    }
}

static bool persist_skills(const Skill *skills, int count) {
    cJSON *arr = cJSON_CreateArray();
    for (int i = 0; i < count; i++)
        cJSON_AddItemToArray(arr, skill_to_json(&skills[i]));

    char *output = cJSON_Print(arr);
    cJSON_Delete(arr);
    if (!output) return false;

    wchar_t path[MAX_PATH];
    get_skills_index_path(path, MAX_PATH);
    bool ok = write_file_utf8(path, output);
    free(output);
    return ok;
}

/* ---------------------------------------------------------------
 * Sync to instruction files
 * --------------------------------------------------------------- */
#define MARKER_START "<!-- ACode Skills -->"
#define MARKER_END   "<!-- /ACode Skills -->"

static void sync_instruction_file(const wchar_t *path, const Skill *skills, int count,
                                  bool (*filter)(const Skill *)) {
    /* Ensure parent directory */
    wchar_t dir[MAX_PATH];
    wcscpy_s(dir, MAX_PATH, path);
    wchar_t *lastSlash = wcsrchr(dir, L'\\');
    if (!lastSlash) lastSlash = wcsrchr(dir, L'/');
    if (lastSlash) { *lastSlash = L'\0'; SHCreateDirectoryExW(NULL, dir, NULL); }

    char *existing = read_file_utf8(path);
    if (!existing) existing = _strdup("");
    if (!existing) return;

    /* Remove old ACode Skills block */
    char *startPos = strstr(existing, MARKER_START);
    char *endPos   = strstr(existing, MARKER_END);
    if (startPos && endPos && endPos > startPos) {
        int endMarkerLen = (int)strlen(MARKER_END);
        char *after = endPos + endMarkerLen;
        memmove(startPos, after, strlen(after) + 1);
        /* Trim trailing whitespace */
        int len = (int)strlen(existing);
        while (len > 0 && (existing[len-1] == '\n' || existing[len-1] == '\r' || existing[len-1] == ' '))
            existing[--len] = '\0';
    }

    /* Count enabled skills */
    int enabledCount = 0;
    for (int i = 0; i < count; i++)
        if (filter(&skills[i])) enabledCount++;

    if (enabledCount == 0) {
        /* Just write cleaned content if non-empty */
        if (existing[0])
            write_file_utf8(path, existing);
        free(existing);
        return;
    }

    /* Build new block */
    int blockSize = 4096 + enabledCount * (SKILL_MAX_CONTENT + SKILL_MAX_NAME_LEN + SKILL_MAX_DESC_LEN);
    char *block = (char *)malloc(blockSize);
    if (!block) { free(existing); return; }

    int pos = 0;
    pos += _snprintf_s(block + pos, blockSize - pos, _TRUNCATE, "\n\n%s\n", MARKER_START);
    for (int i = 0; i < count; i++) {
        if (!filter(&skills[i])) continue;
        pos += _snprintf_s(block + pos, blockSize - pos, _TRUNCATE, "## %s\n", skills[i].name);
        if (skills[i].description[0])
            pos += _snprintf_s(block + pos, blockSize - pos, _TRUNCATE, "> %s\n", skills[i].description);
        pos += _snprintf_s(block + pos, blockSize - pos, _TRUNCATE, "\n%s\n\n", skills[i].content);
    }
    pos += _snprintf_s(block + pos, blockSize - pos, _TRUNCATE, "%s", MARKER_END);

    /* Concatenate */
    int totalLen = (int)strlen(existing) + pos + 2;
    char *output = (char *)malloc(totalLen);
    if (output) {
        _snprintf_s(output, totalLen, _TRUNCATE, "%s%s", existing, block);
        write_file_utf8(path, output);
        free(output);
    }

    free(block);
    free(existing);
}

static bool filter_claude(const Skill *s) { return s->enabledClaude; }
static bool filter_codex(const Skill *s)  { return s->enabledCodex; }
static bool filter_gemini(const Skill *s) { return s->enabledGemini; }

static void sync_all_instruction_files(const Skill *skills, int count) {
    wchar_t path[MAX_PATH];

    get_claude_instructions_path(path, MAX_PATH);
    sync_instruction_file(path, skills, count, filter_claude);

    get_codex_instructions_path(path, MAX_PATH);
    sync_instruction_file(path, skills, count, filter_codex);

    get_gemini_instructions_path(path, MAX_PATH);
    sync_instruction_file(path, skills, count, filter_gemini);
}

/* ---------------------------------------------------------------
 * Public API
 * --------------------------------------------------------------- */
int skills_list(Skill *out, int maxCount) {
    wchar_t path[MAX_PATH];
    get_skills_index_path(path, MAX_PATH);

    char *content = read_file_utf8(path);
    if (!content) return 0;

    cJSON *arr = cJSON_Parse(content);
    free(content);
    if (!arr || !cJSON_IsArray(arr)) { cJSON_Delete(arr); return 0; }

    int count = 0;
    cJSON *item = NULL;
    cJSON_ArrayForEach(item, arr) {
        if (count >= maxCount) break;
        json_to_skill(item, &out[count]);
        count++;
    }

    cJSON_Delete(arr);
    return count;
}

bool skills_save(const Skill *skill) {
    if (!skill || !skill->id[0] || !skill->name[0]) return false;

    Skill all[SKILL_MAX_COUNT];
    int count = skills_list(all, SKILL_MAX_COUNT);

    /* Find existing or append */
    int idx = -1;
    for (int i = 0; i < count; i++) {
        if (strcmp(all[i].id, skill->id) == 0) { idx = i; break; }
    }

    if (idx >= 0) {
        all[idx] = *skill;
    } else {
        if (count >= SKILL_MAX_COUNT) return false;
        all[count] = *skill;
        count++;
    }

    bool ok = persist_skills(all, count);
    if (ok) sync_all_instruction_files(all, count);
    return ok;
}

bool skills_delete(const char *id) {
    if (!id || !id[0]) return false;

    Skill all[SKILL_MAX_COUNT];
    int count = skills_list(all, SKILL_MAX_COUNT);

    int newCount = 0;
    for (int i = 0; i < count; i++) {
        if (strcmp(all[i].id, id) != 0) {
            if (newCount != i) all[newCount] = all[i];
            newCount++;
        }
    }

    if (newCount == count) return true; /* not found */
    bool ok = persist_skills(all, newCount);
    if (ok) sync_all_instruction_files(all, newCount);
    return ok;
}

bool skills_toggle_app(const char *id, const char *app, bool enabled) {
    if (!id || !app) return false;

    Skill all[SKILL_MAX_COUNT];
    int count = skills_list(all, SKILL_MAX_COUNT);

    for (int i = 0; i < count; i++) {
        if (strcmp(all[i].id, id) == 0) {
            if (strcmp(app, "claude") == 0) all[i].enabledClaude = enabled;
            else if (strcmp(app, "codex") == 0) all[i].enabledCodex = enabled;
            else if (strcmp(app, "gemini") == 0) all[i].enabledGemini = enabled;
            break;
        }
    }

    bool ok = persist_skills(all, count);
    if (ok) sync_all_instruction_files(all, count);
    return ok;
}
