#ifndef ACODE_PROVIDER_H
#define ACODE_PROVIDER_H

#include <windows.h>
#include <stdbool.h>

typedef struct {
    int     id;
    char    name[128];
    char    tool[32];       /* "claude_code", "openai", "gemini" */
    char    apiKey[512];
    char    apiBase[512];
    char    model[128];
    bool    isActive;
    int     sortOrder;
    char    presetId[64];
    char    extraEnv[2048];
    char    icon[32];
    char    iconColor[32];
    char    notes[512];
    char    category[64];
} Provider;

/* CRUD */
bool provider_list(const char *tool, Provider **out, int *count);
bool provider_get(int id, Provider *out);
bool provider_insert(const Provider *p);
bool provider_update(const Provider *p);
bool provider_delete(int id);
bool provider_switch(int id);
void provider_free_list(Provider *list);

/* Presets */
typedef struct {
    const char *id;
    const char *name;
    const char *tool;
    const char *apiBase;
    const char *model;
    const char *icon;
    const char *category;
} ProviderPreset;

const ProviderPreset *provider_get_presets(int *count);

#endif /* ACODE_PROVIDER_H */
