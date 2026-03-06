#include "env_generator.h"
#include "provider.h"
#include "provider_service.h"
#include "../utils/wstr.h"
#include <stdio.h>
#include <string.h>

void env_generator_build(wchar_t *envBlock, int envBlockChars) {
    envBlock[0] = L'\0';
    wchar_t *p = envBlock;
    int remaining = envBlockChars;

    /* Claude Code env */
    Provider claude;
    if (provider_service_get_active("claude_code", &claude)) {
        if (claude.apiKey[0]) {
            wchar_t line[1024];
            wchar_t wKey[512];
            wstr_from_utf8(claude.apiKey, wKey, 512);
            int n = _snwprintf(line, 1024, L"ANTHROPIC_API_KEY=%s\n", wKey);
            if (n > 0 && n < remaining) { wcscat(p, line); remaining -= n; }
        }
    }

    /* OpenAI env */
    Provider openai;
    if (provider_service_get_active("openai", &openai)) {
        if (openai.apiKey[0]) {
            wchar_t line[1024];
            wchar_t wKey[512];
            wstr_from_utf8(openai.apiKey, wKey, 512);
            int n = _snwprintf(line, 1024, L"OPENAI_API_KEY=%s\n", wKey);
            if (n > 0 && n < remaining) { wcscat(p, line); remaining -= n; }
        }
    }

    /* Gemini env */
    Provider gemini;
    if (provider_service_get_active("gemini", &gemini)) {
        if (gemini.apiKey[0]) {
            wchar_t line[1024];
            wchar_t wKey[512];
            wstr_from_utf8(gemini.apiKey, wKey, 512);
            int n = _snwprintf(line, 1024, L"GEMINI_API_KEY=%s\n", wKey);
            if (n > 0 && n < remaining) { wcscat(p, line); remaining -= n; }
        }
    }

    /* Common terminal env */
    int n = _snwprintf(p + wcslen(p), remaining, L"TERM=xterm-256color\nCOLORTERM=truecolor\n");
    (void)n;
}
