#include "syntax.h"
#include <stdlib.h>
#include <string.h>
#include <ctype.h>

static void add_token(SyntaxResult *r, int start, int len, TokenType type) {
    if (r->count >= r->capacity) {
        r->capacity = r->capacity ? r->capacity * 2 : 256;
        r->tokens = (SyntaxToken *)realloc(r->tokens, r->capacity * sizeof(SyntaxToken));
    }
    r->tokens[r->count++] = (SyntaxToken){ start, len, type };
}

static bool is_keyword_c(const wchar_t *word, int len) {
    static const wchar_t *kw[] = {
        L"auto", L"break", L"case", L"char", L"const", L"continue", L"default",
        L"do", L"double", L"else", L"enum", L"extern", L"float", L"for", L"goto",
        L"if", L"inline", L"int", L"long", L"register", L"return", L"short",
        L"signed", L"sizeof", L"static", L"struct", L"switch", L"typedef",
        L"union", L"unsigned", L"void", L"volatile", L"while",
        L"bool", L"true", L"false", L"NULL", L"nullptr",
        L"#include", L"#define", L"#ifdef", L"#ifndef", L"#endif", L"#else", L"#pragma",
        NULL
    };
    for (int i = 0; kw[i]; i++) {
        if ((int)wcslen(kw[i]) == len && wcsncmp(word, kw[i], len) == 0) return true;
    }
    return false;
}

static bool is_keyword_js(const wchar_t *word, int len) {
    static const wchar_t *kw[] = {
        L"var", L"let", L"const", L"function", L"return", L"if", L"else",
        L"for", L"while", L"do", L"switch", L"case", L"break", L"continue",
        L"new", L"delete", L"typeof", L"instanceof", L"in", L"of",
        L"class", L"extends", L"super", L"this", L"import", L"export",
        L"default", L"try", L"catch", L"finally", L"throw",
        L"async", L"await", L"yield", L"from", L"as",
        L"true", L"false", L"null", L"undefined", L"void",
        NULL
    };
    for (int i = 0; kw[i]; i++) {
        if ((int)wcslen(kw[i]) == len && wcsncmp(word, kw[i], len) == 0) return true;
    }
    return false;
}

static bool is_keyword_python(const wchar_t *word, int len) {
    static const wchar_t *kw[] = {
        L"and", L"as", L"assert", L"async", L"await", L"break", L"class",
        L"continue", L"def", L"del", L"elif", L"else", L"except", L"finally",
        L"for", L"from", L"global", L"if", L"import", L"in", L"is", L"lambda",
        L"nonlocal", L"not", L"or", L"pass", L"raise", L"return", L"try",
        L"while", L"with", L"yield", L"True", L"False", L"None",
        NULL
    };
    for (int i = 0; kw[i]; i++) {
        if ((int)wcslen(kw[i]) == len && wcsncmp(word, kw[i], len) == 0) return true;
    }
    return false;
}

typedef bool (*KeywordCheck)(const wchar_t *, int);

static KeywordCheck get_keyword_checker(SyntaxLanguage lang) {
    switch (lang) {
    case LANG_C: case LANG_GO: case LANG_RUST: case LANG_JAVA: case LANG_SWIFT:
        return is_keyword_c;
    case LANG_JAVASCRIPT:
        return is_keyword_js;
    case LANG_PYTHON:
        return is_keyword_python;
    default:
        return is_keyword_c;
    }
}

SyntaxLanguage syntax_detect_language(const wchar_t *filename) {
    if (!filename) return LANG_NONE;
    const wchar_t *dot = wcsrchr(filename, L'.');
    if (!dot) return LANG_NONE;
    dot++;

    if (!_wcsicmp(dot, L"c") || !_wcsicmp(dot, L"h") || !_wcsicmp(dot, L"cpp") || !_wcsicmp(dot, L"cc"))
        return LANG_C;
    if (!_wcsicmp(dot, L"js") || !_wcsicmp(dot, L"jsx") || !_wcsicmp(dot, L"ts") || !_wcsicmp(dot, L"tsx"))
        return LANG_JAVASCRIPT;
    if (!_wcsicmp(dot, L"py")) return LANG_PYTHON;
    if (!_wcsicmp(dot, L"rs")) return LANG_RUST;
    if (!_wcsicmp(dot, L"go")) return LANG_GO;
    if (!_wcsicmp(dot, L"swift")) return LANG_SWIFT;
    if (!_wcsicmp(dot, L"java") || !_wcsicmp(dot, L"kt")) return LANG_JAVA;
    if (!_wcsicmp(dot, L"html") || !_wcsicmp(dot, L"htm")) return LANG_HTML;
    if (!_wcsicmp(dot, L"css") || !_wcsicmp(dot, L"scss") || !_wcsicmp(dot, L"less")) return LANG_CSS;
    if (!_wcsicmp(dot, L"json")) return LANG_JSON;
    if (!_wcsicmp(dot, L"sh") || !_wcsicmp(dot, L"bash") || !_wcsicmp(dot, L"zsh") || !_wcsicmp(dot, L"ps1"))
        return LANG_SHELL;
    if (!_wcsicmp(dot, L"sql")) return LANG_SQL;
    if (!_wcsicmp(dot, L"md")) return LANG_MARKDOWN;
    if (!_wcsicmp(dot, L"yaml") || !_wcsicmp(dot, L"yml")) return LANG_YAML;
    if (!_wcsicmp(dot, L"toml")) return LANG_TOML;

    return LANG_NONE;
}

void syntax_highlight(const wchar_t *text, int textLen, SyntaxLanguage lang, SyntaxResult *result) {
    memset(result, 0, sizeof(SyntaxResult));
    if (!text || textLen == 0 || lang == LANG_NONE) return;

    KeywordCheck isKw = get_keyword_checker(lang);
    int i = 0;

    while (i < textLen) {
        /* Line comments */
        if (i + 1 < textLen && text[i] == L'/' && text[i + 1] == L'/') {
            int start = i;
            while (i < textLen && text[i] != L'\n') i++;
            add_token(result, start, i - start, TOKEN_COMMENT);
            continue;
        }

        /* Block comments */
        if (i + 1 < textLen && text[i] == L'/' && text[i + 1] == L'*') {
            int start = i;
            i += 2;
            while (i + 1 < textLen && !(text[i] == L'*' && text[i + 1] == L'/')) i++;
            if (i + 1 < textLen) i += 2;
            add_token(result, start, i - start, TOKEN_COMMENT);
            continue;
        }

        /* Hash comments (Python, Shell, YAML) */
        if (text[i] == L'#' && (lang == LANG_PYTHON || lang == LANG_SHELL || lang == LANG_YAML)) {
            int start = i;
            while (i < textLen && text[i] != L'\n') i++;
            add_token(result, start, i - start, TOKEN_COMMENT);
            continue;
        }

        /* Strings */
        if (text[i] == L'"' || text[i] == L'\'') {
            wchar_t quote = text[i];
            int start = i;
            i++;
            while (i < textLen && text[i] != quote) {
                if (text[i] == L'\\' && i + 1 < textLen) i++;
                i++;
            }
            if (i < textLen) i++;
            add_token(result, start, i - start, TOKEN_STRING);
            continue;
        }

        /* Numbers */
        if ((text[i] >= L'0' && text[i] <= L'9') ||
            (text[i] == L'.' && i + 1 < textLen && text[i + 1] >= L'0' && text[i + 1] <= L'9')) {
            int start = i;
            if (text[i] == L'0' && i + 1 < textLen && (text[i + 1] == L'x' || text[i + 1] == L'X')) {
                i += 2;
                while (i < textLen && ((text[i] >= L'0' && text[i] <= L'9') ||
                       (text[i] >= L'a' && text[i] <= L'f') || (text[i] >= L'A' && text[i] <= L'F'))) i++;
            } else {
                while (i < textLen && ((text[i] >= L'0' && text[i] <= L'9') || text[i] == L'.')) i++;
            }
            add_token(result, start, i - start, TOKEN_NUMBER);
            continue;
        }

        /* Identifiers / Keywords */
        if (iswalpha(text[i]) || text[i] == L'_' || text[i] == L'#') {
            int start = i;
            while (i < textLen && (iswalnum(text[i]) || text[i] == L'_')) i++;

            if (isKw(text + start, i - start)) {
                add_token(result, start, i - start, TOKEN_KEYWORD);
            } else if (i < textLen && text[i] == L'(') {
                add_token(result, start, i - start, TOKEN_FUNCTION);
            }
            continue;
        }

        i++;
    }
}

void syntax_result_free(SyntaxResult *result) {
    free(result->tokens);
    result->tokens = NULL;
    result->count = 0;
    result->capacity = 0;
}
