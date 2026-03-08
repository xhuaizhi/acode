#ifndef ACODE_SKILLS_H
#define ACODE_SKILLS_H

#include <windows.h>
#include <stdbool.h>

#define SKILL_MAX_COUNT     64
#define SKILL_MAX_ID_LEN    64
#define SKILL_MAX_NAME_LEN  128
#define SKILL_MAX_DESC_LEN  512
#define SKILL_MAX_CONTENT   8192
#define SKILL_MAX_APPS      4

typedef struct {
    char    id[SKILL_MAX_ID_LEN];
    char    name[SKILL_MAX_NAME_LEN];
    char    description[SKILL_MAX_DESC_LEN];
    char    content[SKILL_MAX_CONTENT];
    bool    enabledClaude;
    bool    enabledCodex;
    bool    enabledGemini;
} Skill;

/* CRUD */
int  skills_list(Skill *out, int maxCount);
bool skills_save(const Skill *skill);
bool skills_delete(const char *id);
bool skills_toggle_app(const char *id, const char *app, bool enabled);

#endif /* ACODE_SKILLS_H */
