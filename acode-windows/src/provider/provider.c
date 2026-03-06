#include "provider.h"
#include "../database/database.h"
#include <stdlib.h>
#include <string.h>
#include <stdio.h>

static const ProviderPreset s_presets[] = {
    { "claude_official", "Claude \u5B98\u65B9", "claude_code", "https://api.anthropic.com", "claude-sonnet-4-20250514", "bubble.left.fill", "\u5B98\u65B9" },
    { "openai_official", "OpenAI \u5B98\u65B9", "openai", "https://api.openai.com/v1", "gpt-4o", "hexagon", "\u5B98\u65B9" },
    { "gemini_official", "Gemini \u5B98\u65B9", "gemini", "https://generativelanguage.googleapis.com", "gemini-2.5-pro", "sparkle", "\u5B98\u65B9" },
    { "deepseek", "DeepSeek", "openai", "https://api.deepseek.com/v1", "deepseek-chat", "bolt", "\u7B2C\u4E09\u65B9" },
    { "openrouter", "OpenRouter", "openai", "https://openrouter.ai/api/v1", "", "globe", "\u7B2C\u4E09\u65B9" },
};

bool provider_list(const char *tool, Provider **out, int *count) {
    sqlite3 *db = db_get();
    if (!db) return false;

    char sql[512];
    if (tool) {
        snprintf(sql, sizeof(sql),
            "SELECT id,name,tool,api_key,api_base,model,is_active,sort_order,"
            "preset_id,extra_env,icon,icon_color,notes,category "
            "FROM providers WHERE tool='%s' ORDER BY sort_order", tool);
    } else {
        snprintf(sql, sizeof(sql),
            "SELECT id,name,tool,api_key,api_base,model,is_active,sort_order,"
            "preset_id,extra_env,icon,icon_color,notes,category "
            "FROM providers ORDER BY sort_order");
    }

    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(db, sql, -1, &stmt, NULL) != SQLITE_OK)
        return false;

    int capacity = 16;
    *out = (Provider *)calloc(capacity, sizeof(Provider));
    *count = 0;

    while (sqlite3_step(stmt) == SQLITE_ROW) {
        if (*count >= capacity) {
            capacity *= 2;
            *out = (Provider *)realloc(*out, capacity * sizeof(Provider));
        }

        Provider *p = &(*out)[*count];
        memset(p, 0, sizeof(Provider));

        p->id = sqlite3_column_int(stmt, 0);
        const char *s;
        if ((s = (const char *)sqlite3_column_text(stmt, 1))) strncpy(p->name, s, sizeof(p->name) - 1);
        if ((s = (const char *)sqlite3_column_text(stmt, 2))) strncpy(p->tool, s, sizeof(p->tool) - 1);
        if ((s = (const char *)sqlite3_column_text(stmt, 3))) strncpy(p->apiKey, s, sizeof(p->apiKey) - 1);
        if ((s = (const char *)sqlite3_column_text(stmt, 4))) strncpy(p->apiBase, s, sizeof(p->apiBase) - 1);
        if ((s = (const char *)sqlite3_column_text(stmt, 5))) strncpy(p->model, s, sizeof(p->model) - 1);
        p->isActive = sqlite3_column_int(stmt, 6) != 0;
        p->sortOrder = sqlite3_column_int(stmt, 7);
        if ((s = (const char *)sqlite3_column_text(stmt, 8))) strncpy(p->presetId, s, sizeof(p->presetId) - 1);
        if ((s = (const char *)sqlite3_column_text(stmt, 9))) strncpy(p->extraEnv, s, sizeof(p->extraEnv) - 1);
        if ((s = (const char *)sqlite3_column_text(stmt, 10))) strncpy(p->icon, s, sizeof(p->icon) - 1);
        if ((s = (const char *)sqlite3_column_text(stmt, 11))) strncpy(p->iconColor, s, sizeof(p->iconColor) - 1);
        if ((s = (const char *)sqlite3_column_text(stmt, 12))) strncpy(p->notes, s, sizeof(p->notes) - 1);
        if ((s = (const char *)sqlite3_column_text(stmt, 13))) strncpy(p->category, s, sizeof(p->category) - 1);

        (*count)++;
    }

    sqlite3_finalize(stmt);
    return true;
}

bool provider_get(int id, Provider *out) {
    sqlite3 *db = db_get();
    if (!db) return false;

    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(db,
        "SELECT id,name,tool,api_key,api_base,model,is_active,sort_order,"
        "preset_id,extra_env,icon,icon_color,notes,category "
        "FROM providers WHERE id=?", -1, &stmt, NULL) != SQLITE_OK)
        return false;

    sqlite3_bind_int(stmt, 1, id);

    bool found = false;
    if (sqlite3_step(stmt) == SQLITE_ROW) {
        memset(out, 0, sizeof(Provider));
        out->id = sqlite3_column_int(stmt, 0);
        const char *s;
        if ((s = (const char *)sqlite3_column_text(stmt, 1))) strncpy(out->name, s, sizeof(out->name) - 1);
        if ((s = (const char *)sqlite3_column_text(stmt, 2))) strncpy(out->tool, s, sizeof(out->tool) - 1);
        if ((s = (const char *)sqlite3_column_text(stmt, 3))) strncpy(out->apiKey, s, sizeof(out->apiKey) - 1);
        if ((s = (const char *)sqlite3_column_text(stmt, 4))) strncpy(out->apiBase, s, sizeof(out->apiBase) - 1);
        if ((s = (const char *)sqlite3_column_text(stmt, 5))) strncpy(out->model, s, sizeof(out->model) - 1);
        out->isActive = sqlite3_column_int(stmt, 6) != 0;
        out->sortOrder = sqlite3_column_int(stmt, 7);
        found = true;
    }

    sqlite3_finalize(stmt);
    return found;
}

bool provider_insert(const Provider *p) {
    sqlite3 *db = db_get();
    if (!db) return false;

    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(db,
        "INSERT INTO providers (name,tool,api_key,api_base,model,is_active,sort_order,preset_id,extra_env,icon,icon_color,notes,category) "
        "VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?)", -1, &stmt, NULL) != SQLITE_OK)
        return false;

    sqlite3_bind_text(stmt, 1, p->name, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 2, p->tool, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 3, p->apiKey, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 4, p->apiBase, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 5, p->model, -1, SQLITE_TRANSIENT);
    sqlite3_bind_int(stmt, 6, p->isActive ? 1 : 0);
    sqlite3_bind_int(stmt, 7, p->sortOrder);
    sqlite3_bind_text(stmt, 8, p->presetId, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 9, p->extraEnv, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 10, p->icon, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 11, p->iconColor, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 12, p->notes, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 13, p->category, -1, SQLITE_TRANSIENT);

    bool ok = sqlite3_step(stmt) == SQLITE_DONE;
    sqlite3_finalize(stmt);
    return ok;
}

bool provider_update(const Provider *p) {
    sqlite3 *db = db_get();
    if (!db) return false;

    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(db,
        "UPDATE providers SET name=?,api_key=?,api_base=?,model=?,extra_env=?,notes=?,"
        "icon=?,icon_color=?,updated_at=datetime('now') WHERE id=?",
        -1, &stmt, NULL) != SQLITE_OK)
        return false;

    sqlite3_bind_text(stmt, 1, p->name, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 2, p->apiKey, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 3, p->apiBase, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 4, p->model, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 5, p->extraEnv, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 6, p->notes, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 7, p->icon, -1, SQLITE_TRANSIENT);
    sqlite3_bind_text(stmt, 8, p->iconColor, -1, SQLITE_TRANSIENT);
    sqlite3_bind_int(stmt, 9, p->id);

    bool ok = sqlite3_step(stmt) == SQLITE_DONE;
    sqlite3_finalize(stmt);
    return ok;
}

bool provider_delete(int id) {
    sqlite3 *db = db_get();
    if (!db) return false;

    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(db, "DELETE FROM providers WHERE id=?", -1, &stmt, NULL) != SQLITE_OK)
        return false;

    sqlite3_bind_int(stmt, 1, id);
    bool ok = sqlite3_step(stmt) == SQLITE_DONE;
    sqlite3_finalize(stmt);
    return ok;
}

bool provider_switch(int id) {
    sqlite3 *db = db_get();
    if (!db) return false;

    Provider p;
    if (!provider_get(id, &p)) return false;

    /* Deactivate all providers of same tool */
    char sql[256];
    snprintf(sql, sizeof(sql), "UPDATE providers SET is_active=0 WHERE tool='%s'", p.tool);
    db_exec(sql);

    /* Activate this one */
    snprintf(sql, sizeof(sql), "UPDATE providers SET is_active=1 WHERE id=%d", id);
    return db_exec(sql);
}

void provider_free_list(Provider *list) {
    free(list);
}

const ProviderPreset *provider_get_presets(int *count) {
    *count = sizeof(s_presets) / sizeof(s_presets[0]);
    return s_presets;
}
