#include "env_generator.h"
#include "provider.h"
#include "provider_service.h"
#include "../utils/wstr.h"
#include <cJSON.h>
#include <stdio.h>
#include <string.h>

/* Helper: append "KEY=VALUE\n" to envBlock, update remaining */
static void env_append(wchar_t *buf, int *remaining, const char *key, const char *value) {
    if (!key[0] || !value[0]) return;
    wchar_t wKey[256], wVal[1024], line[1536];
    wstr_from_utf8(key, wKey, 256);
    wstr_from_utf8(value, wVal, 1024);
    int n = _snwprintf(line, 1536, L"%s=%s\n", wKey, wVal);
    if (n > 0 && n < *remaining) {
        wcscat(buf, line);
        *remaining -= n;
    }
}

/* Helper: merge extra_env JSON object into envBlock */
static void env_merge_extra(wchar_t *buf, int *remaining, const char *extraEnvJson) {
    if (!extraEnvJson || !extraEnvJson[0] || strcmp(extraEnvJson, "{}") == 0) return;
    cJSON *extra = cJSON_Parse(extraEnvJson);
    if (!extra || !cJSON_IsObject(extra)) { cJSON_Delete(extra); return; }
    cJSON *item = NULL;
    cJSON_ArrayForEach(item, extra) {
        if (cJSON_IsString(item) && item->string && item->valuestring) {
            env_append(buf, remaining, item->string, item->valuestring);
        }
    }
    cJSON_Delete(extra);
}

void env_generator_build(wchar_t *envBlock, int envBlockChars) {
    envBlock[0] = L'\0';
    int remaining = envBlockChars;

    /* ---- Claude Code env (matches Mac ProviderEnvGenerator) ---- */
    Provider claude;
    if (provider_service_get_active("claude_code", &claude)) {
        if (claude.apiKey[0])
            env_append(envBlock, &remaining, "ANTHROPIC_API_KEY", claude.apiKey);
        if (claude.apiBase[0])
            env_append(envBlock, &remaining, "ANTHROPIC_BASE_URL", claude.apiBase);
        if (claude.model[0])
            env_append(envBlock, &remaining, "ANTHROPIC_MODEL", claude.model);
        env_merge_extra(envBlock, &remaining, claude.extraEnv);
    }

    /* ---- OpenAI Codex env ---- */
    Provider openai;
    if (provider_service_get_active("openai", &openai)) {
        if (openai.apiKey[0])
            env_append(envBlock, &remaining, "OPENAI_API_KEY", openai.apiKey);
        if (openai.apiBase[0])
            env_append(envBlock, &remaining, "OPENAI_BASE_URL", openai.apiBase);
        if (openai.model[0])
            env_append(envBlock, &remaining, "OPENAI_MODEL", openai.model);
        env_merge_extra(envBlock, &remaining, openai.extraEnv);
    }

    /* ---- Gemini env (dual keys, matching Mac) ---- */
    Provider gemini;
    if (provider_service_get_active("gemini", &gemini)) {
        if (gemini.apiKey[0]) {
            env_append(envBlock, &remaining, "GOOGLE_API_KEY", gemini.apiKey);
            env_append(envBlock, &remaining, "GEMINI_API_KEY", gemini.apiKey);
        }
        if (gemini.apiBase[0]) {
            env_append(envBlock, &remaining, "GOOGLE_GEMINI_BASE_URL", gemini.apiBase);
            env_append(envBlock, &remaining, "GEMINI_BASE_URL", gemini.apiBase);
        }
        if (gemini.model[0])
            env_append(envBlock, &remaining, "GEMINI_MODEL", gemini.model);
        env_merge_extra(envBlock, &remaining, gemini.extraEnv);
    }

    /* ---- Common terminal env ---- */
    env_append(envBlock, &remaining, "TERM", "xterm-256color");
    env_append(envBlock, &remaining, "COLORTERM", "truecolor");
}
