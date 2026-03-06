#ifndef ACODE_SYNTAX_H
#define ACODE_SYNTAX_H

#include <windows.h>

typedef enum {
    TOKEN_NORMAL,
    TOKEN_KEYWORD,
    TOKEN_TYPE,
    TOKEN_STRING,
    TOKEN_NUMBER,
    TOKEN_COMMENT,
    TOKEN_FUNCTION,
} TokenType;

typedef struct {
    int       start;
    int       length;
    TokenType type;
} SyntaxToken;

typedef struct {
    SyntaxToken *tokens;
    int          count;
    int          capacity;
} SyntaxResult;

typedef enum {
    LANG_NONE,
    LANG_C,
    LANG_JAVASCRIPT,
    LANG_PYTHON,
    LANG_RUST,
    LANG_GO,
    LANG_SWIFT,
    LANG_JAVA,
    LANG_HTML,
    LANG_CSS,
    LANG_JSON,
    LANG_SHELL,
    LANG_SQL,
    LANG_MARKDOWN,
    LANG_YAML,
    LANG_TOML,
} SyntaxLanguage;

SyntaxLanguage syntax_detect_language(const wchar_t *filename);
void syntax_highlight(const wchar_t *text, int textLen, SyntaxLanguage lang, SyntaxResult *result);
void syntax_result_free(SyntaxResult *result);

#endif /* ACODE_SYNTAX_H */
