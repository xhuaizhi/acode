#include "database.h"
#include "../utils/wstr.h"
#include <stdio.h>

static sqlite3 *s_db = NULL;

bool db_open(const wchar_t *path) {
    char pathUtf8[MAX_PATH * 2];
    wstr_to_utf8(path, pathUtf8, sizeof(pathUtf8));

    int rc = sqlite3_open(pathUtf8, &s_db);
    if (rc != SQLITE_OK) {
        s_db = NULL;
        /* Fallback to in-memory */
        rc = sqlite3_open(":memory:", &s_db);
        if (rc != SQLITE_OK) return false;
    }

    sqlite3_busy_timeout(s_db, 5000);
    db_setup_tables();
    db_seed_model_pricing();
    return true;
}

void db_close(void) {
    if (s_db) {
        sqlite3_close(s_db);
        s_db = NULL;
    }
}

sqlite3 *db_get(void) {
    return s_db;
}

bool db_exec(const char *sql) {
    if (!s_db) return false;
    char *err = NULL;
    int rc = sqlite3_exec(s_db, sql, NULL, NULL, &err);
    if (err) sqlite3_free(err);
    return rc == SQLITE_OK;
}

bool db_setup_tables(void) {
    return db_exec(
        "CREATE TABLE IF NOT EXISTS providers ("
        "  id INTEGER PRIMARY KEY AUTOINCREMENT,"
        "  name TEXT NOT NULL,"
        "  tool TEXT NOT NULL,"
        "  api_key TEXT NOT NULL DEFAULT '',"
        "  api_base TEXT NOT NULL DEFAULT '',"
        "  model TEXT NOT NULL DEFAULT '',"
        "  is_active INTEGER NOT NULL DEFAULT 0,"
        "  sort_order INTEGER NOT NULL DEFAULT 0,"
        "  preset_id TEXT DEFAULT NULL,"
        "  extra_env TEXT DEFAULT NULL,"
        "  icon TEXT DEFAULT NULL,"
        "  icon_color TEXT DEFAULT NULL,"
        "  notes TEXT DEFAULT NULL,"
        "  category TEXT DEFAULT NULL,"
        "  created_at TEXT DEFAULT (datetime('now')),"
        "  updated_at TEXT DEFAULT (datetime('now'))"
        ");"
        "CREATE TABLE IF NOT EXISTS model_pricing ("
        "  model_id TEXT PRIMARY KEY,"
        "  display_name TEXT NOT NULL,"
        "  input_cost_per_million REAL DEFAULT 0,"
        "  output_cost_per_million REAL DEFAULT 0,"
        "  cache_read_cost_per_million REAL DEFAULT 0,"
        "  cache_creation_cost_per_million REAL DEFAULT 0"
        ");"
        "CREATE TABLE IF NOT EXISTS settings ("
        "  key TEXT PRIMARY KEY,"
        "  value TEXT"
        ");"
    );
}

bool db_seed_model_pricing(void) {
    /* Only seed if table is empty */
    sqlite3_stmt *stmt;
    if (sqlite3_prepare_v2(s_db, "SELECT COUNT(*) FROM model_pricing", -1, &stmt, NULL) != SQLITE_OK)
        return false;

    int count = 0;
    if (sqlite3_step(stmt) == SQLITE_ROW)
        count = sqlite3_column_int(stmt, 0);
    sqlite3_finalize(stmt);

    if (count > 0) return true;

    return db_exec(
        "INSERT INTO model_pricing VALUES "
        "('claude-3-5-haiku-20241022','Claude 3.5 Haiku',1.0,5.0,0.1,1.25),"
        "('claude-3-5-sonnet-20241022','Claude 3.5 Sonnet',3.0,15.0,0.3,3.75),"
        "('claude-sonnet-4-20250514','Claude Sonnet 4',3.0,15.0,0.3,3.75),"
        "('claude-opus-4-20250514','Claude Opus 4',15.0,75.0,1.5,18.75),"
        "('gpt-4o','GPT-4o',2.5,10.0,1.25,0),"
        "('gpt-4o-mini','GPT-4o Mini',0.15,0.6,0.075,0),"
        "('o3','o3',10.0,40.0,2.5,0),"
        "('o3-mini','o3-mini',1.1,4.4,0.55,0),"
        "('o4-mini','o4-mini',1.1,4.4,0.55,0),"
        "('codex-mini-latest','Codex Mini',1.5,6.0,0.375,0),"
        "('gemini-2.5-pro','Gemini 2.5 Pro',1.25,10.0,0.315,0),"
        "('gemini-2.5-flash','Gemini 2.5 Flash',0.15,0.6,0.0375,0),"
        "('gemini-2.0-flash','Gemini 2.0 Flash',0.1,0.4,0.025,0),"
        "('deepseek-chat','DeepSeek V3',0.27,1.1,0.07,0),"
        "('deepseek-reasoner','DeepSeek R1',0.55,2.19,0.14,0);"
    );
}
